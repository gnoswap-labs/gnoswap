# GnoSwap Guardians — H-02 Low: applyWarmup double floor truncates dust reward

**Severity:** Low — rounds to Medium x3 when chained to EndExternalIncentive Shortfall display divergence.
**Component:** `contract/r/gnoswap/staker/v1/reward_calculation_warmup.gno:applyWarmup`
**Commit:** `b10321f` 2026-08-14
**Date:** 2026-08-14
**Reporter:** pinrocks (madhouse)

## Summary

`reward_calculation_warmup.gno:applyWarmup` computes per-position rewards with two successive floors:

```gno
perPositionReward = (poolReward * positionLiquidity) / stakedLiquidity  // floor
totalReward       = (perPositionReward * WarmupRatio) / 100            // floor
totalPenalty      = (perPositionReward * (100 - WarmupRatio)) / 100   // floor
```

Warmup tiers are 30, 50, 70. With dust `positionLiquidity=1` and `stakedLiquidity=1e12`, `poolReward=1e12` gives `perPosition=1`. Then `ratio=30` gives `reward=0` (`1*30/100 floor`), `penalty=0` (`1*70/100 floor`), sum `0`, lost `1` wei versus `perPosition=1`. Sibling function `reward_calculation_pool.gno:384 applyWarmup` already uses `gnsmath.SafeMulDivInt64(warmupReward, ratio, 100)` (single floor), but `warmup.gno` still uses raw `MulOverflow/Div` twice. Fix #1355 only covered the pool-side path.

## Example

- `stakedLiquidity=1e12`, `positionLiquidity=1`, `poolReward=1e12`, `WarmupRatio=30`.
- `perPosition = 1`.
- Current code: `reward=0`, `penalty=0`, `lost=1`.
- 1000 dust positions lose 1000 wei to remainder.

The remainder appears in `contract/r/gnoswap/staker/v1/external_incentive.gno:260 distributable = MulDiv(rewardPerSecondX128*duration, q128)` where `remainder = TotalReward - distributable` is expected near zero, and `EndExternalIncentive` caps refund to `poolLeftExternalRewardAmount` emitting `EndExternalIncentiveShortfall`.

## Proof

`poc/h02_m35_dust.py` replicates the u256 floor arithmetic:

```
dust 1/1e12 pool1e12 ratio30 => per=1  rew=0 pen=0 sum=0 lost=1  (1k dust -> lost 1000)
```

Run `python3 poc/h02_m35_dust.py` — see `evidence/recon/h02_m35_dust.txt`.

## Not a duplicate of #1355

Fix #1355 replaced `SafeMulInt64/100` with `SafeMulDivInt64` only in `reward_calculation_pool.gno:390`. The `warmup.gno:60` function was not touched, different file and line.

## Fix

Use `gnsmath.SafeMulDivInt64` or single `u256.MulDiv(perPosition, ratio, 100)` in `warmup.gno:applyWarmup`, and assert `reward + penalty == perPosition` or `perPosition - 1` (one rounding).

## References

- `poc/h02_m35_dust.py`, `evidence/recon/h02_m35_dust.txt`
- `contract/r/gnoswap/staker/v1/reward_calculation_warmup.gno:60-85`
- `contract/r/gnoswap/staker/v1/external_incentive.gno:191`
