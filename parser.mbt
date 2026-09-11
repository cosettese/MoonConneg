///|
priv struct Cursor {
  chars : Array[Char]
  mut pos : Int
}

///|
fn Cursor::new(input : String) -> Cursor {
  { chars: input.to_array(), pos: 0, }
}

///|
fn Cursor::end(self : Cursor) -> Bool {
  self.pos >= self.chars.length()
}

///|
fn Cursor::peek(self : Cursor) -> Char? {
  if self.end() {
    None
  } else {
    Some(self.chars[self.pos])
  }
}

///|
fn is_ows(ch : Char) -> Bool {
  ch == ' ' || ch == '\t'
}

///|
fn is_alpha(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn is_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_tchar(ch : Char) -> Bool {
  is_alpha(ch) ||
  is_digit(ch) ||
  ch == '!' ||
  ch == '#' ||
  ch == '$' ||
  ch == '%' ||
  ch == '&' ||
  ch == '\'' ||
  ch == '*' ||
  ch == '+' ||
  ch == '-' ||
  ch == '.' ||
  ch == '^' ||
  ch == '_' ||
  ch == '`' ||
  ch == '|' ||
  ch == '~'
}

///|
fn chars_to_string(chars : Array[Char], start : Int, end : Int) -> String {
  let out = StringBuilder(size_hint=end - start)
  for i = start; i < end; i = i + 1 {
    out.write_char(chars[i])
  }
  out.to_string()
}

///|
fn Cursor::skip_ows(self : Cursor) -> Unit {
  while !self.end() && is_ows(self.chars[self.pos]) {
    self.pos = self.pos + 1
  }
}

///|
fn Cursor::take_char(
  self : Cursor,
  expected : Char,
  context : String,
) -> Result[Unit, ParseError] {
  match self.peek() {
    None => Err(UnexpectedEnd(self.pos, context))
    Some(ch) =>
      if ch == expected {
        self.pos = self.pos + 1
        Ok(())
      } else {
        Err(UnexpectedCharacter(self.pos, ch, context))
      }
  }
}

///|
fn Cursor::token(self : Cursor, context : String) -> Result[String, ParseError] {
  let start = self.pos
  while !self.end() && is_tchar(self.chars[self.pos]) {
    self.pos = self.pos + 1
  }
  if self.pos == start {
    Err(InvalidToken(start, context))
  } else {
    Ok(chars_to_string(self.chars, start, self.pos))
  }
}

///|
fn Cursor::quoted(self : Cursor) -> Result[String, ParseError] {
  let start = self.pos
  match self.take_char('"', "opening quote") {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let out = StringBuilder()
  while !self.end() {
    let ch = self.chars[self.pos]
    self.pos = self.pos + 1
    if ch == '"' {
      return Ok(out.to_string())
    }
    if ch == '\\' {
      if self.end() {
        return Err(UnexpectedEnd(self.pos, "quoted-pair character"))
      }
      out.write_char(self.chars[self.pos])
      self.pos = self.pos + 1
    } else if ch == '\r' || ch == '\n' {
      return Err(UnexpectedCharacter(self.pos - 1, ch, "quoted text"))
    } else {
      out.write_char(ch)
    }
  }
  Err(UnexpectedEnd(start, "closing quote"))
}

///|
fn Cursor::parameter(self : Cursor) -> Result[(Parameter, Int), ParseError] {
  self.skip_ows()
  let offset = self.pos
  let name = match self.token("parameter name") {
    Err(error) => return Err(error)
    Ok(value) => value.to_lower()
  }
  self.skip_ows()
  match self.take_char('=', "=") {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  self.skip_ows()
  let value = match self.peek() {
    Some('"') =>
      match self.quoted() {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      match self.token("parameter value") {
        Ok(value) => value
        Err(error) => return Err(error)
      }
  }
  Ok(({ name, value, }, offset))
}

///|
fn has_parameter(parameters : Array[Parameter], name : String) -> Bool {
  for parameter in parameters {
    if parameter.name == name {
      return true
    }
  }
  false
}

///|
fn parse_quality(value : String, offset : Int) -> Result[Int, ParseError] {
  let chars = value.to_array()
  if chars.length() == 0 {
    return Err(InvalidQuality(offset, value))
  }
  if chars[0] == '1' {
    if chars.length() == 1 {
      return Ok(1000)
    }
    if chars.length() < 3 || chars.length() > 5 || chars[1] != '.' {
      return Err(InvalidQuality(offset, value))
    }
    for i = 2; i < chars.length(); i = i + 1 {
      if chars[i] != '0' {
        return Err(InvalidQuality(offset, value))
      }
    }
    return Ok(1000)
  }
  if chars[0] != '0' {
    return Err(InvalidQuality(offset, value))
  }
  if chars.length() == 1 {
    return Ok(0)
  }
  if chars.length() < 3 || chars.length() > 5 || chars[1] != '.' {
    return Err(InvalidQuality(offset, value))
  }
  let mut result = 0
  let weights = [100, 10, 1]
  for i = 2; i < chars.length(); i = i + 1 {
    if !is_digit(chars[i]) {
      return Err(InvalidQuality(offset, value))
    }
    result = result + (chars[i].to_int() - '0'.to_int()) * weights[i - 2]
  }
  Ok(result)
}

///|
/// Parse a concrete Content-Type value.
pub fn parse_media_type(input : String) -> Result[MediaType, ParseError] {
  parse_media_type_with_limits(input, Limits::default())
}

///|
/// Parse a concrete Content-Type value with explicit resource limits.
pub fn parse_media_type_with_limits(
  input : String,
  limits : Limits,
) -> Result[MediaType, ParseError] {
  match check_field_limit(input, limits) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let cursor = Cursor::new(input)
  cursor.skip_ows()
  if cursor.end() {
    return Err(EmptyInput)
  }
  let type_offset = cursor.pos
  let type_ = match cursor.token("media type") {
    Ok(value) => value.to_lower()
    Err(error) => return Err(error)
  }
  match cursor.take_char('/', "/") {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let subtype = match cursor.token("media subtype") {
    Ok(value) => value.to_lower()
    Err(error) => return Err(error)
  }
  if type_ == "*" || subtype == "*" {
    return Err(InvalidWildcard(type_offset))
  }
  let parameters = []
  while true {
    cursor.skip_ows()
    if cursor.end() {
      break
    }
    match cursor.take_char(';', "; or end of input") {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    match
      check_parameter_limit(
        parameters.length() + 1,
        limits,
        "Content-Type parameters",
      ) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let (parameter, offset) = match cursor.parameter() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if has_parameter(parameters, parameter.name) {
      return Err(DuplicateParameter(offset, parameter.name))
    }
    parameters.push(parameter)
  }
  Ok({ type_, subtype, parameters, })
}

///|
/// Parse an Accept field into ordered media ranges.
pub fn parse_accept(input : String) -> Result[Array[MediaRange], ParseError] {
  parse_accept_with_limits(input, Limits::default())
}

///|
/// Parse an Accept field with explicit resource limits.
pub fn parse_accept_with_limits(
  input : String,
  limits : Limits,
) -> Result[Array[MediaRange], ParseError] {
  match check_field_limit(input, limits) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let cursor = Cursor::new(input)
  cursor.skip_ows()
  if cursor.end() {
    match check_list_limit(1, limits, "Accept media ranges") {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    return Ok([
      {
        type_: "*",
        subtype: "*",
        parameters: [],
        quality: 1000,
        extensions: [],
        order: 0,
      },
    ])
  }
  let ranges = []
  let mut order = 0
  while true {
    match check_list_limit(order + 1, limits, "Accept media ranges") {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    cursor.skip_ows()
    let type_offset = cursor.pos
    let type_ = match cursor.token("media range type") {
      Ok(value) => value.to_lower()
      Err(error) => return Err(error)
    }
    match cursor.take_char('/', "/") {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let subtype = match cursor.token("media range subtype") {
      Ok(value) => value.to_lower()
      Err(error) => return Err(error)
    }
    if type_ == "*" && subtype != "*" {
      return Err(InvalidWildcard(type_offset))
    }
    let parameters = []
    let extensions = []
    let mut quality = 1000
    let mut seen_quality = false
    let mut parameter_count = 0
    while true {
      cursor.skip_ows()
      match cursor.peek() {
        Some(';') => {
          cursor.pos = cursor.pos + 1
          parameter_count = parameter_count + 1
          match
            check_parameter_limit(parameter_count, limits, "Accept parameters") {
            Err(error) => return Err(error)
            Ok(_) => ()
          }
          let (parameter, offset) = match cursor.parameter() {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          if parameter.name == "q" {
            if seen_quality {
              return Err(DuplicateParameter(offset, "q"))
            }
            quality = match parse_quality(parameter.value, offset) {
              Ok(value) => value
              Err(error) => return Err(error)
            }
            seen_quality = true
          } else if seen_quality {
            if has_parameter(extensions, parameter.name) {
              return Err(DuplicateParameter(offset, parameter.name))
            }
            extensions.push(parameter)
          } else {
            if has_parameter(parameters, parameter.name) {
              return Err(DuplicateParameter(offset, parameter.name))
            }
            parameters.push(parameter)
          }
        }
        _ => break
      }
    }
    ranges.push({ type_, subtype, parameters, quality, extensions, order, })
    order = order + 1
    cursor.skip_ows()
    if cursor.end() {
      break
    }
    match cursor.take_char(',', ", or end of input") {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    cursor.skip_ows()
    if cursor.end() {
      return Err(UnexpectedEnd(cursor.pos, "media range after comma"))
    }
  }
  Ok(ranges)
}
