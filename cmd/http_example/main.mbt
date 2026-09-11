///|
fn available_variants() -> Array[@moonconneg.Variant] {
  [
    @moonconneg.Variant::parse(
      "json-en-gzip", "application/json; charset=utf-8", "gzip", "en-US",
    ).unwrap(),
    @moonconneg.Variant::parse(
      "json-fr-identity", "application/json; charset=utf-8", "identity", "fr",
    ).unwrap(),
    @moonconneg.Variant::parse(
      "html-en-identity", "text/html; charset=utf-8", "identity", "en",
    ).unwrap(),
  ]
}

///|
/// A framework adapter can pass request fields to MoonConneg and translate the
/// pure decision into its own response type. This example renders a response
/// head so the integration remains executable without a networking dependency.
fn render_response(
  preferences : @moonconneg.RequestPreferences,
) -> Result[String, @moonconneg.ParseError] {
  let decision = match
    @moonconneg.negotiate_request(preferences, available_variants()) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  match decision.response_metadata() {
    None =>
      Ok(
        "HTTP/1.1 406 Not Acceptable\nVary: Accept, Accept-Encoding, Accept-Language",
      )
    Some(metadata) => {
      let out = StringBuilder()
      out.write_string("HTTP/1.1 200 OK\nContent-Type: ")
      out.write_string(metadata.content_type)
      out.write_char('\n')
      match metadata.content_encoding {
        None => ()
        Some(encoding) => {
          out.write_string("Content-Encoding: ")
          out.write_string(encoding)
          out.write_char('\n')
        }
      }
      out.write_string("Content-Language: ")
      out.write_string(metadata.content_language)
      out.write_string("\nVary: ")
      out.write_string(metadata.vary)
      out.write_string("\n\n")
      out.write_string("selected asset: ")
      out.write_string(metadata.variant_id)
      out.write_string("\n\n")
      out.write_string(decision.summary())
      Ok(out.to_string())
    }
  }
}

///|
fn main {
  match
    render_response({
      accept: Some("application/json, text/html;q=0.7"),
      accept_encoding: Some("br;q=0.2, gzip;q=1, identity;q=0.5"),
      accept_language: Some("fr;q=0.6, en-US;q=1"),
    }) {
    Err(error) => {
      println("HTTP/1.1 400 Bad Request")
      println("")
      println(error.message())
    }
    Ok(response) => println(response)
  }
}
