///|
test "adapter renders selected representation headers" {
  let response = render_response(
    "application/json, text/html;q=0.7",
    Some("gzip, identity;q=0.5"),
    Some("en-US, fr;q=0.6"),
  ).unwrap()
  assert_true(response.contains("HTTP/1.1 200 OK"))
  assert_true(
    response.contains("Content-Type: application/json; charset=utf-8"),
  )
  assert_true(response.contains("Content-Encoding: gzip"))
  assert_true(response.contains("Content-Language: en-us"))
  assert_true(response.contains("selected asset: json-en-gzip"))
}

///|
test "adapter renders 406 when every variant is refused" {
  let response = render_response("*/*;q=0", None, None).unwrap()
  assert_eq(
    response, "HTTP/1.1 406 Not Acceptable\nVary: Accept, Accept-Encoding, Accept-Language",
  )
}
