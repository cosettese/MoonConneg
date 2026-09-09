///|
fn representation(
  id : String,
  media_type : String,
) -> @moonconneg.Representation {
  @moonconneg.Representation::parse(id, media_type).unwrap()
}

///|
test "empty Accept selects first server representation" {
  let result = @moonconneg.negotiate("", [
    representation("json", "application/json"),
    representation("html", "text/html"),
  ]).unwrap()
  assert_eq(result.selected_id(), Some("json"))
}

///|
test "higher quality representation wins" {
  let result = @moonconneg.negotiate(
    "application/json;q=0.6, text/html;q=0.9",
    [
      representation("json", "application/json"),
      representation("html", "text/html"),
    ],
  ).unwrap()
  assert_eq(result.selected_id(), Some("html"))
}

///|
test "specific range governs quality before global wildcard" {
  let result = @moonconneg.negotiate("text/*;q=0.9, text/html;q=0.4", [
    representation("html", "text/html"),
    representation("plain", "text/plain"),
  ]).unwrap()
  assert_eq(result.selected_id(), Some("plain"))
  assert_eq(result.candidates[0].quality, 400)
  assert_eq(result.candidates[1].quality, 900)
}

///|
test "specific q zero rejects a representation despite wildcard" {
  let result = @moonconneg.negotiate("text/html;q=0, */*;q=1", [
    representation("html", "text/html"),
    representation("json", "application/json"),
  ]).unwrap()
  assert_eq(result.selected_id(), Some("json"))
  assert_false(result.candidates[0].acceptable)
  assert_eq(result.candidates[0].specificity, 2)
}

///|
test "media range parameters constrain matching" {
  let result = @moonconneg.negotiate(
    "text/html;level=1;q=0.9, text/html;q=0.5",
    [
      representation("level1", "text/html;level=1"),
      representation("plain", "text/html"),
    ],
  ).unwrap()
  assert_eq(result.selected_id(), Some("level1"))
  assert_eq(result.candidates[0].matched_parameters, 1)
  assert_eq(result.candidates[1].matched_parameters, 0)
}

///|
test "charset values compare case insensitively" {
  let result = @moonconneg.negotiate("text/plain;charset=UTF-8", [
    representation("utf8", "text/plain;charset=utf-8"),
  ]).unwrap()
  assert_eq(result.selected_id(), Some("utf8"))
}

///|
test "accept extensions do not constrain representations" {
  let result = @moonconneg.negotiate("application/json;q=0.8;trace=on", [
    representation("json", "application/json"),
  ]).unwrap()
  assert_eq(result.selected_id(), Some("json"))
  assert_eq(result.candidates[0].quality, 800)
}

///|
test "client order breaks an equal score tie" {
  let result = @moonconneg.negotiate(
    "application/json;q=0.8, text/html;q=0.8",
    [
      representation("html", "text/html"),
      representation("json", "application/json"),
    ],
  ).unwrap()
  assert_eq(result.selected_id(), Some("json"))
}

///|
test "server order is the final deterministic tie breaker" {
  let result = @moonconneg.negotiate("text/*;q=0.8", [
    representation("plain", "text/plain"),
    representation("html", "text/html"),
  ]).unwrap()
  assert_eq(result.selected_id(), Some("plain"))
}

///|
test "returns no selection when every representation is refused" {
  let result = @moonconneg.negotiate("application/json;q=0, text/*;q=0", [
    representation("json", "application/json"),
    representation("html", "text/html"),
  ]).unwrap()
  assert_eq(result.selected_id(), None)
}

///|
test "normalizes media type serialization and quotes spaces" {
  let parsed = @moonconneg.parse_media_type(
    "Application/JSON; Charset=UTF-8; profile=\"public api\"",
  ).unwrap()
  assert_eq(
    parsed.to_string(),
    "application/json; charset=UTF-8; profile=\"public api\"",
  )
}

///|
test "summary explains winner and rejected candidate" {
  let result = @moonconneg.negotiate("application/json;q=0, text/html;q=0.7", [
    representation("json", "application/json"),
    representation("html", "text/html"),
  ]).unwrap()
  assert_eq(
    result.summary(),
    "selected: html (text/html)\n- json: rejected by exact media range at client position 1 (q=0)\n- html: matched exact media range at client position 2 with q=0.7",
  )
}
