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
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/rbac"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	_ "gno.land/r/onbloc/foo"
	_ "gno.land/r/onbloc/qux"
)

const (
	targetPoolPath    = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:3000"
	unrelatedPoolPath = "gno.land/r/onbloc/foo.FOO:gno.land/r/onbloc/qux.QUX:3000"
	maxTimeout  int64 = 9999999999
	maxInt64    int64 = 9223372036854775807
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())
)

func main(cur realm) {
	println("[SCENARIO] initialize and tier two internal pools")
	setupPools(cur)
	println("[EXPECTED] both pools are tiered for internal rewards")
	println()

	println("[SCENARIO] stake a position in pool A")
	stakeTargetPoolPosition(cur)
	println("[EXPECTED] position staked successfully")
	println("[EXPECTED] only pool A reward-cache count increased")
}

func setupPools(cur realm) {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	emission.ChangeDistributionPct(cross(cur), 7500, 2500, 0, 0)
	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	initialPrice := gnsmath.TickMathGetSqrtRatioAtTick(0).ToString()
	pl.CreatePool(cross(cur), "gno.land/r/onbloc/bar.BAR", "gno.land/r/onbloc/baz.BAZ", 3000, initialPrice)
	pl.CreatePool(cross(cur), "gno.land/r/onbloc/foo.FOO", "gno.land/r/onbloc/qux.QUX", 3000, initialPrice)
	sr.SetPoolTier(cross(cur), targetPoolPath, 1)
	sr.SetPoolTier(cross(cur), unrelatedPoolPath, 2)
}

func stakeTargetPoolPosition(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)

	poolACacheCountBefore := sr.GetPoolRewardCacheCount(targetPoolPath)
	poolBCacheCountBefore := sr.GetPoolRewardCacheCount(unrelatedPoolPath)
	positionID, _, _, _ := pn.Mint(
		cross(cur),
		"gno.land/r/onbloc/bar.BAR",
		"gno.land/r/onbloc/baz.BAZ",
		3000,
		int32(-1020),
		int32(1020),
		"1000000",
		"1000000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)

	gnft.Approve(cross(cur), stakerAddr, grc721.TokenID(strconv.Itoa(int(positionID))))
	testing.SkipHeights(1)
	sr.StakeToken(cross(cur), positionID, "")

	if owner := gnft.MustOwnerOf(grc721.TokenID(strconv.Itoa(int(positionID)))); owner != stakerAddr {
		panic("position was not staked")
	}
	if got := sr.GetPoolRewardCacheCount(targetPoolPath); got != poolACacheCountBefore+1 {
		panic("pool A reward-cache count did not increase")
	}
	if got := sr.GetPoolRewardCacheCount(unrelatedPoolPath); got != poolBCacheCountBefore {
		panic("pool B reward-cache count changed")
	}
}

// Output:
// [SCENARIO] initialize and tier two internal pools
// [EXPECTED] both pools are tiered for internal rewards
//
// [SCENARIO] stake a position in pool A
// [EXPECTED] position staked successfully
// [EXPECTED] only pool A reward-cache count increased
