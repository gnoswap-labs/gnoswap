# Emission Module (`r/emission/`)

GNS minting and distribution schedule.

## Rules

- `MintAndDistributeGns` returns `(int64, bool)`. The `bool` indicates whether emission is active (not halted). **Every caller must check this bool** — ignoring it causes the calling module to halt when emission is paused.
- Minting authority: only `emission` calls `gns.Mint`. Any other realm gaining mint access is a critical vulnerability.
- Emission rate changes must trigger a cache-invalidation callback in staker. Missing this causes stale reward calculations until the next user interaction.
- Allocation percentages (stakers / devops / community pool / governance stakers) must sum to 100% after any change.

## GNS Token (`r/gns/`)

- Mint callable only by `emission`. Verify access control on every mint path.
- Total supply accounting must be consistent with all minting and burning events.
- GRC-20 standard compliance: no hooks, no rebase, no transfer fees.

## Pitfalls

- Halted emission not tolerated → halt cascades to unrelated modules (staker, gov).
- Emission rate change without staker cache invalidation → stale rewards until next user interaction.
- Allocation percentages don't sum to 100% → some emissions lost or over-distributed.
