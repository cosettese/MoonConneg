///|
fn parameter_value_equal(name : String, left : String, right : String) -> Bool {
  if name == "charset" {
    left.to_lower() == right.to_lower()
  } else {
    left == right
  }
}

///|
fn MediaType::parameter(self : MediaType, name : String) -> String? {
  let normalized = name.to_lower()
  for parameter in self.parameters {
    if parameter.name == normalized {
      return Some(parameter.value)
    }
  }
  None
}

///|
fn MediaRange::specificity(self : MediaRange) -> Int {
  if self.type_ == "*" {
    0
  } else if self.subtype == "*" {
    1
  } else {
    2
  }
}

///|
fn MediaRange::matches(self : MediaRange, media_type : MediaType) -> Bool {
  if self.type_ != "*" && self.type_ != media_type.type_ {
    return false
  }
  if self.subtype != "*" && self.subtype != media_type.subtype {
    return false
  }
  for constraint in self.parameters {
    match media_type.parameter(constraint.name) {
      None => return false
      Some(actual) =>
        if !parameter_value_equal(constraint.name, constraint.value, actual) {
          return false
        }
    }
  }
  true
}

///|
fn range_precedes(left : MediaRange, right : MediaRange) -> Bool {
  let left_specificity = left.specificity()
  let right_specificity = right.specificity()
  if left_specificity != right_specificity {
    left_specificity > right_specificity
  } else if left.parameters.length() != right.parameters.length() {
    left.parameters.length() > right.parameters.length()
  } else {
    left.order < right.order
  }
}

///|
fn governing_range(
  ranges : Array[MediaRange],
  media_type : MediaType,
) -> MediaRange? {
  let mut best : MediaRange? = None
  for range in ranges {
    if range.matches(media_type) {
      match best {
        None => best = Some(range)
        Some(current) =>
          if range_precedes(range, current) {
            best = Some(range)
          }
      }
    }
  }
  best
}

///|
fn parameter_needs_quotes(value : String) -> Bool {
  let chars = value.to_array()
  if chars.length() == 0 {
    return true
  }
  for ch in chars {
    if !is_tchar(ch) {
      return true
    }
  }
  false
}

///|
fn write_parameter_value(out : StringBuilder, value : String) -> Unit {
  if !parameter_needs_quotes(value) {
    out.write_string(value)
    return
  }
  out.write_char('"')
  for ch in value {
    if ch == '"' || ch == '\\' {
      out.write_char('\\')
    }
    out.write_char(ch)
  }
  out.write_char('"')
}

///|
/// Render the normalized media type while preserving parameter order.
pub fn MediaType::to_string(self : MediaType) -> String {
  let out = StringBuilder()
  out.write_string(self.type_)
  out.write_char('/')
  out.write_string(self.subtype)
  for parameter in self.parameters {
    out.write_string("; ")
    out.write_string(parameter.name)
    out.write_char('=')
    write_parameter_value(out, parameter.value)
  }
  out.to_string()
}

///|
/// Parse one server representation with a stable application-defined id.
pub fn Representation::parse(
  id : String,
  media_type : String,
) -> Result[Representation, ParseError] {
  match parse_media_type(media_type) {
    Err(error) => Err(error)
    Ok(parsed) => Ok({ id, media_type: parsed, })
  }
}

///|
fn match_explanation(range : MediaRange) -> String {
  let kind = match range.specificity() {
    2 => "exact media range"
    1 => "type wildcard"
    _ => "global wildcard"
  }
  if range.quality == 0 {
    "rejected by \{kind} at client position \{range.order + 1} (q=0)"
  } else {
    "matched \{kind} at client position \{range.order + 1} with q=\{quality_text(range.quality)}"
  }
}

///|
fn score_candidate(
  representation : Representation,
  ranges : Array[MediaRange],
  server_order : Int,
) -> Candidate {
  match governing_range(ranges, representation.media_type) {
    None =>
      {
        id: representation.id,
        media_type: representation.media_type.to_string(),
        acceptable: false,
        quality: 0,
        specificity: -1,
        matched_parameters: 0,
        client_order: -1,
        server_order,
        explanation: "no media range matches this representation",
      }
    Some(range) =>
      {
        id: representation.id,
        media_type: representation.media_type.to_string(),
        acceptable: range.quality > 0,
        quality: range.quality,
        specificity: range.specificity(),
        matched_parameters: range.parameters.length(),
        client_order: range.order,
        server_order,
        explanation: match_explanation(range),
      }
  }
}

///|
fn candidate_precedes(left : Candidate, right : Candidate) -> Bool {
  if left.acceptable != right.acceptable {
    left.acceptable
  } else if left.quality != right.quality {
    left.quality > right.quality
  } else if left.specificity != right.specificity {
    left.specificity > right.specificity
  } else if left.matched_parameters != right.matched_parameters {
    left.matched_parameters > right.matched_parameters
  } else if left.client_order != right.client_order {
    left.client_order < right.client_order
  } else {
    left.server_order < right.server_order
  }
}

///|
/// Select from already parsed preferences and representations.
pub fn negotiate_ranges(
  ranges : Array[MediaRange],
  available : Array[Representation],
) -> Negotiation {
  let candidates = []
  let mut selected_index : Int? = None
  for index, representation in available {
    let candidate = score_candidate(representation, ranges, index)
    candidates.push(candidate)
    if candidate.acceptable {
      match selected_index {
        None => selected_index = Some(index)
        Some(current_index) =>
          if candidate_precedes(candidate, candidates[current_index]) {
            selected_index = Some(index)
          }
      }
    }
  }
  let selected = match selected_index {
    None => None
    Some(index) => Some(available[index])
  }
  { selected, candidates, }
}

///|
/// Parse an Accept field and choose the best server representation.
///
/// An empty field is treated as `*/*`. The winning order is quality,
/// specificity, matching parameter count, client order, then server order.
pub fn negotiate(
  accept : String,
  available : Array[Representation],
) -> Result[Negotiation, ParseError] {
  negotiate_with_limits(accept, available, Limits::default())
}

///|
/// Parse an Accept field and choose a representation with explicit limits.
pub fn negotiate_with_limits(
  accept : String,
  available : Array[Representation],
  limits : Limits,
) -> Result[Negotiation, ParseError] {
  match
    check_available_limit(
      available.length(),
      limits,
      "available media representations",
    ) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match parse_accept_with_limits(accept, limits) {
    Err(error) => Err(error)
    Ok(ranges) => Ok(negotiate_ranges(ranges, available))
  }
}

///|
/// Return the selected representation id, when negotiation succeeded.
pub fn Negotiation::selected_id(self : Negotiation) -> String? {
  match self.selected {
    None => None
    Some(representation) => Some(representation.id)
  }
}

///|
/// Render a compact, deterministic decision report for logs and tests.
pub fn Negotiation::summary(self : Negotiation) -> String {
  let out = StringBuilder()
  match self.selected {
    None => out.write_string("selected: none")
    Some(representation) => {
      out.write_string("selected: ")
      out.write_string(representation.id)
      out.write_string(" (")
      out.write_string(representation.media_type.to_string())
      out.write_char(')')
    }
  }
  for candidate in self.candidates {
    out.write_string("\n- ")
    out.write_string(candidate.id)
    out.write_string(": ")
    out.write_string(candidate.explanation)
  }
  out.to_string()
}
