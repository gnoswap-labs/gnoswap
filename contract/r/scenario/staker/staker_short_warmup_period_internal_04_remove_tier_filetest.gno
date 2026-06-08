// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	en "gno.land/r/gnoswap/emission"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	quxPath = "gno.land/r/onbloc/qux"

	fee100  uint32 = 100
	fee3000 uint32 = 3000

	maxTimeout            int64 = 9999999999
	maxInt64              int64 = 9223372036854775807
	MUST_EXISTS_IN_TIER_1       = "gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000"
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup(cur)
	println()

	println("[SCENARIO] 2. Mint and distribute GNS")
	doubleMint(cur)
	println()

	println("[SCENARIO] 3. Create pools")
	poolInitCreatePool(cur)
	println()

	println("[SCENARIO] 4. Mint position 01 on bar:qux:100")
	mintBarQux100_1(cur)
	println()

	println("[SCENARIO] 5. Mint position 02 on bar:baz:3000")
	mintBarBaz100_2(cur)
	println()

	println("[SCENARIO] 6. Stake position 01")
	stakeToken_1(cur)
	println()

	println("[SCENARIO] 7. Set bar:baz:3000 pool to tier 2")
	setPoolTier(cur)
	println()

	println("[SCENARIO] 8. Stake position 02")
	stakeToken_2(cur)
	println()

	println("[SCENARIO] 9. Remove pool tier and verify reward changes")
	removePoolTier(cur)
	println()
}

func initAndSetup(cur realm) {
	testing.SetRealm(adminRealm)
	en.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)

	// override warm-up period for testing
	sr.SetWarmUp(cross(cur), 30, 150)
	sr.SetWarmUp(cross(cur), 50, 300)
	sr.SetWarmUp(cross(cur), 70, 900)
	sr.SetWarmUp(cross(cur), 100, maxInt64)

	// set unstaking fee to 0
	sr.SetUnStakingFee(cross(cur), 0)

	// set pool creation fee to 0
	pl.SetPoolCreationFee(cross(cur), 0)

	// set community pool distribution to 0% (give it to devOps)
	en.ChangeDistributionPct(
		cross(cur),
		7500, // liquidityStakerPct
		2500, // devOpsPct
		0, // communityPoolPct
		0, // govStakerPct
	)

	testing.SetRealm(stakerRealm)
	testing.SkipHeights(1)
}

func doubleMint(cur realm) {
	testing.SetRealm(adminRealm)
	en.MintAndDistributeGns(cross(cur))
	en.MintAndDistributeGns(cross(cur))

	ufmt.Printf("[EXPECTED] GNS minted and distributed\n")
	testing.SkipHeights(1)
}

func poolInitCreatePool(cur realm) {
	testing.SetRealm(adminRealm)

	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee()*3)

	pl.CreatePool(cross(cur), barPath, quxPath, 100, "79228162514264337593543950337")
	sr.SetPoolTier(cross(cur), "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", 1)

	pl.CreatePool(cross(cur), barPath, bazPath, 3000, "79228162514264337593543950337")

	ufmt.Printf("[EXPECTED] pools created: bar:qux:100 (tier 1), bar:baz:3000 (no tier)\n")
	testing.SkipHeights(1)
}

func mintBarQux100_1(cur realm) {
	testing.SetRealm(adminRealm)

	bar.Approve(cross(cur), poolAddr, maxInt64)
	qux.Approve(cross(cur), poolAddr, maxInt64)

	positionId, _, _, _ := pn.Mint(
		cross(cur),
		barPath,
		quxPath,
		fee100,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminUser,
		"",
	)

	if positionId != 1 {
		panic("expected position id 1")
	}

	owner, err := gnft.OwnerOf(positionIdFrom(cur, positionId))
	if err != nil || owner != adminUser {
		panic("unexpected owner")
	}

	ufmt.Printf("[EXPECTED] position 01 minted on bar:qux:100: id=%d\n", positionId)
	testing.SkipHeights(1)
}

func mintBarBaz100_2(cur realm) {
	testing.SetRealm(adminRealm)

	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)

	positionId, _, _, _ := pn.Mint(
		cross(cur),
		barPath,
		bazPath,
		fee3000,
		int32(-1020),
		int32(1020),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminUser,
		"",
	)

	if positionId != 2 {
		panic("expected position id 2")
	}

	owner, err := gnft.OwnerOf(positionIdFrom(cur, positionId))
	if err != nil || owner != adminUser {
		panic("unexpected owner")
	}

	ufmt.Printf("[EXPECTED] position 02 minted on bar:baz:3000: id=%d\n", positionId)
	testing.SkipHeights(1)
}

func stakeToken_1(cur realm) {
	testing.SetRealm(adminRealm)

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, 1))
	sr.StakeToken(cross(cur), 1, "")

	ufmt.Printf("[EXPECTED] position 01 staked\n")
	testing.SkipHeights(1)
}

func setPoolTier(cur realm) {
	testing.SkipHeights(100) // this reward should go to bar:qux:100

	testing.SetRealm(adminRealm)
	sr.SetPoolTier(cross(cur), "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000", 2)

	ufmt.Printf("[EXPECTED] bar:baz:3000 pool set to tier 2\n")
	testing.SkipHeights(1)
}

func stakeToken_2(cur realm) {
	testing.SetRealm(adminRealm)

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, 2))
	sr.StakeToken(cross(cur), 2, "")

	// clear reward
	sr.CollectReward(cross(cur), 1)
	sr.CollectReward(cross(cur), 2)

	ufmt.Printf("[EXPECTED] position 02 staked and rewards cleared\n")
	testing.SkipHeights(1)
}

func removePoolTier(cur realm) {
	println("[INFO] checking reward for position 01 before removing tier")
	testing.SetRealm(adminRealm)

	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), 1) // position 01 is in tier1 pool
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns
	ufmt.Printf("[EXPECTED] position 01 reward before tier removal: %d GNS\n", diff)

	println("[INFO] removing pool tier 2")
	testing.SetRealm(adminRealm)
	sr.RemovePoolTier(cross(cur), "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000")
	testing.SkipHeights(1)
	// tier2 pool has been removed, only 1 pool exist in tier 1

	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), 1) // position 01 is in tier1 pool
	afterGns = gns.BalanceOf(adminUser)
	diff = afterGns - beforeGns
	ufmt.Printf("[EXPECTED] position 01 reward after tier removal: %d GNS\n", diff)
}

func positionIdFrom(cur realm, positionId any) grc721.TokenID {
	switch positionId := positionId.(type) {
	case string:
		return grc721.TokenID(positionId)
	case int:
		return grc721.TokenID(strconv.Itoa(positionId))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId)))
	case grc721.TokenID:
		return positionId
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize and setup
//
// [SCENARIO] 2. Mint and distribute GNS
// [EXPECTED] GNS minted and distributed
//
// [SCENARIO] 3. Create pools
// [EXPECTED] pools created: bar:qux:100 (tier 1), bar:baz:3000 (no tier)
//
// [SCENARIO] 4. Mint position 01 on bar:qux:100
// [EXPECTED] position 01 minted on bar:qux:100: id=1
//
// [SCENARIO] 5. Mint position 02 on bar:baz:3000
// [EXPECTED] position 02 minted on bar:baz:3000: id=2
//
// [SCENARIO] 6. Stake position 01
// [EXPECTED] position 01 staked
//
// [SCENARIO] 7. Set bar:baz:3000 pool to tier 2
// [EXPECTED] bar:baz:3000 pool set to tier 2
//
// [SCENARIO] 8. Stake position 02
// [EXPECTED] position 02 staked and rewards cleared
//
// [SCENARIO] 9. Remove pool tier and verify reward changes
// [INFO] checking reward for position 01 before removing tier
// [EXPECTED] position 01 reward before tier removal: 6555005 GNS
// [INFO] removing pool tier 2
// [EXPECTED] position 01 reward after tier removal: 9364294 GNS
