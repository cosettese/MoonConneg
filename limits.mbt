///|
/// Conservative defaults suitable for ordinary HTTP applications.
pub fn Limits::default() -> Limits {
  {
    max_field_chars: 8192,
    max_list_items: 128,
    max_parameters_per_item: 32,
    max_available: 256,
  }
}

///|
/// Effectively disable resource limits while retaining integer accounting.
pub fn Limits::unlimited() -> Limits {
  {
    max_field_chars: 2147483647,
    max_list_items: 2147483647,
    max_parameters_per_item: 2147483647,
    max_available: 2147483647,
  }
}

///|
fn check_field_limit(
  input : String,
  limits : Limits,
) -> Result[Unit, ParseError] {
  let actual = input.to_array().length()
  if actual > limits.max_field_chars {
    Err(LimitExceeded("field characters", limits.max_field_chars, actual))
  } else {
    Ok(())
  }
}

///|
fn check_list_limit(
  actual : Int,
  limits : Limits,
  context : String,
) -> Result[Unit, ParseError] {
  if actual > limits.max_list_items {
    Err(LimitExceeded(context, limits.max_list_items, actual))
  } else {
    Ok(())
  }
}

///|
fn check_parameter_limit(
  actual : Int,
  limits : Limits,
  context : String,
) -> Result[Unit, ParseError] {
  if actual > limits.max_parameters_per_item {
    Err(LimitExceeded(context, limits.max_parameters_per_item, actual))
  } else {
    Ok(())
  }
}

///|
fn check_available_limit(
  actual : Int,
  limits : Limits,
  context : String,
) -> Result[Unit, ParseError] {
  if actual > limits.max_available {
    Err(LimitExceeded(context, limits.max_available, actual))
  } else {
    Ok(())
  }
}
