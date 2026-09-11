///|
fn variant(
  id : String,
  media_type : String,
  encoding : String,
  language : String,
) -> @moonconneg.Variant {
  @moonconneg.Variant::parse(id, media_type, encoding, language).unwrap()
}

///|
test "variant parsing normalizes every negotiated dimension" {
  let parsed = variant(
    "api", "Application/JSON; Charset=UTF-8", "GZip", "EN-us",
  )
  assert_eq(parsed.media_type.type_, "application")
  assert_eq(parsed.encoding, "gzip")
  assert_eq(parsed.language, "en-us")
}

///|
test "combined quality can outweigh one higher media preference" {
  let result = @moonconneg.negotiate_variants(
    "application/json;q=0.8, text/html;q=0.9",
    Some("br;q=0.9, identity;q=0.5"),
    Some("en;q=0.9, fr;q=1"),
    [
      variant("json-en-br", "application/json", "br", "en-US"),
      variant("html-fr", "text/html", "identity", "fr"),
    ],
  ).unwrap()
  assert_eq(result.selected_id(), Some("json-en-br"))
  assert_eq(result.candidates[0].combined_quality, 648000000)
  assert_eq(result.candidates[1].combined_quality, 450000000)
}

///|
test "rejection on any axis rejects the whole variant" {
  let result = @moonconneg.negotiate_variants(
    "application/json",
    Some("gzip;q=0"),
    Some("en"),
    [variant("api", "application/json", "gzip", "en")],
  ).unwrap()
  assert_eq(result.selected_id(), None)
  assert_false(result.candidates[0].acceptable)
  assert_false(result.candidates[0].encoding.acceptable)
}

///|
test "absent optional fields let media preference decide" {
  let result = @moonconneg.negotiate_variants(
    "text/html;q=0.4, application/json;q=0.9",
    None,
    None,
    [
      variant("html", "text/html", "identity", "en"),
      variant("json", "application/json", "gzip", "fr"),
    ],
  ).unwrap()
  assert_eq(result.selected_id(), Some("json"))
}

///|
test "media client order resolves an otherwise equal product" {
  let result = @moonconneg.negotiate_variants(
    "text/html;q=0.8, application/json;q=0.8",
    None,
    None,
    [
      variant("json", "application/json", "identity", "en"),
      variant("html", "text/html", "identity", "en"),
    ],
  ).unwrap()
  assert_eq(result.selected_id(), Some("html"))
}

///|
test "server order is the final variant tie breaker" {
  let result = @moonconneg.negotiate_variants(
    "application/json",
    Some("gzip"),
    Some("en"),
    [
      variant("first", "application/json", "gzip", "en-US"),
      variant("second", "application/json", "gzip", "en-GB"),
    ],
  ).unwrap()
  assert_eq(result.selected_id(), Some("first"))
}

///|
test "variant parser rejects wildcard server dimensions" {
  assert_true(
    @moonconneg.Variant::parse("bad", "application/json", "*", "en")
    is Err(@moonconneg.InvalidCoding(_, _)),
  )
  assert_true(
    @moonconneg.Variant::parse("bad", "application/json", "gzip", "*")
    is Err(@moonconneg.InvalidLanguage(_, _)),
  )
}

///|
test "variant summary contains all three axis explanations" {
  let result = @moonconneg.negotiate_variants(
    "application/json",
    Some("gzip"),
    Some("en"),
    [variant("api", "application/json", "gzip", "en")],
  ).unwrap()
  assert_eq(
    result.summary(),
    "selected variant: api (application/json; encoding=gzip; language=en)\n- api: acceptable; media: matched exact media range at client position 1 with q=1; encoding: matched exact coding at client position 1 with q=1; language: matched exact language range at client position 1 with q=1",
  )
}
