# Ecosystem position

This document records a public ecosystem check performed on 2026-09-10. It is
not a claim that no other implementation can exist; it explains the closest
MoonBit projects found and the boundary MoonConneg intends to preserve.

## Closest projects

| Project | Existing capability | Boundary from MoonConneg |
| --- | --- | --- |
| [f4ah6o/http11](https://mooncakes.io/docs/f4ah6o/http11) | Parses `Accept`, `Accept-Charset`, `Accept-Encoding`, and `Accept-Language` as part of a broad Sans I/O HTTP/1.1 package. | Its published acceptance-field API exposes parsed items and serialization. MoonConneg focuses on ranking server representations and returning an explainable decision. |
| [RabitLogic/mbit](https://mooncakes.io/docs/RabitLogic/mbit) | Provides `Context::negotiate_format` inside a Gin-inspired web framework. | The helper is tied to framework context and performs simple exact or `*/*` matching. MoonConneg is transport-independent and applies quality, specificity, parameter, and stable tie-breaking rules. |
| [moonbit-community/crescent](https://mooncakes.io/docs/bobzhang/crescent) | Selects precompressed static assets from `Accept-Encoding`. | The logic belongs to static-file serving and only treats explicit zero quality as refusal. MoonConneg models general server candidates and exposes the complete scoring result. |

Other public GitHub matches inspected during the check were header-name tables
or compression middleware rather than reusable representation-selection
engines.

## Independent contribution

MoonConneg is designed as a framework-neutral policy engine with these
responsibilities:

- parse preference fields with precise errors and source offsets;
- determine the governing client range for every server representation;
- preserve exact refusal semantics such as a specific `q=0` overriding a
  broader positive wildcard;
- rank candidates deterministically, including client and server order as
  explicit final tie-breakers;
- return candidate-level reasons suitable for logs, tests, and debugging;
- combine media type, content encoding, and language preferences in one
  decision instead of exposing unrelated parsers.

MoonConneg does not contain code copied from the projects above and does not
currently depend on them. If a future adapter or fixture is derived from
another project, its origin, license, and scope will be documented with that
change.
