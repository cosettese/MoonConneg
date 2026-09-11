///|
fn is_alphanumeric(ch : Char) -> Bool {
  is_alpha(ch) || is_digit(ch)
}

///|
/// Validate RFC 4647 basic-language-range syntax and return its subtag count.
fn basic_language_specificity(
  value : String,
  offset : Int,
  allow_wildcard : Bool,
) -> Result[Int, ParseError] {
  if value == "*" {
    if allow_wildcard {
      return Ok(0)
    }
    return Err(InvalidLanguage(offset, value))
  }
  let chars = value.to_array()
  if chars.length() == 0 {
    return Err(InvalidLanguage(offset, value))
  }
  let mut subtag_start = 0
  let mut subtag_index = 0
  for index = 0; index <= chars.length(); index = index + 1 {
    if index == chars.length() || chars[index] == '-' {
      let subtag_length = index - subtag_start
      if subtag_length == 0 || subtag_length > 8 {
        return Err(InvalidLanguage(offset + subtag_start, value))
      }
      for position = subtag_start; position < index; position = position + 1 {
        let valid = if subtag_index == 0 {
          is_alpha(chars[position])
        } else {
          is_alphanumeric(chars[position])
        }
        if !valid {
          return Err(InvalidLanguage(offset + position, value))
        }
      }
      subtag_index = subtag_index + 1
      subtag_start = index + 1
    }
  }
  Ok(subtag_index)
}

///|
/// Parse an Accept-Language field into ordered basic language ranges.
pub fn parse_accept_language(
  input : String,
) -> Result[Array[LanguagePreference], ParseError] {
  parse_accept_language_with_limits(input, Limits::default())
}

///|
/// Parse an Accept-Language field with explicit resource limits.
pub fn parse_accept_language_with_limits(
  input : String,
  limits : Limits,
) -> Result[Array[LanguagePreference], ParseError] {
  match check_field_limit(input, limits) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let cursor = Cursor::new(input)
  cursor.skip_ows()
  if cursor.end() {
    return Ok([])
  }
  let preferences = []
  let mut order = 0
  while true {
    match check_list_limit(order + 1, limits, "Accept-Language items") {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    cursor.skip_ows()
    let range_offset = cursor.pos
    let range = match cursor.token("basic language range") {
      Ok(value) => value.to_lower()
      Err(error) => return Err(error)
    }
    let specificity = match
      basic_language_specificity(range, range_offset, true) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let mut quality = 1000
    let mut seen_quality = false
    let mut parameter_count = 0
    while true {
      cursor.skip_ows()
      if cursor.peek() != Some(';') {
        break
      }
      cursor.pos = cursor.pos + 1
      parameter_count = parameter_count + 1
      match
        check_parameter_limit(
          parameter_count, limits, "Accept-Language parameters",
        ) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let (parameter, offset) = match cursor.parameter() {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if parameter.name != "q" {
        return Err(InvalidParameter(offset, parameter.name, "Accept-Language"))
      }
      if seen_quality {
        return Err(DuplicateParameter(offset, "q"))
      }
      quality = match parse_quality(parameter.value, offset) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      seen_quality = true
    }
    preferences.push({ range, quality, specificity, order, })
    order = order + 1
    cursor.skip_ows()
    if cursor.end() {
      break
    }
    match cursor.take_char(',', ", or end of input") {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    cursor.skip_ows()
    if cursor.end() {
      return Err(UnexpectedEnd(cursor.pos, "language range after comma"))
    }
  }
  Ok(preferences)
}

///|
fn normalize_available_language(input : String) -> Result[String, ParseError] {
  let cursor = Cursor::new(input)
  cursor.skip_ows()
  if cursor.end() {
    return Err(InvalidLanguage(0, input))
  }
  let offset = cursor.pos
  let language = match cursor.token("available language tag") {
    Ok(value) => value.to_lower()
    Err(error) => return Err(error)
  }
  cursor.skip_ows()
  if !cursor.end() {
    match cursor.peek() {
      Some(ch) =>
        return Err(
          UnexpectedCharacter(cursor.pos, ch, "end of available language tag"),
        )
      None => ()
    }
  }
  match basic_language_specificity(language, offset, false) {
    Ok(_) => Ok(language)
    Err(error) => Err(error)
  }
}

///|
fn basic_language_matches(range : String, language : String) -> Bool {
  if range == "*" {
    return true
  }
  let range_chars = range.to_array()
  let language_chars = language.to_array()
  if range_chars.length() > language_chars.length() {
    return false
  }
  for index = 0; index < range_chars.length(); index = index + 1 {
    if range_chars[index] != language_chars[index] {
      return false
    }
  }
  range_chars.length() == language_chars.length() ||
  language_chars[range_chars.length()] == '-'
}

///|
fn language_preference_precedes(
  left : LanguagePreference,
  right : LanguagePreference,
) -> Bool {
  if left.specificity != right.specificity {
    left.specificity > right.specificity
  } else {
    left.order < right.order
  }
}

///|
fn governing_language_preference(
  preferences : Array[LanguagePreference],
  language : String,
) -> LanguagePreference? {
  let mut best : LanguagePreference? = None
  for preference in preferences {
    if basic_language_matches(preference.range, language) {
      match best {
        None => best = Some(preference)
        Some(current) =>
          if language_preference_precedes(preference, current) {
            best = Some(preference)
          }
      }
    }
  }
  best
}

///|
fn score_language_candidate(
  language : String,
  preferences : Array[LanguagePreference],
  header_present : Bool,
  server_order : Int,
) -> LanguageCandidate {
  if !header_present {
    return {
      language,
      acceptable: true,
      quality: 1000,
      specificity: -1,
      client_order: -1,
      server_order,
      explanation: "accepted because Accept-Language is absent",
    }
  }
  match governing_language_preference(preferences, language) {
    None =>
      {
        language,
        acceptable: false,
        quality: 0,
        specificity: -1,
        client_order: -1,
        server_order,
        explanation: if preferences.length() == 0 {
          "rejected because Accept-Language contains no language ranges"
        } else {
          "no basic language range matches this representation"
        },
      }
    Some(preference) => {
      let kind = if preference.range == "*" {
        "wildcard language range"
      } else if preference.range == language {
        "exact language range"
      } else {
        "prefix language range"
      }
      {
        language,
        acceptable: preference.quality > 0,
        quality: preference.quality,
        specificity: preference.specificity,
        client_order: preference.order,
        server_order,
        explanation: if preference.quality == 0 {
          "rejected by \{kind} at client position \{preference.order + 1} (q=0)"
        } else {
          "matched \{kind} at client position \{preference.order + 1} with q=\{quality_text(preference.quality)}"
        },
      }
    }
  }
}

///|
fn language_candidate_precedes(
  left : LanguageCandidate,
  right : LanguageCandidate,
) -> Bool {
  if left.acceptable != right.acceptable {
    left.acceptable
  } else if left.quality != right.quality {
    left.quality > right.quality
  } else if left.specificity != right.specificity {
    left.specificity > right.specificity
  } else if left.client_order != right.client_order {
    left.client_order < right.client_order
  } else {
    left.server_order < right.server_order
  }
}

///|
/// Choose the best available language using RFC 4647 Basic Filtering.
///
/// `None` means the field was absent and every language is acceptable. A
/// present but empty value contains no ranges, so this strict policy returns
/// no selection. Equal scores are resolved by client order and then server
/// order.
pub fn negotiate_language(
  accept_language : String?,
  available : Array[String],
) -> Result[LanguageNegotiation, ParseError] {
  negotiate_language_with_limits(accept_language, available, Limits::default())
}

///|
/// Choose a language with explicit parsing and candidate limits.
pub fn negotiate_language_with_limits(
  accept_language : String?,
  available : Array[String],
  limits : Limits,
) -> Result[LanguageNegotiation, ParseError] {
  match
    check_available_limit(available.length(), limits, "available language tags") {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let (preferences, header_present) = match accept_language {
    None => ([], false)
    Some(value) =>
      match parse_accept_language_with_limits(value, limits) {
        Err(error) => return Err(error)
        Ok(parsed) => (parsed, true)
      }
  }
  let languages = []
  for language in available {
    match normalize_available_language(language) {
      Err(error) => return Err(error)
      Ok(normalized) => languages.push(normalized)
    }
  }
  let candidates = []
  let mut selected_index : Int? = None
  for index, language in languages {
    let candidate = score_language_candidate(
      language, preferences, header_present, index,
    )
    candidates.push(candidate)
    if candidate.acceptable {
      match selected_index {
        None => selected_index = Some(index)
        Some(current_index) =>
          if language_candidate_precedes(candidate, candidates[current_index]) {
            selected_index = Some(index)
          }
      }
    }
  }
  let selected = match selected_index {
    None => None
    Some(index) => Some(languages[index])
  }
  Ok({ selected, candidates, })
}

///|
pub fn LanguageNegotiation::selected_language(
  self : LanguageNegotiation,
) -> String? {
  self.selected
}

///|
/// Render a compact, deterministic language decision report.
pub fn LanguageNegotiation::summary(self : LanguageNegotiation) -> String {
  let out = StringBuilder()
  match self.selected {
    None => out.write_string("selected language: none")
    Some(language) => {
      out.write_string("selected language: ")
      out.write_string(language)
    }
  }
  for candidate in self.candidates {
    out.write_string("\n- ")
    out.write_string(candidate.language)
    out.write_string(": ")
    out.write_string(candidate.explanation)
  }
  out.to_string()
}
