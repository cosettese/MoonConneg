///|
/// Construct request preferences with all three fields absent.
pub fn RequestPreferences::default() -> RequestPreferences {
  { accept: None, accept_encoding: None, accept_language: None, }
}

///|
/// Select a complete representation from typed HTTP request preferences.
///
/// An absent Accept field accepts every media type, as required by HTTP. The
/// optional encoding and language fields retain their distinct absent-field
/// semantics.
pub fn negotiate_request(
  preferences : RequestPreferences,
  available : Array[Variant],
) -> Result[VariantNegotiation, ParseError] {
  negotiate_request_with_limits(preferences, available, Limits::default())
}

///|
/// Select from typed request preferences with explicit resource limits.
pub fn negotiate_request_with_limits(
  preferences : RequestPreferences,
  available : Array[Variant],
  limits : Limits,
) -> Result[VariantNegotiation, ParseError] {
  let accept = match preferences.accept {
    None => ""
    Some(value) => value
  }
  negotiate_variants_with_limits(
    accept,
    preferences.accept_encoding,
    preferences.accept_language,
    available,
    limits,
  )
}
