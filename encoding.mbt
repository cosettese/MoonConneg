///|
/// Parse an Accept-Encoding field into ordered content-coding preferences.
///
/// An empty field produces no explicit preferences. This is distinct from an
/// absent field and is interpreted by `negotiate_encoding` as requesting only
/// the identity representation.
pub fn parse_accept_encoding(
  input : String,
) -> Result[Array[EncodingPreference], ParseError] {
  parse_accept_encoding_with_limits(input, Limits::default())
}

///|
/// Parse an Accept-Encoding field with explicit resource limits.
pub fn parse_accept_encoding_with_limits(
  input : String,
  limits : Limits,
) -> Result[Array[EncodingPreference], ParseError] {
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
    match check_list_limit(order + 1, limits, "Accept-Encoding items") {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    cursor.skip_ows()
    let coding = match cursor.token("content coding") {
      Ok(value) => value.to_lower()
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
          parameter_count, limits, "Accept-Encoding parameters",
        ) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let (parameter, offset) = match cursor.parameter() {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if parameter.name != "q" {
        return Err(InvalidParameter(offset, parameter.name, "Accept-Encoding"))
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
    preferences.push({ coding, quality, order, })
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
      return Err(UnexpectedEnd(cursor.pos, "content coding after comma"))
    }
  }
  Ok(preferences)
}

///|
fn normalize_available_coding(input : String) -> Result[String, ParseError] {
  let cursor = Cursor::new(input)
  cursor.skip_ows()
  if cursor.end() {
    return Err(InvalidCoding(0, input))
  }
  let offset = cursor.pos
  let coding = match cursor.token("available content coding") {
    Ok(value) => value.to_lower()
    Err(error) => return Err(error)
  }
  cursor.skip_ows()
  if !cursor.end() {
    match cursor.peek() {
      Some(ch) =>
        return Err(
          UnexpectedCharacter(cursor.pos, ch, "end of available content coding"),
        )
      None => ()
    }
  }
  if coding == "*" {
    return Err(InvalidCoding(offset, coding))
  }
  Ok(coding)
}

///|
fn first_encoding_preference(
  preferences : Array[EncodingPreference],
  coding : String,
) -> EncodingPreference? {
  for preference in preferences {
    if preference.coding == coding {
      return Some(preference)
    }
  }
  None
}

///|
fn explicit_encoding_candidate(
  coding : String,
  preference : EncodingPreference,
  specificity : Int,
  server_order : Int,
) -> EncodingCandidate {
  let kind = if specificity == 1 { "exact coding" } else { "wildcard" }
  let explanation = if preference.quality == 0 {
    "rejected by \{kind} at client position \{preference.order + 1} (q=0)"
  } else {
    "matched \{kind} at client position \{preference.order + 1} with q=\{quality_text(preference.quality)}"
  }
  {
    coding,
    acceptable: preference.quality > 0,
    quality: preference.quality,
    specificity,
    client_order: preference.order,
    server_order,
    explanation,
  }
}

///|
fn score_encoding_candidate(
  coding : String,
  preferences : Array[EncodingPreference],
  header_present : Bool,
  field_empty : Bool,
  server_order : Int,
) -> EncodingCandidate {
  if !header_present {
    return {
      coding,
      acceptable: true,
      quality: 1000,
      specificity: -1,
      client_order: -1,
      server_order,
      explanation: "accepted because Accept-Encoding is absent",
    }
  }
  match first_encoding_preference(preferences, coding) {
    Some(preference) =>
      return explicit_encoding_candidate(coding, preference, 1, server_order)
    None => ()
  }
  let wildcard = first_encoding_preference(preferences, "*")
  if coding == "identity" {
    match wildcard {
      Some(preference) if preference.quality == 0 =>
        return explicit_encoding_candidate(coding, preference, 0, server_order)
      _ =>
        return {
          coding,
          acceptable: true,
          quality: 1000,
          specificity: -1,
          client_order: -1,
          server_order,
          explanation: if field_empty {
            "selected identity because Accept-Encoding is empty"
          } else {
            "identity is acceptable by default with q=1"
          },
        }
    }
  }
  match wildcard {
    Some(preference) =>
      explicit_encoding_candidate(coding, preference, 0, server_order)
    None =>
      {
        coding,
        acceptable: false,
        quality: 0,
        specificity: -1,
        client_order: -1,
        server_order,
        explanation: if field_empty {
          "rejected because an empty Accept-Encoding permits only identity"
        } else {
          "no content-coding preference matches this representation"
        },
      }
  }
}

///|
fn encoding_candidate_precedes(
  left : EncodingCandidate,
  right : EncodingCandidate,
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
/// Choose the best available content coding according to Accept-Encoding.
///
/// `None` means the field was absent, while `Some("")` means it was present
/// with an empty value. Available codings use `identity` for an unencoded
/// representation. Equal scores are resolved by client order and then server
/// order.
pub fn negotiate_encoding(
  accept_encoding : String?,
  available : Array[String],
) -> Result[EncodingNegotiation, ParseError] {
  negotiate_encoding_with_limits(accept_encoding, available, Limits::default())
}

///|
/// Choose a content coding with explicit parsing and candidate limits.
pub fn negotiate_encoding_with_limits(
  accept_encoding : String?,
  available : Array[String],
  limits : Limits,
) -> Result[EncodingNegotiation, ParseError] {
  match
    check_available_limit(
      available.length(),
      limits,
      "available content codings",
    ) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let (preferences, header_present, field_empty) = match accept_encoding {
    None => ([], false, false)
    Some(value) =>
      match parse_accept_encoding_with_limits(value, limits) {
        Err(error) => return Err(error)
        Ok(parsed) => (parsed, true, parsed.length() == 0)
      }
  }
  let codings = []
  for coding in available {
    match normalize_available_coding(coding) {
      Err(error) => return Err(error)
      Ok(normalized) => codings.push(normalized)
    }
  }
  let candidates = []
  let mut selected_index : Int? = None
  for index, coding in codings {
    let candidate = score_encoding_candidate(
      coding, preferences, header_present, field_empty, index,
    )
    candidates.push(candidate)
    if candidate.acceptable {
      match selected_index {
        None => selected_index = Some(index)
        Some(current_index) =>
          if encoding_candidate_precedes(candidate, candidates[current_index]) {
            selected_index = Some(index)
          }
      }
    }
  }
  let selected = match selected_index {
    None => None
    Some(index) => Some(codings[index])
  }
  Ok({ selected, candidates, })
}

///|
pub fn EncodingNegotiation::selected_coding(
  self : EncodingNegotiation,
) -> String? {
  self.selected
}

///|
/// Render a compact, deterministic encoding decision report.
pub fn EncodingNegotiation::summary(self : EncodingNegotiation) -> String {
  let out = StringBuilder()
  match self.selected {
    None => out.write_string("selected encoding: none")
    Some(coding) => {
      out.write_string("selected encoding: ")
      out.write_string(coding)
    }
  }
  for candidate in self.candidates {
    out.write_string("\n- ")
    out.write_string(candidate.coding)
    out.write_string(": ")
    out.write_string(candidate.explanation)
  }
  out.to_string()
}
