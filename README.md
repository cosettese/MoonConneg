# MoonConneg

MoonConneg is a pure MoonBit core for deterministic, explainable HTTP content
negotiation. It is intended for web frameworks, API gateways, static servers,
and test tools that need one reusable implementation instead of ad-hoc header
splitting.

## Current capabilities

The current core provides:

- concrete `Content-Type` parsing;
- ordered `Accept` media-range parsing;
- strict q-values represented as integer thousandths;
- wildcard validation;
- media parameters and accept-extension separation;
- quoted values, escapes, duplicate checks, and source offsets in diagnostics;
- concrete representation matching with parameter constraints;
- RFC-style specificity precedence between exact, type wildcard, and `*/*`;
- deterministic tie-breaking by quality, specificity, parameter count, client
  order, and server order;
- explicit `q=0` refusal behavior and human-readable decision reports;
- `Accept-Encoding` parsing and deterministic coding selection, including the
  distinct semantics of an absent field, an empty field, wildcard exclusions,
  and the implicit `identity` fallback;
- `Accept-Language` parsing and deterministic RFC 4647 Basic Filtering with
  case-insensitive subtag matching, specific refusals, and wildcard fallback;
- portable behavior across MoonBit's supported backends, without FFI.

Run the current verification:

```bash
moon check --deny-warn
moon test --deny-warn
```

The next milestone will combine media type, encoding, and language into one
deterministic representation decision instead of exposing the three dimensions
as unrelated selectors.

## Project position

The project is an original MoonBit implementation guided by the HTTP semantics
and field syntax specifications. It does not copy another implementation. The
scope is deliberately framework-neutral: it selects representations but does
not open sockets, read files, or send responses.

See [ECOSYSTEM.md](ECOSYSTEM.md) for the public MoonBit projects checked for
overlap and the independent contribution MoonConneg intends to maintain.

## License

Apache-2.0.
