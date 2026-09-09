///|
test "parses and normalizes a media type" {
  let parsed = @moonconneg.parse_media_type(
    "Application/JSON; Charset=\"UTF-8\"; profile=v1",
  )
  guard parsed is Ok(media_type) else { fail("valid media type expected") }
  assert_eq(media_type.type_, "application")
  assert_eq(media_type.subtype, "json")
  assert_eq(media_type.parameters.length(), 2)
  assert_eq(media_type.parameters[0].name, "charset")
  assert_eq(media_type.parameters[0].value, "UTF-8")
}

///|
test "rejects wildcard concrete media type" {
  assert_true(
    @moonconneg.parse_media_type("text/*")
    is Err(@moonconneg.InvalidWildcard(_)),
  )
}

///|
test "parses accept quality as exact thousandths" {
  let parsed = @moonconneg.parse_accept(
    "text/html;level=1;q=0.750; note=fast, application/json, */*;q=0.1",
  )
  guard parsed is Ok(ranges) else { fail("valid Accept field expected") }
  assert_eq(ranges.length(), 3)
  assert_eq(ranges[0].quality, 750)
  assert_eq(ranges[0].parameters.length(), 1)
  assert_eq(ranges[0].extensions.length(), 1)
  assert_eq(ranges[1].quality, 1000)
  assert_eq(ranges[2].type_, "*")
}

///|
test "empty accept means any representation" {
  let parsed = @moonconneg.parse_accept("")
  guard parsed is Ok(ranges) else { fail("empty Accept should be supported") }
  assert_eq(ranges.length(), 1)
  assert_eq(ranges[0].type_, "*")
  assert_eq(ranges[0].subtype, "*")
  assert_eq(ranges[0].quality, 1000)
}

///|
test "quoted commas stay inside one parameter" {
  let parsed = @moonconneg.parse_accept("text/plain;profile=\"a,b\";q=0.5")
  guard parsed is Ok(ranges) else { fail("quoted comma should parse") }
  assert_eq(ranges.length(), 1)
  assert_eq(ranges[0].parameters[0].value, "a,b")
}

///|
test "rejects malformed quality and duplicate parameters" {
  assert_true(
    @moonconneg.parse_accept("text/plain;q=.5")
    is Err(@moonconneg.InvalidQuality(_, _)),
  )
  assert_true(
    @moonconneg.parse_media_type("text/plain;charset=utf-8;charset=ascii")
    is Err(@moonconneg.DuplicateParameter(_, _)),
  )
}

///|
test "quality text is compact and deterministic" {
  assert_eq(@moonconneg.quality_text(0), "0")
  assert_eq(@moonconneg.quality_text(500), "0.5")
  assert_eq(@moonconneg.quality_text(875), "0.875")
  assert_eq(@moonconneg.quality_text(1000), "1")
}
