///|
/// Parse and normalize one server representation variant.
///
/// Use `identity` as the encoding for an unencoded representation.
pub fn Variant::parse(
  id : String,
  media_type : String,
  encoding : String,
  language : String,
) -> Result[Variant, ParseError] {
  let parsed_media_type = match parse_media_type(media_type) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let parsed_encoding = match normalize_available_coding(encoding) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let parsed_language = match normalize_available_language(language) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  Ok({
    id,
    media_type: parsed_media_type,
    encoding: parsed_encoding,
    language: parsed_language,
  })
}

///|
fn score_variant(
  variant : Variant,
  media_ranges : Array[MediaRange],
  encoding_preferences : Array[EncodingPreference],
  encoding_header_present : Bool,
  encoding_field_empty : Bool,
  language_preferences : Array[LanguagePreference],
  language_header_present : Bool,
  server_order : Int,
) -> VariantCandidate {
  let representation : Representation = {
    id: variant.id,
    media_type: variant.media_type,
  }
  let media = score_candidate(representation, media_ranges, server_order)
  let encoding = score_encoding_candidate(
    variant.encoding,
    encoding_preferences,
    encoding_header_present,
    encoding_field_empty,
    server_order,
  )
  let language = score_language_candidate(
    variant.language,
    language_preferences,
    language_header_present,
    server_order,
  )
  let acceptable = media.acceptable &&
    encoding.acceptable &&
    language.acceptable
  let combined_quality = media.quality * encoding.quality * language.quality
  let explanation = if acceptable {
    "acceptable; media: \{media.explanation}; encoding: \{encoding.explanation}; language: \{language.explanation}"
  } else {
    "rejected; media: \{media.explanation}; encoding: \{encoding.explanation}; language: \{language.explanation}"
  }
  {
    id: variant.id,
    acceptable,
    combined_quality,
    media,
    encoding,
    language,
    server_order,
    explanation,
  }
}

///|
fn preference_order_precedes(left : Int, right : Int) -> Bool {
  if left == right {
    false
  } else if left < 0 {
    false
  } else if right < 0 {
    true
  } else {
    left < right
  }
}

///|
fn variant_candidate_precedes(
  left : VariantCandidate,
  right : VariantCandidate,
) -> Bool {
  if left.acceptable != right.acceptable {
    left.acceptable
  } else if left.combined_quality != right.combined_quality {
    left.combined_quality > right.combined_quality
  } else if left.media.quality != right.media.quality {
    left.media.quality > right.media.quality
  } else if left.language.quality != right.language.quality {
    left.language.quality > right.language.quality
  } else if left.encoding.quality != right.encoding.quality {
    left.encoding.quality > right.encoding.quality
  } else if left.media.specificity != right.media.specificity {
    left.media.specificity > right.media.specificity
  } else if left.language.specificity != right.language.specificity {
    left.language.specificity > right.language.specificity
  } else if left.encoding.specificity != right.encoding.specificity {
    left.encoding.specificity > right.encoding.specificity
  } else if left.media.client_order != right.media.client_order {
    preference_order_precedes(left.media.client_order, right.media.client_order)
  } else if left.language.client_order != right.language.client_order {
    preference_order_precedes(
      left.language.client_order,
      right.language.client_order,
    )
  } else if left.encoding.client_order != right.encoding.client_order {
    preference_order_precedes(
      left.encoding.client_order,
      right.encoding.client_order,
    )
  } else {
    left.server_order < right.server_order
  }
}

///|
/// Select one complete representation using all three preference fields.
///
/// Overall quality is the product of the media, encoding, and language qvalues
/// in integer thousandths. Product ties are resolved by the individual quality
/// values in media-language-encoding order, then by specificity, client order,
/// and finally server order. This fixed ordering is a documented MoonConneg
/// policy rather than a requirement imposed by HTTP.
pub fn negotiate_variants(
  accept : String,
  accept_encoding : String?,
  accept_language : String?,
  available : Array[Variant],
) -> Result[VariantNegotiation, ParseError] {
  let media_ranges = match parse_accept(accept) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let (encoding_preferences, encoding_header_present, encoding_field_empty) = match
    accept_encoding {
    None => ([], false, false)
    Some(value) =>
      match parse_accept_encoding(value) {
        Err(error) => return Err(error)
        Ok(parsed) => (parsed, true, parsed.length() == 0)
      }
  }
  let (language_preferences, language_header_present) = match accept_language {
    None => ([], false)
    Some(value) =>
      match parse_accept_language(value) {
        Err(error) => return Err(error)
        Ok(parsed) => (parsed, true)
      }
  }
  let candidates = []
  let mut selected_index : Int? = None
  for index, variant in available {
    let candidate = score_variant(
      variant, media_ranges, encoding_preferences, encoding_header_present, encoding_field_empty,
      language_preferences, language_header_present, index,
    )
    candidates.push(candidate)
    if candidate.acceptable {
      match selected_index {
        None => selected_index = Some(index)
        Some(current_index) =>
          if variant_candidate_precedes(candidate, candidates[current_index]) {
            selected_index = Some(index)
          }
      }
    }
  }
  let selected = match selected_index {
    None => None
    Some(index) => Some(available[index])
  }
  Ok({ selected, candidates, })
}

///|
pub fn VariantNegotiation::selected_id(self : VariantNegotiation) -> String? {
  match self.selected {
    None => None
    Some(variant) => Some(variant.id)
  }
}

///|
/// Render a compact report containing every dimension's decision.
pub fn VariantNegotiation::summary(self : VariantNegotiation) -> String {
  let out = StringBuilder()
  match self.selected {
    None => out.write_string("selected variant: none")
    Some(variant) => {
      out.write_string("selected variant: ")
      out.write_string(variant.id)
      out.write_string(" (")
      out.write_string(variant.media_type.to_string())
      out.write_string("; encoding=")
      out.write_string(variant.encoding)
      out.write_string("; language=")
      out.write_string(variant.language)
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
