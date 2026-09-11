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
  accept : String,
  accept_encoding : String?,
  accept_language : String?,
) -> Result[String, @moonconneg.ParseError] {
  let decision = match
    @moonconneg.negotiate_variants(
      accept,
      accept_encoding,
      accept_language,
      available_variants(),
    ) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  match decision.selected {
    None =>
      Ok(
        "HTTP/1.1 406 Not Acceptable\nVary: Accept, Accept-Encoding, Accept-Language",
      )
    Some(variant) => {
      let out = StringBuilder()
      out.write_string("HTTP/1.1 200 OK\nContent-Type: ")
      out.write_string(variant.media_type.to_string())
      out.write_char('\n')
      if variant.encoding != "identity" {
        out.write_string("Content-Encoding: ")
        out.write_string(variant.encoding)
        out.write_char('\n')
      }
      out.write_string("Content-Language: ")
      out.write_string(variant.language)
      out.write_string("\nVary: Accept, Accept-Encoding, Accept-Language\n\n")
      out.write_string("selected asset: ")
      out.write_string(variant.id)
      out.write_string("\n\n")
      out.write_string(decision.summary())
      Ok(out.to_string())
    }
  }
}

///|
fn main {
  match
    render_response(
      "application/json, text/html;q=0.7",
      Some("br;q=0.2, gzip;q=1, identity;q=0.5"),
      Some("fr;q=0.6, en-US;q=1"),
    ) {
    Err(error) => {
      println("HTTP/1.1 400 Bad Request")
      println("")
      println(error.message())
    }
    Ok(response) => println(response)
  }
}
