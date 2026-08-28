// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
	_ "gno.land/r/gnoswap/pool/v1"
	pn "gno.land/r/gnoswap/position"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/rbac"
	rt "gno.land/r/gnoswap/router"
	_ "gno.land/r/gnoswap/router/v1"
	"gno.land/r/gnoswap/scenarioutils"
	sr "gno.land/r/gnoswap/staker"
	_ "gno.land/r/gnoswap/staker/v1"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	halvingTickAdmin, _   = access.GetAddress(prbac.ROLE_ADMIN.String())
	halvingTickAdminRealm = testing.NewUserRealm(halvingTickAdmin)
	halvingTickStaker, _  = access.GetAddress(prbac.ROLE_STAKER.String())
	halvingTickPool, _    = access.GetAddress(prbac.ROLE_POOL.String())
	halvingTickRouter, _  = access.GetAddress(prbac.ROLE_ROUTER.String())
)

const (
	halvingTickPoolPath       = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:3000"
	halvingTickTimeout  int64 = 9999999999
	halvingTickMaxInt   int64 = 9223372036854775807
)

func main(cur realm) {
	println("[SCENARIO] halving tick-cross unclaimable")
	setupHalvingTickScenario(cur)
	mintHalvingTickPositions(cur)
	stakeOutOfRangePosition(cur)
	skipFirstHalving(cur)
	crossIntoRangeBySwap(cur)
	collectAfterCross(cur)
}

func setupHalvingTickScenario(cur realm) {
	testing.SetRealm(halvingTickAdminRealm)
	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	emission.ChangeDistributionPct(cross(cur), 7500, 2500, 0, 0)
	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)
	testing.SkipHeights(1)
	emission.MintAndDistributeGns(cross(cur))
	pl.CreatePool(cross(cur), "gno.land/r/onbloc/bar.BAR", "gno.land/r/onbloc/baz.BAZ", 3000, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross(cur), halvingTickPoolPath, 1)
}

func mintHalvingTickPositions(cur realm) {
	testing.SetRealm(halvingTickAdminRealm)
	bar.Approve(cross(cur), halvingTickPool, halvingTickMaxInt)
	baz.Approve(cross(cur), halvingTickPool, halvingTickMaxInt)
	// Position 1 supplies swap liquidity but is not staked.
	pn.Mint(cross(cur), "gno.land/r/onbloc/bar.BAR", "gno.land/r/onbloc/baz.BAZ", 3000, -1020, 1020, "1000000", "1000000", "1", "1", halvingTickTimeout, halvingTickAdmin, "")
	// Position 2 is out of range at tick 0, therefore its stake leaves staker liquidity at zero.
	pn.Mint(cross(cur), "gno.land/r/onbloc/bar.BAR", "gno.land/r/onbloc/baz.BAZ", 3000, 60, 120, "1000000", "0", "0", "0", halvingTickTimeout, halvingTickAdmin, "")
}

func stakeOutOfRangePosition(cur realm) {
	testing.SetRealm(halvingTickAdminRealm)
	gnft.Approve(cross(cur), halvingTickStaker, grc721.TokenID(strconv.Itoa(2)))
	sr.StakeToken(cross(cur), 2, "")
	if tick, _ := pl.GetSlot0Tick(halvingTickPoolPath); tick >= 60 {
		panic("position must start out of range")
	}
}

func skipFirstHalving(cur realm) {
	testing.SetRealm(halvingTickAdminRealm)
	boundary := gns.GetHalvingYearStartTimestamp(3)
	blocks := (boundary-time.Now().Unix())/5 + 2
	testing.SkipHeights(blocks)
	if gns.GetCurrentYear() != 3 {
		panic("expected first halving")
	}
	println("[EXPECTED] first halving crossed")
}

func crossIntoRangeBySwap(cur realm) {
	testing.SetRealm(halvingTickAdminRealm)
	bar.Approve(cross(cur), halvingTickRouter, halvingTickMaxInt)
	baz.Approve(cross(cur), halvingTickRouter, halvingTickMaxInt)
	rt.ExactInSwapRoute(cross(cur), "gno.land/r/onbloc/baz.BAZ", "gno.land/r/onbloc/bar.BAR", "100000", "gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/bar.BAR:3000", "100", "0", halvingTickTimeout, "")
	if tick, _ := pl.GetSlot0Tick(halvingTickPoolPath); tick < 60 {
		panic("swap did not cross into staked range")
	} else {
		println("[EXPECTED] swap crossed into staked range")
	}
}

func collectAfterCross(cur realm) {
	testing.SetRealm(halvingTickAdminRealm)
	testing.SkipHeights(1)
	beforeUser := gns.BalanceOf(halvingTickAdmin)
	beforeCommunity, _ := access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())
	communityBefore := gns.BalanceOf(beforeCommunity)
	sr.CollectReward(cross(cur), 2)
	if gns.BalanceOf(halvingTickAdmin) <= beforeUser {
		panic("in-range staker must receive a reward")
	}
	if gns.BalanceOf(beforeCommunity) <= communityBefore {
		panic("zero-liquidity interval must be sent to community pool")
	}
	println("[EXPECTED] reward and unclaimable distribution completed")
}

// Output:
// [SCENARIO] halving tick-cross unclaimable
// [EXPECTED] first halving crossed
// [EXPECTED] swap crossed into staked range
// [EXPECTED] reward and unclaimable distribution completed
