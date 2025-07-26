// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"std"
	"strconv"

	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	en "gno.land/r/gnoswap/v1/emission"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	quxPath = "gno.land/r/onbloc/qux"

	fee100  uint32 = 100
	fee3000 uint32 = 3000

	max_timeout           int64 = 9999999999
	MUST_EXISTS_IN_TIER_1       = "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Mint and distribute GNS")
	doubleMint()
	println()

	println("[SCENARIO] 3. Create pools")
	createPool()
	println()

	println("[SCENARIO] 4. Mint position 01 on bar:qux:100")
	mintBarQux100_1()
	println()

	println("[SCENARIO] 5. Mint position 02 on bar:baz:3000")
	mintBarBaz100_2()
	println()

	println("[SCENARIO] 6. Skip 100 heights")
	skip100Height()
	println()

	println("[SCENARIO] 7. Stake position 01")
	stakeToken_1()
	println()

	println("[SCENARIO] 8. Set bar:baz:3000 pool to tier 2")
	setPoolTier()
	println()

	println("[SCENARIO] 9. Stake position 02 and check tier 2 reward")
	stakeToken_2()
	println()

	println("[SCENARIO] 10. Change pool tier to 1 and check reward")
	changePoolTier()
	println()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	// override warm-up period for testing
	sr.SetWarmUpByAdmin(cross, 30, 150)
	sr.SetWarmUpByAdmin(cross, 50, 300)
	sr.SetWarmUpByAdmin(cross, 70, 900)
	sr.SetWarmUpByAdmin(cross, 100, consts.INT64_MAX)

	// set unstaking fee to 0
	sr.SetUnStakingFeeByAdmin(cross, 0)

	// set pool creation fee to 0
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	// set community pool distribution to 0% (give it to devOps)
	en.ChangeDistributionPctByAdmin(
		cross,
		1, 7500,
		2, 2500,
		3, 0,
		4, 0,
	)

	testing.SetRealm(stakerRealm)
	testing.SkipHeights(1)
}

func doubleMint() {
	testing.SetRealm(adminRealm)
	en.MintAndDistributeGns(cross)
	en.MintAndDistributeGns(cross)

	ufmt.Printf("[EXPECTED] GNS minted and distributed\n")
	testing.SkipHeights(1)
}

func createPool() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*3)

	pl.CreatePool(cross, barPath, quxPath, 100, "79228162514264337593543950337")
	sr.SetPoolTierByAdmin(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", 1)

	pl.CreatePool(cross, barPath, bazPath, 3000, "79228162514264337593543950337")

	ufmt.Printf("[EXPECTED] pools created: bar:qux:100 (tier 1), bar:baz:3000 (no tier)\n")
	testing.SkipHeights(1)
}

func mintBarQux100_1() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	qux.Approve(cross, poolAddr, consts.INT64_MAX)

	positionId, _, _, _ := pn.Mint(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		max_timeout,
		adminUser,
		adminUser,
		"",
	)

	if positionId != 1 {
		panic("expected position id 1")
	}

	owner, err := gnft.OwnerOf(positionIdFrom(positionId))
	if err != nil || owner != adminUser {
		panic("unexpected owner")
	}

	ufmt.Printf("[EXPECTED] position 01 minted on bar:qux:100: id=%d\n", positionId)
	testing.SkipHeights(1)
}

func mintBarBaz100_2() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)

	positionId, _, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee3000,
		int32(-1020),
		int32(1020),
		"50",
		"50",
		"1",
		"1",
		max_timeout,
		adminUser,
		adminUser,
		"",
	)

	if positionId != 2 {
		panic("expected position id 2")
	}

	owner, err := gnft.OwnerOf(positionIdFrom(positionId))
	if err != nil || owner != adminUser {
		panic("unexpected owner")
	}

	ufmt.Printf("[EXPECTED] position 02 minted on bar:baz:3000: id=%d\n", positionId)
	testing.SkipHeights(1)
}

func skip100Height() {
	testing.SkipHeights(100)
	ufmt.Printf("[EXPECTED] skipped 100 heights\n")
	testing.SkipHeights(1)
}

func stakeToken_1() {
	testing.SetRealm(adminRealm)

	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	ufmt.Printf("[EXPECTED] position 01 staked\n")
	testing.SkipHeights(1)
}

func setPoolTier() {
	testing.SkipHeights(100) // this reward should go to bar:qux:100

	testing.SetRealm(adminRealm)

	sr.SetPoolTierByAdmin(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000", 2)
	ufmt.Printf("[EXPECTED] bar:baz:3000 pool set to tier 2\n")
	testing.SkipHeights(1)
}

func stakeToken_2() {
	testing.SetRealm(adminRealm)

	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")

	ufmt.Printf("[EXPECTED] position 02 staked\n")
	testing.SkipHeights(1)

	println("[INFO] collecting reward when position 02 is in tier 2")
	testing.SetRealm(adminRealm)

	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 2, false)
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns
	ufmt.Printf("[EXPECTED] position 02 tier 2 reward: %d GNS\n", diff)

	testing.SkipHeights(1)
}

func changePoolTier() {
	testing.SetRealm(adminRealm)

	sr.ChangePoolTierByAdmin(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000", 1)
	sr.CollectReward(cross, 2, false)
	ufmt.Printf("[EXPECTED] pool tier changed to 1\n")

	println("[INFO] checking reward when position 02 is in tier 1")
	testing.SkipHeights(1)
	testing.SetRealm(adminRealm)

	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 2, false)
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns
	ufmt.Printf("[EXPECTED] position 02 tier 1 reward: %d GNS\n", diff)
}

func positionIdFrom(positionId any) grc721.TokenID {
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
// [SCENARIO] 6. Skip 100 heights
// [EXPECTED] skipped 100 heights
//
// [SCENARIO] 7. Stake position 01
// [EXPECTED] position 01 staked
//
// [SCENARIO] 8. Set bar:baz:3000 pool to tier 2
// [EXPECTED] bar:baz:3000 pool set to tier 2
//
// [SCENARIO] 9. Stake position 02 and check tier 2 reward
// [EXPECTED] position 02 staked
// [INFO] collecting reward when position 02 is in tier 2
// [EXPECTED] position 02 tier 2 reward: 963184 GNS
//
// [SCENARIO] 10. Change pool tier to 1 and check reward
// [EXPECTED] pool tier changed to 1
// [INFO] checking reward when position 02 is in tier 1
// [EXPECTED] position 02 tier 1 reward: 1070205 GNS
