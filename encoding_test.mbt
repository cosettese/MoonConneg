///|
test "parses ordered encoding preferences and exact qvalues" {
  let parsed = @moonconneg.parse_accept_encoding("GZip; q=0.750, br, *;q=0.1").unwrap()
  assert_eq(parsed.length(), 3)
  assert_eq(parsed[0].coding, "gzip")
  assert_eq(parsed[0].quality, 750)
  assert_eq(parsed[1].quality, 1000)
  assert_eq(parsed[2].coding, "*")
}

///|
test "rejects invalid encoding parameters and duplicate quality" {
  assert_true(
    @moonconneg.parse_accept_encoding("gzip;level=1")
    is Err(@moonconneg.InvalidParameter(_, _, _)),
  )
  assert_true(
    @moonconneg.parse_accept_encoding("gzip;q=0.5;q=0.4")
    is Err(@moonconneg.DuplicateParameter(_, _)),
  )
}

///|
test "absent Accept-Encoding leaves choice to server order" {
  let result = @moonconneg.negotiate_encoding(None, ["br", "gzip", "identity"]).unwrap()
  assert_eq(result.selected_coding(), Some("br"))
  assert_eq(result.candidates[0].quality, 1000)
}

///|
test "empty Accept-Encoding permits only identity" {
  let result = @moonconneg.negotiate_encoding(Some(""), ["gzip", "identity"]).unwrap()
  assert_eq(result.selected_coding(), Some("identity"))
  assert_false(result.candidates[0].acceptable)
  assert_true(result.candidates[1].acceptable)
}

///|
test "highest explicit encoding quality wins" {
  let result = @moonconneg.negotiate_encoding(
    Some("br;q=0.4, gzip;q=0.8, identity;q=0.2"),
    ["br", "gzip", "identity"],
  ).unwrap()
  assert_eq(result.selected_coding(), Some("gzip"))
}

///|
test "exact refusal overrides a positive wildcard" {
  let result = @moonconneg.negotiate_encoding(Some("gzip;q=0, *;q=1"), [
    "gzip", "br", "identity",
  ]).unwrap()
  assert_eq(result.selected_coding(), Some("br"))
  assert_false(result.candidates[0].acceptable)
  assert_eq(result.candidates[0].specificity, 1)
}

///|
test "wildcard zero excludes implicit identity" {
  let result = @moonconneg.negotiate_encoding(Some("*;q=0"), ["br", "identity"]).unwrap()
  assert_eq(result.selected_coding(), None)
  assert_false(result.candidates[1].acceptable)
}

///|
test "explicit identity overrides wildcard zero" {
  let result = @moonconneg.negotiate_encoding(Some("*;q=0, identity;q=0.5"), [
    "gzip", "identity",
  ]).unwrap()
  assert_eq(result.selected_coding(), Some("identity"))
  assert_eq(result.candidates[1].quality, 500)
}

///|
test "unlisted coding falls back to implicit identity" {
  let result = @moonconneg.negotiate_encoding(Some("gzip;q=0.5"), [
    "br", "identity",
  ]).unwrap()
  assert_eq(result.selected_coding(), Some("identity"))
  assert_false(result.candidates[0].acceptable)
}

///|
test "encoding summary explains the decision" {
  let result = @moonconneg.negotiate_encoding(
    Some("gzip;q=0, identity;q=0.4"),
    ["gzip", "identity"],
  ).unwrap()
  assert_eq(
    result.summary(),
    "selected encoding: identity\n- gzip: rejected by exact coding at client position 1 (q=0)\n- identity: matched exact coding at client position 2 with q=0.4",
  )
}
