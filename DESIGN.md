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

## Planned selection pipeline

1. Parse and validate the client preference fields.
2. Find every matching media range for each available representation.
3. Choose the most specific governing range for that representation.
4. Rank acceptable representations by quality, specificity, parameter count,
   client order, and finally server order.
5. Return both the winner and the scored candidates for diagnostics.
