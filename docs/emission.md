# Emission Module (`r/gnoswap/emission/`)

GNS minting and distribution schedule.

## Rules

- `MintAndDistributeGns` returns `(int64, bool)`. The `bool` is `false` only when emission is halted; in that case the function returns `(0, false)` without panicking or automatically halting the caller. A caller that requires emission must explicitly handle the result.
- Minting authority: only `emission` calls `gns.MintGns`. Any other realm gaining mint access is a critical vulnerability.
- Distribution percentage changes invoke the staker cache-invalidation callback only when one is registered. `SetOnDistributionPctChangeCallback` accepts `nil` to clear it, so keeping the callback registered is a deployment invariant when staker cache invalidation is required.
- Allocation percentages (liquidity staker / devops / community pool / governance staker) must sum to 10000 basis points after any change.

## GNS Token (`r/gnoswap/gns/`)

- Mint callable only by `emission`. Verify access control on every mint path.
- Total supply accounting must be consistent with all minting and burning events.
- GRC-20 standard compliance: no hooks, no rebase, no transfer fees.

## Emission arithmetic

- The conceptual `baseEmission / (2^halvingCount)` formula is implemented as piecewise integer rates. Each year uses `floor(yearDistributionAmount / SECONDS_IN_YEAR)`.
- Mint ranges are inclusive, clamped to the 12-year schedule end, and crossed year boundaries are calculated one year at a time. When a range reaches a year end, the year's remaining integer amount (including division dust) is added.

## Pitfalls

- Treating a halted call's `false` result as an automatic abort is incorrect; callers must decide whether their own operation requires emission.
- Clearing or failing to register the distribution-change callback leaves staker caches without that invalidation signal.
- Off-chain calculators that omit inclusive seconds, schedule-end clamping, per-year integer division, or end-of-year remainder top-ups can disagree with on-chain mint amounts.
- Allocation percentages that do not sum to 10000 basis points are rejected.
