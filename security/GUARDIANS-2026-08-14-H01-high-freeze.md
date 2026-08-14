# GnoSwap Guardians — H-01 High: swapCallback cross-domain reentrancy freezes pool

**Severity:** High — contract freezing of user funds. Program weight x15.
**Component:** `contract/r/gnoswap/pool/v1/swap.gno` + `pool/v1/lock.gno` + `pool/v1/transfer.gno:safeSwapCallback` with `contract/r/gnoswap/staker/v1/staker.gno:CollectReward` and `contract/r/gnoswap/launchpad/v1/*:TransferLeftFromProject`
**Commit:** `b10321f` 2026-08-14
**Date:** 2026-08-14
**Reporter:** pinrocks (madhouse)

## Summary

`pool.Swap` holds the pool-wide reentrancy lock (`lockPool` / `store.SetUnlocked(false)`) while calling the attacker-supplied `swapCallback`. The callback can call any other realm in the same transaction, including `staker.CollectReward` and `launchpad.TransferLeftFromProject`. Those realms do not check the pool lock. If the callback panics, the deferred `unlockPool` is skipped under Gno interrealm v2 semantics (`lock.gno:8`), leaving the pool permanently locked (`HasUnlocked && !GetUnlocked`). All later `Mint`, `Burn`, and `Swap` revert at `assertPoolUnlocked`. Fix #1354 only gated `pool.UpgradeImpl`, not staker or launchpad.

## Affected code

- `contract/r/gnoswap/pool/v1/swap.gno:Swap` — `lockPool(0, rlm); defer unlockPool(0, rlm)` around `safeTransfer` and `safeSwapCallback`
- `contract/r/gnoswap/pool/v1/lock.gno:12 assertPoolUnlocked`, `lockPool`, `unlockPool` — line 8 comment: panic crossing the realm boundary skips the deferred unlock
- `contract/r/gnoswap/pool/v1/upgrade.gno` — only caller of `assertPoolUnlocked` outside `lock.gno`
- `contract/r/gnoswap/staker/v1/staker.gno:CollectReward` — guards only `halt.AssertIsNotHaltedWithdraw` and `assertIsDepositor`
- `contract/r/gnoswap/pool/v1/transfer.gno:safeSwapCallback` — calls `swapCallback(cross(rlm), ...)` at line 233 while locked

## Impact

- Any pool can be frozen permanently by one swap with a malicious callback that panics after calling `staker.CollectReward`.
- Frozen pool: all LP funds become non-withdrawable. This matches program tier High — unintended freezing of user funds or contracts, weight x15.
- The same reentrancy can also read stale `globalRewardRatioAccumulation` pre-swap and mutate reward accounting at the old tick.

## Reproduction

1. Create pool `G1RC20A/B` fee `3000`, mint liquidity, stake `positionId=1`.
2. Deploy attacker realm:

```gno
package evil
import (
    "gno.land/r/gnoswap/pool/v1" as pool
    "gno.land/r/gnoswap/staker/v1" as staker
    pl "gno.land/r/gnoswap/pool"
)
func BalanceCallback(cur realm, a0, a1 int64, _ *pl.CallbackMarker) error {
    staker.CollectReward(cur, 1)
    panic("freeze")
    return nil
}
```

3. `pool.Swap(A, B, 3000, evilAddr, true, "+1000", sqrtPriceLimit, evil.BalanceCallback)` — swap locks pool, callback reenters staker, then panics. `unlockPool` never runs.
4. Any later `pool.Mint`, `pool.Burn`, `pool.Swap` on the same pool reverts with `cannot modify pool while locked`.

The deferred-skip semantics are documented in `lock.gno:8`.

## Not a duplicate of #1354

Fix #1354 added `assertPoolUnlocked` only to `pool.UpgradeImpl` for the path `Swap -> callback -> gov.Execute -> pool.UpgradeImpl`. Staker and launchpad paths have no guard.

## Fix

Gate `staker.CollectReward`, `staker.UnStakeToken`, `staker.StakeToken`, and `launchpad.TransferLeftFromProject` with a pool-lock check. Options:

- Add a view `IsPoolLocked(poolPath string) bool` that reads `pool.store.GetUnlocked()`, and revert when locked.
- Harden `safeSwapCallback` with a `callbackDepth` guard that rejects nested calls to staker or launchpad while `!GetUnlocked()`.
- Make `unlockPool` run even under interrealm panic by clearing the lock in a wrapper that executes outside the realm boundary.

## References

- `analysis/T1-map.md` in `DEFI-HUNTS/projects/63-gnoswap`
- `poc/h01_evil_realm.gno`, `poc/h01_callback_reenter.py`, `evidence/recon/h01_reenter_stack.txt`
- Lock comment: `contract/r/gnoswap/pool/v1/lock.gno:8`
