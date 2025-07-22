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
	"gno.land/r/gnoswap/v1/emission"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
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
	depositGnsAmount      int64 = 100000000000
	TIMESTAMP_90DAYS            = int64(7776000)
	MUST_EXISTS_IN_TIER_1       = "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint position 01 on bar:qux:100")
	mintBarQux100_1()
	println()

	println("[SCENARIO] 4. Create external incentive with BAR")
	createExternalIncentiveBar()
	println()

	println("[SCENARIO] 5. Create external incentive with GNS")
	createExternalIncentiveGns()
	println()

	println("[SCENARIO] 6. Stake position 01")
	stakeToken_1()
	println()

	println("[SCENARIO] 7. Wait for incentives to become active")
	afterActive()
	println()

	println("[SCENARIO] 8. Collect reward for single block")
	collectRewardSingleBlock()
	println()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	// override warm-up period for testing
	sr.SetWarmUp(cross, 30, 150)
	sr.SetWarmUp(cross, 50, 300)
	sr.SetWarmUp(cross, 70, 900)
	sr.SetWarmUp(cross, 100, consts.INT64_MAX)

	// set unstaking fee to 0
	sr.SetUnStakingFeeByAdmin(cross, 0)

	testing.SetRealm(stakerRealm)
	emission.RegisterGnsChangeCallback(cross)
	testing.SkipHeights(1)
}

func createPool() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*3)

	pl.CreatePool(cross, barPath, quxPath, 100, "79228162514264337593543950337")
	sr.SetPoolTierByAdmin(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", 1)

	pl.CreatePool(cross, barPath, bazPath, 3000, "79228162514264337593543950337")

	ufmt.Printf("[EXPECTED] pools created and bar:qux:100 set to tier 1\n")
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

	ufmt.Printf("[EXPECTED] position 01 minted: id=%d\n", positionId)
	testing.SkipHeights(1)
}

func createExternalIncentiveBar() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, stakerAddr, consts.INT64_MAX)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		barPath,
		2_000_000_000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentive BAR created\n")
	testing.SkipHeights(1)
}

func createExternalIncentiveGns() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, stakerAddr, consts.INT64_MAX)

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		consts.GNS_PATH,
		5_000_000_000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentive GNS created\n")
	testing.SkipHeights(1)
}

func stakeToken_1() {
	testing.SetRealm(adminRealm)

	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	ufmt.Printf("[EXPECTED] position 01 staked\n")
	testing.SkipHeights(1)
}

func afterActive() {
	testing.SkipHeights(978 - std.ChainHeight() - 1) // in active
	testing.SkipHeights(1)                           // active // but no block passed since active
	testing.SkipHeights(50)                          // skip 50 more block

	testing.SkipHeights(1)

	// clear reward
	testing.SetRealm(adminRealm)
	sr.CollectReward(cross, 1, false)
	ufmt.Printf("[EXPECTED] incentives are now active, initial rewards cleared\n")
}

func collectRewardSingleBlock() {
	testing.SetRealm(adminRealm)

	oldBar := bar.BalanceOf(adminUser)
	oldGns := gns.BalanceOf(adminUser)

	testing.SkipHeights(1)
	sr.CollectReward(cross, 1, false)
	// 1 block passed
	// position warmup is 70%

	newBar := bar.BalanceOf(adminUser)
	newGns := gns.BalanceOf(adminUser)

	barReward := newBar - oldBar
	ufmt.Printf("[EXPECTED] BAR reward: %d\n", barReward)

	gnsReward := newGns - oldGns
	ufmt.Printf("[EXPECTED] GNS reward (internal + external): %d\n", gnsReward)
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
// [SCENARIO] 2. Create pool
// [EXPECTED] pools created and bar:qux:100 set to tier 1
//
// [SCENARIO] 3. Mint position 01 on bar:qux:100
// [EXPECTED] position 01 minted: id=1
//
// [SCENARIO] 4. Create external incentive with BAR
// [EXPECTED] external incentive BAR created
//
// [SCENARIO] 5. Create external incentive with GNS
// [EXPECTED] external incentive GNS created
//
// [SCENARIO] 6. Stake position 01
// [EXPECTED] position 01 staked
//
// [SCENARIO] 7. Wait for incentives to become active
// [EXPECTED] incentives are now active, initial rewards cleared
//
// [SCENARIO] 8. Collect reward for single block
// [EXPECTED] BAR reward: 359
// [EXPECTED] GNS reward (internal + external): 3746617
