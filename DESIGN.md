# MoonConneg design

## Boundary

MoonConneg owns parsing and deterministic selection. HTTP transports and web
framework adapters stay outside the core package.

## Invariants

1. Media type, subtype, and parameter names are normalized to lowercase.
2. Quality is stored as an integer from 0 through 1000; no floating-point
   comparison participates in negotiation.
3. Accept order is retained so ties are reproducible.
4. Parameters before `q` constrain a match; parameters after `q` are accept
   extensions and do not constrain a representation.
5. Parse errors carry a character offset and describe the expected grammar.
6. An absent `Accept-Encoding` field and a present but empty field remain
   distinct: absence accepts every coding, while an empty value accepts only
   `identity`.

## Selection pipeline

1. Parse and validate the client preference fields.
2. Find every matching media range for each available representation.
3. Choose the most specific governing range for that representation.
4. Rank acceptable representations by quality, specificity, parameter count,
   client order, and finally server order.
5. Return both the winner and the scored candidates for diagnostics.

The governing media range is chosen by specificity and matching parameter
count before its q-value is applied. This is important for an explicit exact
`q=0`: a broader positive wildcard must not silently make that representation
acceptable again.

## Encoding policy

Available encodings use the token `identity` for an unencoded representation.
An exact coding preference governs before `*`, even when the exact preference
has a lower quality or rejects the coding. Identity is acceptable by default,
but `identity;q=0` or `*;q=0` without a more specific identity preference can
exclude it. Candidates are ranked by quality, exactness, client order, and
finally server order, and every candidate retains its reason for diagnostics.

## Language policy

Language negotiation uses RFC 4647 Basic Filtering. Comparisons are
case-insensitive, and a non-wildcard range matches either an equal tag or a tag
for which the range is a prefix ending at a hyphen boundary. More-specific
ranges govern before broader ranges, so `en-US;q=0` can reject `en-US` even when
`en;q=1` is present. The wildcard only governs languages without a more
specific matching range. A missing field accepts every available language; a
present empty field contains no acceptable ranges under the strict core policy.
