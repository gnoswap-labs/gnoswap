// PKGPATH: gno.land/r/gnoswap/v1/main
// callback-time staking observes finalized staker tick-cross accounting
//

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/scenarioutils"
	sr "gno.land/r/gnoswap/staker"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

const (
	fee        uint32 = 100
	maxApprove int64  = 9223372036854775807
	deadline   int64  = 9999999999

	referencePositionID uint64 = 1
	callbackPositionID  uint64 = 2
	honestPositionID    uint64 = 3
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())

	barPath  = "gno.land/r/onbloc/bar.BAR"
	bazPath  = "gno.land/r/onbloc/baz.BAZ"
	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"

	referenceLiquidity string
	honestLiquidity    string
)

func main(cur realm) {
	println("[SCENARIO] Callback-time staking uses the final pool tick")
	println()
	println("[STEP 1] Create an incentivized pool at tick 0")
	setup(cur)
	println()
	println("[STEP 2] Swap to tick 100 through a callback realm")
	performCallbackStakeSwap(cur)
	println()
	println("[STEP 3] Verify final tick, liquidity, and reward eligibility")
	verifyFinalAccounting(cur)
	println("[RESULT] Callback-time staking remains aligned with final accounting")
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)
	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee())
	pl.SetPoolCreationFee(cross(cur), 0)
	pl.CreatePool(cross(cur), barPath, bazPath, fee, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross(cur), poolPath, 1)

	bar.Approve(cross(cur), poolAddr, maxApprove)
	baz.Approve(cross(cur), poolAddr, maxApprove)

	_, referenceLiquidity, _, _ = pn.Mint(cross(cur), barPath, bazPath, fee, 0, 10, "10000000", "10000000", "0", "0", deadline, adminAddr, "")
	pn.Mint(cross(cur), barPath, bazPath, fee, 0, 50, "10000000", "10000000", "0", "0", deadline, adminAddr, "")
	_, honestLiquidity, _, _ = pn.Mint(cross(cur), barPath, bazPath, fee, 50, 150, "10000000", "10000000", "0", "0", deadline, adminAddr, "")

	stake(cur, referencePositionID)
	stake(cur, honestPositionID)
	if got := sr.GetPoolStakedLiquidity(poolPath); got != referenceLiquidity {
		panic(ufmt.Sprintf("expected initial CurrentStakedLiquidity %s, got %s", referenceLiquidity, got))
	}
	println("[EXPECTED] Initial staked liquidity matches the [0, 10] reference position")
}

func performCallbackStakeSwap(cur realm) {
	testing.SetRealm(routerRealm)
	_, _ = pl.Swap(
		cross(cur),
		barPath,
		bazPath,
		fee,
		adminAddr,
		false,
		"100000000",
		gnsmath.TickMathGetSqrtRatioAtTick(100).ToString(),
		stakeAndSettleSwap,
	)
}

func stakeAndSettleSwap(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
	testing.SetRealm(adminRealm)

	currentTick, _ := pl.GetSlot0Tick(poolPath)
	if currentTick != 100 {
		return ufmt.Errorf("expected pool tick 100 before callback stake, got %d", currentTick)
	}
	if got := sr.GetPoolStakedLiquidity(poolPath); got != honestLiquidity {
		return ufmt.Errorf("expected CurrentStakedLiquidity %s at tick 100, got %s", honestLiquidity, got)
	}

	stake(cur, callbackPositionID)
	if got := sr.GetPoolStakedLiquidity(poolPath); got != honestLiquidity {
		return ufmt.Errorf("expected out-of-range callback position to stay excluded from CurrentStakedLiquidity %s, got %s", honestLiquidity, got)
	}
	println("[EXPECTED] Callback position remains excluded from CurrentStakedLiquidity at tick 100")

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(0, cur, barPath, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		common.SafeGRC20Transfer(0, cur, bazPath, poolAddr, amount1Delta)
	}
	return nil
}

func verifyFinalAccounting(cur realm) {
	testing.SetRealm(adminRealm)

	poolTick, _ := pl.GetSlot0Tick(poolPath)
	if poolTick != 100 {
		panic(ufmt.Sprintf("expected final pool tick 100, got %d", poolTick))
	}
	if historicalTick := latestHistoricalTick(poolPath); historicalTick != poolTick {
		panic(ufmt.Sprintf("expected final historical tick %d, got %d", poolTick, historicalTick))
	}
	if !sr.IsStaked(callbackPositionID) {
		panic("callback position must be staked")
	}
	if got := sr.GetPoolStakedLiquidity(poolPath); got != honestLiquidity {
		panic(ufmt.Sprintf("expected final CurrentStakedLiquidity %s, got %s", honestLiquidity, got))
	}
	println("[EXPECTED] Historical tick and CurrentStakedLiquidity match tick 100")

	testing.SkipHeights(10)
	if reward := sr.CollectableEmissionReward(callbackPositionID); reward != 0 {
		panic(ufmt.Sprintf("out-of-range callback position must have zero collectable reward, got %d", reward))
	}
	before := gns.BalanceOf(adminAddr)
	sr.CollectReward(cross(cur), callbackPositionID)
	if gns.BalanceOf(adminAddr) != before {
		panic("out-of-range callback position must not collect a reward")
	}
	println("[EXPECTED] Callback position remains ineligible for reward collection")
}

func latestHistoricalTick(poolPath string) int32 {
	historicalTicks := sr.GetPoolHistoricalTicks(poolPath)
	if historicalTicks == nil || historicalTicks.Size() == 0 {
		panic("expected a staker historical tick")
	}

	var latestTick int32
	historicalTicks.IterateByOffset(historicalTicks.Size()-1, 1, func(_ string, value any) bool {
		tick, ok := value.(int32)
		if !ok {
			panic(ufmt.Sprintf("expected historical tick int32, got %T", value))
		}
		latestTick = tick
		return false
	})
	return latestTick
}

func stake(cur realm, positionID uint64) {
	gnft.Approve(cross(cur), stakerAddr, grc721.TokenID(strconv.Itoa(int(positionID))))
	sr.StakeToken(cross(cur), positionID, "")
}

// Output:
// [SCENARIO] Callback-time staking uses the final pool tick
//
// [STEP 1] Create an incentivized pool at tick 0
// [EXPECTED] Initial staked liquidity matches the [0, 10] reference position
//
// [STEP 2] Swap to tick 100 through a callback realm
// [EXPECTED] Callback position remains excluded from CurrentStakedLiquidity at tick 100
//
// [STEP 3] Verify final tick, liquidity, and reward eligibility
// [EXPECTED] Historical tick and CurrentStakedLiquidity match tick 100
// [EXPECTED] Callback position remains ineligible for reward collection
// [RESULT] Callback-time staking remains aligned with final accounting
