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
/// Source-aware parse diagnostics for Content-Type and Accept fields.
pub(all) enum ParseError {
  EmptyInput
  UnexpectedEnd(Int, String)
  UnexpectedCharacter(Int, Char, String)
  InvalidToken(Int, String)
  InvalidWildcard(Int)
  InvalidQuality(Int, String)
  DuplicateParameter(Int, String)
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
    InvalidQuality(offset, value) =>
      "invalid q value '\{value}' at offset \{offset}; expected 0..1 with at most three decimals"
    DuplicateParameter(offset, name) =>
      "duplicate parameter '\{name}' at offset \{offset}"
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
