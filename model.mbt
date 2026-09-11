///|
/// One media type parameter. Names are stored in lowercase.
pub(all) struct Parameter {
  name : String
  value : String
} derive(Eq, Debug)

///|
/// A concrete representation media type such as `application/json`.
pub(all) struct MediaType {
  type_ : String
  subtype : String
  parameters : Array[Parameter]
} derive(Eq, Debug)

///|
/// One range from an HTTP Accept field. Quality uses integer thousandths.
pub(all) struct MediaRange {
  type_ : String
  subtype : String
  parameters : Array[Parameter]
  quality : Int
  extensions : Array[Parameter]
  order : Int
} derive(Eq, Debug)

///|
/// A server representation available for selection.
pub(all) struct Representation {
  id : String
  media_type : MediaType
} derive(Eq, Debug)

///|
/// The score and explanation assigned to one server representation.
pub(all) struct Candidate {
  id : String
  media_type : String
  acceptable : Bool
  quality : Int
  specificity : Int
  matched_parameters : Int
  client_order : Int
  server_order : Int
  explanation : String
} derive(Eq, Debug)

///|
/// A complete deterministic negotiation decision.
pub(all) struct Negotiation {
  selected : Representation?
  candidates : Array[Candidate]
} derive(Eq, Debug)

///|
/// One ordered preference from an Accept-Encoding field.
pub(all) struct EncodingPreference {
  coding : String
  quality : Int
  order : Int
} derive(Eq, Debug)

///|
/// The score and explanation assigned to one available content coding.
pub(all) struct EncodingCandidate {
  coding : String
  acceptable : Bool
  quality : Int
  specificity : Int
  client_order : Int
  server_order : Int
  explanation : String
} derive(Eq, Debug)

///|
/// A complete deterministic Accept-Encoding decision.
pub(all) struct EncodingNegotiation {
  selected : String?
  candidates : Array[EncodingCandidate]
} derive(Eq, Debug)

///|
/// One ordered preference from an Accept-Language field.
pub(all) struct LanguagePreference {
  range : String
  quality : Int
  specificity : Int
  order : Int
} derive(Eq, Debug)

///|
/// The score and explanation assigned to one available language tag.
pub(all) struct LanguageCandidate {
  language : String
  acceptable : Bool
  quality : Int
  specificity : Int
  client_order : Int
  server_order : Int
  explanation : String
} derive(Eq, Debug)

///|
/// A complete deterministic Accept-Language decision.
pub(all) struct LanguageNegotiation {
  selected : String?
  candidates : Array[LanguageCandidate]
} derive(Eq, Debug)

///|
/// One complete server representation across all negotiated dimensions.
pub(all) struct Variant {
  id : String
  media_type : MediaType
  encoding : String
  language : String
} derive(Eq, Debug)

///|
/// The three-axis score and explanation assigned to one variant.
pub(all) struct VariantCandidate {
  id : String
  acceptable : Bool
  combined_quality : Int
  media : Candidate
  encoding : EncodingCandidate
  language : LanguageCandidate
  server_order : Int
  explanation : String
} derive(Eq, Debug)

///|
/// A deterministic decision across media type, encoding, and language.
pub(all) struct VariantNegotiation {
  selected : Variant?
  candidates : Array[VariantCandidate]
} derive(Eq, Debug)

///|
/// Header-ready metadata for a selected complete representation.
///
/// `content_encoding` is absent for the identity coding because HTTP responses
/// normally omit Content-Encoding when no transformation was applied.
pub(all) struct ResponseMetadata {
  variant_id : String
  content_type : String
  content_encoding : String?
  content_language : String
  vary : String
} derive(Eq, Debug)

///|
/// Resource limits applied before or during parsing and selection.
pub(all) struct Limits {
  max_field_chars : Int
  max_list_items : Int
  max_parameters_per_item : Int
  max_available : Int
} derive(Eq, Debug)

///|
/// Source-aware diagnostics for parsed content negotiation fields.
pub(all) enum ParseError {
  EmptyInput
  UnexpectedEnd(Int, String)
  UnexpectedCharacter(Int, Char, String)
  InvalidToken(Int, String)
  InvalidWildcard(Int)
  InvalidCoding(Int, String)
  InvalidLanguage(Int, String)
  InvalidQuality(Int, String)
  DuplicateParameter(Int, String)
  InvalidParameter(Int, String, String)
  LimitExceeded(String, Int, Int)
} derive(Eq, Debug)

///|
pub fn ParseError::message(self : ParseError) -> String {
  match self {
    EmptyInput => "header value is empty"
    UnexpectedEnd(offset, expected) =>
      "unexpected end at offset \{offset}; expected \{expected}"
    UnexpectedCharacter(offset, found, expected) =>
      "unexpected character '\{found}' at offset \{offset}; expected \{expected}"
    InvalidToken(offset, context) =>
      "invalid or empty token at offset \{offset} for \{context}"
    InvalidWildcard(offset) =>
      "invalid wildcard at offset \{offset}; only */* and type/* are allowed"
    InvalidCoding(offset, coding) =>
      "invalid content coding '\{coding}' at offset \{offset}"
    InvalidLanguage(offset, language) =>
      "invalid basic language range or tag '\{language}' at offset \{offset}"
    InvalidQuality(offset, value) =>
      "invalid q value '\{value}' at offset \{offset}; expected 0..1 with at most three decimals"
    DuplicateParameter(offset, name) =>
      "duplicate parameter '\{name}' at offset \{offset}"
    InvalidParameter(offset, name, context) =>
      "parameter '\{name}' is not allowed at offset \{offset} for \{context}"
    LimitExceeded(resource, limit, actual) =>
      "\{resource} limit exceeded: maximum \{limit}, got \{actual}"
  }
}

///|
pub fn quality_text(quality : Int) -> String {
  if quality <= 0 {
    "0"
  } else if quality >= 1000 {
    "1"
  } else {
    let hundreds = quality / 100
    let tens = quality / 10 % 10
    let ones = quality % 10
    if ones != 0 {
      "0.\{hundreds}\{tens}\{ones}"
    } else if tens != 0 {
      "0.\{hundreds}\{tens}"
    } else {
      "0.\{hundreds}"
    }
  }
}
