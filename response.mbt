///|
/// Convert a successful three-axis decision into header-ready response data.
///
/// Returns `None` when the request has no acceptable variant. Adapters can map
/// that case to 406 Not Acceptable and map parser errors to 400 Bad Request.
pub fn VariantNegotiation::response_metadata(
  self : VariantNegotiation,
) -> ResponseMetadata? {
  match self.selected {
    None => None
    Some(variant) =>
      Some({
        variant_id: variant.id,
        content_type: variant.media_type.to_string(),
        content_encoding: if variant.encoding == "identity" {
          None
        } else {
          Some(variant.encoding)
        },
        content_language: variant.language,
        vary: "Accept, Accept-Encoding, Accept-Language",
      })
  }
}
