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

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(access.ROLE_STAKER)
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"

	fee100 uint32 = 100

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

	println("[SCENARIO] 3. Create pool")
	createPool()
	println()

	println("[SCENARIO] 4. Mint position 01 with large liquidity")
	mintBarQux100_1()
	println()

	println("[SCENARIO] 5. Mint position 02 with small liquidity")
	mintBarQux100_2()
	println()

	println("[SCENARIO] 6. Stake both positions")
	stakeToken_1_2()
	println()

	println("[SCENARIO] 7. Collect rewards and verify distribution")
	collectRewardBoth()
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
	en.RegisterGnsChangeCallback(cross)
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

	ufmt.Printf("[EXPECTED] pool created and set to tier 1\n")
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
		"500000000",
		"500000000",
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

	ufmt.Printf("[EXPECTED] position 01 minted with large liquidity: id=%d\n", positionId)
	testing.SkipHeights(1)
}

func mintBarQux100_2() {
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
		"500",
		"500",
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

	ufmt.Printf("[EXPECTED] position 02 minted with small liquidity: id=%d\n", positionId)
	testing.SkipHeights(1)
}

func stakeToken_1_2() {
	testing.SetRealm(adminRealm)

	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")

	ufmt.Printf("[EXPECTED] both positions staked successfully\n")
	testing.SkipHeights(1)
}

func collectRewardBoth() {
	// reward per block 10702054

	// total staked liquidity = 10252593386
	// > position-01: 10252583134 // ratio 99.9999000058%
	//  > 10702054 * 99.9999000058% = 10702043.2985667191
	//  > warm up = 10702043.2985667191 * 30% = 3210612.9895700157

	// > position-02: 10252 // ratio 0.0000999942%
	//  > 10702054 * 0.0000999942% = 10.7014332809
	//  > warm up = 10.7014332809 * 30% = 3.2104299843

	println("[INFO] collecting reward for position 01 (large liquidity)")
	testing.SetRealm(adminRealm)

	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	newGns := gns.BalanceOf(adminUser)
	diff := newGns - beforeGns
	ufmt.Printf("[EXPECTED] position 01 reward: %d GNS\n", diff)
	// reward 3210612
	// penalty 7491431
	// total 10702043

	println("[INFO] collecting reward for position 02 (small liquidity)")
	testing.SetRealm(adminRealm)

	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 2, false)
	newGns = gns.BalanceOf(adminUser)
	diff = newGns - beforeGns
	ufmt.Printf("[EXPECTED] position 02 reward: %d GNS\n", diff)
	// reward 3
	// penalty 7
	// total 10
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
// [SCENARIO] 3. Create pool
// [EXPECTED] pool created and set to tier 1
//
// [SCENARIO] 4. Mint position 01 with large liquidity
// [EXPECTED] position 01 minted with large liquidity: id=1
//
// [SCENARIO] 5. Mint position 02 with small liquidity
// [EXPECTED] position 02 minted with small liquidity: id=2
//
// [SCENARIO] 6. Stake both positions
// [EXPECTED] both positions staked successfully
//
// [SCENARIO] 7. Collect rewards and verify distribution
// [INFO] collecting reward for position 01 (large liquidity)
// [EXPECTED] position 01 reward: 1605306 GNS
// [INFO] collecting reward for position 02 (small liquidity)
// [EXPECTED] position 02 reward: 1 GNS
