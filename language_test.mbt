///|
test "parses and normalizes ordered language preferences" {
  let parsed = @moonconneg.parse_accept_language(
    "ZH-Hant-TW; q=0.750, en-US, *;q=0.1",
  ).unwrap()
  assert_eq(parsed.length(), 3)
  assert_eq(parsed[0].range, "zh-hant-tw")
  assert_eq(parsed[0].quality, 750)
  assert_eq(parsed[0].specificity, 3)
  assert_eq(parsed[1].quality, 1000)
  assert_eq(parsed[2].specificity, 0)
}

///|
test "Accept-Language ignores empty list members" {
  let parsed = @moonconneg.parse_accept_language(", en-US, , fr,").unwrap()
  assert_eq(parsed.length(), 2)
  assert_eq(parsed[0].range, "en-us")
  assert_eq(parsed[0].order, 0)
  assert_eq(parsed[1].range, "fr")
  assert_eq(parsed[1].order, 1)
  assert_eq(@moonconneg.parse_accept_language(",,,").unwrap(), [])
}

///|
test "rejects invalid language ranges and parameters" {
  assert_true(
    @moonconneg.parse_accept_language("en-abcdefghi")
    is Err(@moonconneg.InvalidLanguage(_, _)),
  )
  assert_true(
    @moonconneg.parse_accept_language("en;level=1")
    is Err(@moonconneg.InvalidParameter(_, _, _)),
  )
}

///|
test "absent Accept-Language leaves choice to server order" {
  let result = @moonconneg.negotiate_language(None, ["fr", "en-US"]).unwrap()
  assert_eq(result.selected_language(), Some("fr"))
  assert_eq(result.candidates[0].quality, 1000)
}

///|
test "empty Accept-Language contains no acceptable range" {
  let result = @moonconneg.negotiate_language(Some(""), ["en", "fr"]).unwrap()
  assert_eq(result.selected_language(), None)
  assert_false(result.candidates[0].acceptable)
  assert_false(result.candidates[1].acceptable)
}

///|
test "higher language quality wins" {
  let result = @moonconneg.negotiate_language(Some("fr;q=0.5, en;q=0.9"), [
    "fr-FR", "en-US",
  ]).unwrap()
  assert_eq(result.selected_language(), Some("en-us"))
}

///|
test "basic filtering matches only at a subtag boundary" {
  let result = @moonconneg.negotiate_language(Some("de-DE"), [
    "de-Deva", "de-DE-1996",
  ]).unwrap()
  assert_eq(result.selected_language(), Some("de-de-1996"))
  assert_false(result.candidates[0].acceptable)
}

///|
test "specific language refusal governs before broad range" {
  let result = @moonconneg.negotiate_language(Some("en;q=1, en-US;q=0"), [
    "en-US", "en-GB",
  ]).unwrap()
  assert_eq(result.selected_language(), Some("en-gb"))
  assert_false(result.candidates[0].acceptable)
  assert_eq(result.candidates[0].specificity, 2)
}

///|
test "wildcard is a fallback for otherwise unmatched languages" {
  let result = @moonconneg.negotiate_language(Some("en;q=0.4, *;q=0.8"), [
    "en-US", "fr",
  ]).unwrap()
  assert_eq(result.selected_language(), Some("fr"))
  assert_eq(result.candidates[0].quality, 400)
  assert_eq(result.candidates[1].quality, 800)
}

///|
test "client order breaks equal language scores" {
  let result = @moonconneg.negotiate_language(Some("fr;q=0.8, en;q=0.8"), [
    "en", "fr",
  ]).unwrap()
  assert_eq(result.selected_language(), Some("fr"))
}

///|
test "server order is final language tie breaker" {
  let result = @moonconneg.negotiate_language(Some("en;q=0.8"), [
    "en-US", "en-GB",
  ]).unwrap()
  assert_eq(result.selected_language(), Some("en-us"))
}

///|
test "language summary explains the decision" {
  let result = @moonconneg.negotiate_language(Some("en-US;q=0, en;q=0.7"), [
    "en-US", "en-GB",
  ]).unwrap()
  assert_eq(
    result.summary(),
    "selected language: en-gb\n- en-us: rejected by exact language range at client position 1 (q=0)\n- en-gb: matched prefix language range at client position 2 with q=0.7",
  )
}
