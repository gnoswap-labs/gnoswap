# Position Module (`v1/position/`)

LP position NFT management.

## Key Files

| File | Purpose |
|------|---------|
| `mint.gno` | Position creation |
| `burn.gno` | Position burning (sets `burned` flag) |
| `liquidity_management.gno` | Liquidity add/remove logic |
| `reposition.gno` | Tick range change |
| `manager.gno` | Position manager |
| `position.gno` | Position data structures |

## Rules

- Positions are **non-transferable** except to/from the staker realm.
- `burned = true` must block `IncreaseLiquidity`. The NFT is not destroyed, only flagged.
- Slippage check in `DecreaseLiquidity`: compare against **actually received** amounts (from `Collect`), not amounts owed (from `Burn`).
- All position-altering operations (`Mint`, `IncreaseLiquidity`, `DecreaseLiquidity`, `Reposition`) must enforce a user-specified deadline via `assertIsNotExpired`.
- Position key is derived from `positionPackagePath` + tick range — **no owner component**. Two positions with the same tick range in the same package share a key.

## Pitfalls

- Slippage on owed amounts (not received) → user receives less than minimum.
- `burned = true` not checked → liquidity added to dead position.
- Missing deadline enforcement → stale transactions execute at unfavorable prices.
