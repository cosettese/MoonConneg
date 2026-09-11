///|
fn response_variant(
  id : String,
  media_type : String,
  encoding : String,
  language : String,
) -> @moonconneg.Variant {
  @moonconneg.Variant::parse(id, media_type, encoding, language).unwrap()
}

///|
test "response metadata exposes normalized selected headers" {
  let decision = @moonconneg.negotiate_variants(
    "application/json",
    Some("gzip"),
    Some("en"),
    [
      response_variant(
        "api", "Application/JSON; Charset=UTF-8", "GZip", "EN-us",
      ),
    ],
  ).unwrap()
  let metadata = decision.response_metadata().unwrap()
  assert_eq(metadata.variant_id, "api")
  assert_eq(metadata.content_type, "application/json; charset=UTF-8")
  assert_eq(metadata.content_encoding, Some("gzip"))
  assert_eq(metadata.content_language, "en-us")
  assert_eq(metadata.vary, "Accept, Accept-Encoding, Accept-Language")
}

///|
test "response metadata omits the identity content encoding" {
  let decision = @moonconneg.negotiate_variants("text/plain", None, None, [
    response_variant("plain", "text/plain", "identity", "en"),
  ]).unwrap()
  assert_eq(decision.response_metadata().unwrap().content_encoding, None)
}

///|
test "response metadata is absent when no variant is acceptable" {
  let decision = @moonconneg.negotiate_variants("*/*;q=0", None, None, [
    response_variant("plain", "text/plain", "identity", "en"),
  ]).unwrap()
  assert_eq(decision.response_metadata(), None)
}
