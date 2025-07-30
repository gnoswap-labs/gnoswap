// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	rr "gno.land/r/gnoswap/v1/router"
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
	stakerRealm   = std.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	poolPath              string = "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100"
	MUST_EXISTS_IN_TIER_1        = "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint position 01 (narrow range)")
	mintBarQux100_1()
	println()

	println("[SCENARIO] 4. Mint position 02 (wide range)")
	mintBarQux100_2()
	println()

	println("[SCENARIO] 5. Stake both positions and check initial rewards")
	stakeToken_1_2()
	println()

	println("[SCENARIO] 6. Make position 01 out of range via swap")
	makePosition1OutRange()
	println()

	println("[SCENARIO] 7. Check rewards after position goes out of range")
	checkRewardAfter1Block()
	println()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	// override warm-up period for testing
	sr.SetWarmUpByAdmin(cross, 30, 150)
	sr.SetWarmUpByAdmin(cross, 50, 300)
	sr.SetWarmUpByAdmin(cross, 70, 900)
	sr.SetWarmUpByAdmin(cross, 100, maxInt64)

	// set unstaking fee to 0
	sr.SetUnStakingFeeByAdmin(cross, 0)

	testing.SetRealm(stakerRealm)
	testing.SkipHeights(1)
}

func createPool() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*3)

	pl.CreatePool(cross, barPath, quxPath, 100, "79228162514264337593543950337")
	sr.SetPoolTierByAdmin(cross, poolPath, 1)

	ufmt.Printf("[EXPECTED] pool created and set to tier 1\n")
	testing.SkipHeights(1)
}

func mintBarQux100_1() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	positionId, _, _, _ := pn.Mint(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-30),
		int32(30),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminUser,
		adminUser,
		"",
	)

	if positionId != 1 {
		panic("expected position id 1")
	}

	ufmt.Printf("[EXPECTED] position 01 minted with narrow range (-30 to 30): id=%d\n", positionId)
	testing.SkipHeights(1)
}

func mintBarQux100_2() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	positionId, _, _, _ := pn.Mint(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-1000),
		int32(1000),
		"50000",
		"50000",
		"1",
		"1",
		maxTimeout,
		adminUser,
		adminUser,
		"",
	)

	if positionId != 2 {
		panic("expected position id 2")
	}

	ufmt.Printf("[EXPECTED] position 02 minted with wide range (-1000 to 1000): id=%d\n", positionId)
	testing.SkipHeights(1)
}

func stakeToken_1_2() {
	testing.SetRealm(adminRealm)

	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")

	testing.SkipHeights(1)

	// clear reward
	sr.CollectReward(cross, 1, false)
	sr.CollectReward(cross, 2, false)

	ufmt.Printf("[EXPECTED] both positions staked and initial rewards cleared\n")
	testing.SkipHeights(1)

	/*
		total staked liquidity: 1058618
		> position 01: 33360 || 3.1512783648%
		> position 02: 1025258 || 96.8487216352%

		reward per block: 10702054
		> position 01: 10702054 * 3.1512783648% = 337251.512291213
		 > warmUp 30% => 337251.512291213 * 30% = 101175.4536873639
		> position 02: 10702054 * 96.8487216352% = 10364802.487708787
		 > warmUp 30% => 10364802.487708787 * 30% = 3109440.7463126361
	*/

	println("[INFO] collecting reward for position 01 while in-range")
	testing.SetRealm(adminRealm)

	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns
	ufmt.Printf("[EXPECTED] position 01 (in-range) reward: %d GNS\n", diff)
	// reward 101175
	// penalty 236076
	// total 337251

	println("[INFO] collecting reward for position 02 while in-range")
	testing.SetRealm(adminRealm)

	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 2, false)
	afterGns = gns.BalanceOf(adminUser)
	diff = afterGns - beforeGns
	ufmt.Printf("[EXPECTED] position 02 (in-range) reward: %d GNS\n", diff)
	// reward 3109440
	// penalty 7255362
	// total 10364802
}

func makePosition1OutRange() {
	poolTick := pl.GetSlot0Tick(poolPath)
	if poolTick != 0 {
		panic("expected pool tick to be 0")
	}

	// ROUTER SWAP
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	bar.Approve(cross, routerAddr, maxInt64)
	qux.Approve(cross, routerAddr, maxInt64)

	tokenIn, tokenOut := rr.ExactInSwapRoute(
		cross,
		barPath,
		quxPath,
		"10000",
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		"100",
		"0",
		maxTimeout,
		"", // referrer
	)

	if tokenIn != "10000" || tokenOut != "-9884" {
		panic("unexpected swap result")
	}

	ufmt.Printf("[EXPECTED] swap executed: %s BAR -> %s QUX\n", tokenIn, tokenOut)
	testing.SkipHeights(1)

	// position-01 became out-range
	// position-02 is only in-range position
}

func checkRewardAfter1Block() {
	println("[INFO] checking reward for position 01 (now out-range)")
	testing.SetRealm(adminRealm)

	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns
	if diff != 0 {
		panic("expected no reward for out of range position")
	}
	ufmt.Printf("[EXPECTED] position 01 (out-range) reward: %d GNS\n", diff)

	println("[INFO] checking reward for position 02 (still in-range)")
	testing.SetRealm(adminRealm)

	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 2, false)
	afterGns = gns.BalanceOf(adminUser)
	diff = afterGns - beforeGns
	ufmt.Printf("[EXPECTED] position 02 (in-range) reward: %d GNS\n", diff)
	// reward 3210615
	// penalty 7491438
	// total 10702053

	// since position-01 has become out-range, position-02 is the only in-range position
	// so position-02 will get entire block reward
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
// [EXPECTED] pool created and set to tier 1
//
// [SCENARIO] 3. Mint position 01 (narrow range)
// [EXPECTED] position 01 minted with narrow range (-30 to 30): id=1
//
// [SCENARIO] 4. Mint position 02 (wide range)
// [EXPECTED] position 02 minted with wide range (-1000 to 1000): id=2
//
// [SCENARIO] 5. Stake both positions and check initial rewards
// [EXPECTED] both positions staked and initial rewards cleared
// [INFO] collecting reward for position 01 while in-range
// [EXPECTED] position 01 (in-range) reward: 50587 GNS
// [INFO] collecting reward for position 02 while in-range
// [EXPECTED] position 02 (in-range) reward: 1554720 GNS
//
// [SCENARIO] 6. Make position 01 out of range via swap
// [EXPECTED] swap executed: 10000 BAR -> -9884 QUX
//
// [SCENARIO] 7. Check rewards after position goes out of range
// [INFO] checking reward for position 01 (now out-range)
// [EXPECTED] position 01 (out-range) reward: 0 GNS
// [INFO] checking reward for position 02 (still in-range)
// [EXPECTED] position 02 (in-range) reward: 1605307 GNS
