# Pool Module (`v1/pool/`)

Core AMM. All pools live in a single singleton realm.

## Key Files

| File | Purpose |
|------|---------|
| `swap.gno` | Swap execution, reentrancy lock, oracle |
| `pool.gno` | Pool data structures, Slot0 |
| `position.gno` | Per-pool position tracking |
| `manager.gno` | Pool creation |
| `liquidity_math.gno` | Liquidity calculations |
| `transfer.gno` | Token transfer helpers (`SafeGRC20Transfer`) |

## Rules

- **Slot0**: holds `sqrtPriceX96`, `tick`, `unlocked`. Persist reentrancy lock via `SetSlot0(...)` — local copy mutation has no effect.
- **Oracle**: write with **pre-swap** tick and liquidity. Post-swap values produce wrong TWAP.
- **feeGrowthOutside** on ticks: invert correctly at every `tickCross`.
- **Protocol fee**: capped at 25% of swap fees per token. Validate upper bound on any change.
- **Transfer**: use `SafeGRC20Transfer` in `transfer.gno`. Never add direct `tokenTeller` calls without panic-on-failure.
- **Tick range**: `[-887272, 887272]`. `MIN_SQRT_RATIO` / `MAX_SQRT_RATIO` are hard bounds.

## Swap Loop

Find next tick → `ComputeSwapStep` → accumulate fees → cross tick (update `liquidityNet`) → repeat until `amountSpecifiedRemaining == 0` or price limit hit.

## Swap Callback

```
Pool sends output → SwapCallback on router → router sends input to pool
```

Both checks required: `access.AssertIsPool(caller)` + `assertIsRouterV1()`.

## Reentrancy

`Slot0.unlocked` is the guard. Always call `SetSlot0(...)` to persist before any external call.

## AMM Primitives

| Primitive | Format | Detail |
|-----------|--------|--------|
| sqrtPriceX96 | Q64.96 | √price × 2^96 |
| feeGrowthGlobal | Q128.128 | Cumulative fee per unit liquidity |
| Tick range | int | `[-887272, 887272]` |
| Fee tiers | fixed | 0.01% / 0.05% / 0.3% / 1% — no new tiers post-deploy |

## Pitfalls

- Reentrancy lock on local `Slot0` copy → lock never persists.
- Oracle written with post-swap tick → wrong TWAP.
- `CreatePool` accepts arbitrary initial `sqrtPriceX96` with no price-oracle sanity check (audit N-03). Recovery: wide-range mint → corrective swap → remove.
