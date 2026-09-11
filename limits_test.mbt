///|
fn limits(
  field_chars : Int,
  list_items : Int,
  parameters : Int,
  available : Int,
) -> @moonconneg.Limits {
  @moonconneg.Limits::{
    max_field_chars: field_chars,
    max_list_items: list_items,
    max_parameters_per_item: parameters,
    max_available: available,
  }
}

///|
test "default limits are finite and production oriented" {
  let value = @moonconneg.Limits::default()
  assert_eq(value.max_field_chars, 8192)
  assert_eq(value.max_list_items, 128)
  assert_eq(value.max_parameters_per_item, 32)
  assert_eq(value.max_available, 256)
}

///|
test "field character limit rejects oversized input before parsing" {
  let result = @moonconneg.parse_accept_with_limits(
    "text/plain",
    limits(4, 8, 8, 8),
  )
  assert_true(result is Err(@moonconneg.LimitExceeded(_, _, _)))
}

///|
test "media range item limit is enforced" {
  let result = @moonconneg.parse_accept_with_limits(
    "text/plain, text/html",
    limits(100, 1, 8, 8),
  )
  assert_true(result is Err(@moonconneg.LimitExceeded(_, _, _)))
}

///|
test "Content-Type parameter limit is enforced" {
  let result = @moonconneg.parse_media_type_with_limits(
    "text/plain;a=1;b=2",
    limits(100, 8, 1, 8),
  )
  assert_true(result is Err(@moonconneg.LimitExceeded(_, _, _)))
}

///|
test "encoding and language list limits are enforced" {
  let constrained = limits(100, 1, 8, 8)
  assert_true(
    @moonconneg.parse_accept_encoding_with_limits("gzip, br", constrained)
    is Err(@moonconneg.LimitExceeded(_, _, _)),
  )
  assert_true(
    @moonconneg.parse_accept_language_with_limits("en, fr", constrained)
    is Err(@moonconneg.LimitExceeded(_, _, _)),
  )
}

///|
test "available variant limit is enforced before scoring" {
  let variants = [
    @moonconneg.Variant::parse("one", "application/json", "identity", "en").unwrap(),
    @moonconneg.Variant::parse("two", "application/json", "gzip", "fr").unwrap(),
  ]
  let result = @moonconneg.negotiate_variants_with_limits(
    "application/json",
    None,
    None,
    variants,
    limits(100, 8, 8, 1),
  )
  assert_true(result is Err(@moonconneg.LimitExceeded(_, _, _)))
}

///|
test "callers can raise limits for trusted large preference lists" {
  let result = @moonconneg.parse_accept_with_limits(
    "text/plain, text/html",
    limits(100, 2, 8, 8),
  ).unwrap()
  assert_eq(result.length(), 2)
}

///|
test "unlimited configuration preserves ordinary negotiation" {
  let result = @moonconneg.negotiate_encoding_with_limits(
    Some("br;q=1, gzip;q=0.5"),
    ["gzip", "br"],
    @moonconneg.Limits::unlimited(),
  ).unwrap()
  assert_eq(result.selected_coding(), Some("br"))
}
