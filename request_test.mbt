///|
fn request_variant(
  id : String,
  media_type : String,
  encoding : String,
  language : String,
) -> @moonconneg.Variant {
  @moonconneg.Variant::parse(id, media_type, encoding, language).unwrap()
}

///|
test "default request preferences preserve absent fields" {
  let preferences = @moonconneg.RequestPreferences::default()
  assert_eq(preferences.accept, None)
  assert_eq(preferences.accept_encoding, None)
  assert_eq(preferences.accept_language, None)
}

///|
test "absent Accept accepts every media type and preserves server order" {
  let decision = @moonconneg.negotiate_request(
    @moonconneg.RequestPreferences::default(),
    [
      request_variant("html", "text/html", "identity", "en"),
      request_variant("json", "application/json", "gzip", "fr"),
    ],
  ).unwrap()
  assert_eq(decision.selected_id(), Some("html"))
}

///|
test "typed request fields route all three preference dimensions" {
  let preferences : @moonconneg.RequestPreferences = {
    accept: Some("application/json"),
    accept_encoding: Some("gzip"),
    accept_language: Some("fr"),
  }
  let decision = @moonconneg.negotiate_request(preferences, [
    request_variant("json-en", "application/json", "identity", "en"),
    request_variant("json-fr", "application/json", "gzip", "fr"),
  ]).unwrap()
  assert_eq(decision.selected_id(), Some("json-fr"))
}

///|
test "typed request negotiation applies explicit limits" {
  let preferences : @moonconneg.RequestPreferences = {
    accept: None,
    accept_encoding: Some("gzip, br"),
    accept_language: None,
  }
  let limits : @moonconneg.Limits = {
    max_field_chars: 4,
    max_list_items: 8,
    max_parameters_per_item: 8,
    max_available: 8,
  }
  let result = @moonconneg.negotiate_request_with_limits(
    preferences,
    [request_variant("json", "application/json", "gzip", "en")],
    limits,
  )
  assert_true(result is Err(@moonconneg.LimitExceeded(_, _, _)))
}
