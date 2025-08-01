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
	bazPath = "gno.land/r/onbloc/baz"
	quxPath = "gno.land/r/onbloc/qux"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	max_timeout      int64 = 9999999999
	maxInt64         int64 = 9223372036854775807
	depositGnsAmount int64 = 100000000000

	TIMESTAMP_90DAYS = int64(7776000)
	poolPath         = "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint position 01 bar:qux:100")
	mintBarQux100_1()
	println()

	println("[SCENARIO] 4. Mint position 02 bar:qux:100")
	mintBarQux100_2()
	println()

	println("[SCENARIO] 5. Create external incentive with BAR")
	createExternalIncentiveBar()
	println()

	println("[SCENARIO] 6. Stake positions 01 and 02")
	stakeToken_1_AND_2()
	println()

	println("[SCENARIO] 7. Check rewards before incentive is active")
	beforeActive()
	println()

	println("[SCENARIO] 8. Check rewards after 50 blocks")
	after50Blocks()
	println()

	println("[SCENARIO] 9. Make position 01 out of range via swap")
	makePosition1OutRange()
	println()

	println("[SCENARIO] 10. Check rewards after position goes out of range")
	rewardNowAfter1Block()
	println()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	// override warm-up period for testing
	sr.SetWarmUp(cross, 30, 150)
	sr.SetWarmUp(cross, 50, 300)
	sr.SetWarmUp(cross, 70, 900)
	sr.SetWarmUp(cross, 100, maxInt64)

	// set unstaking fee to 0
	sr.SetUnStakingFee(cross, 0)

	testing.SetRealm(stakerRealm)
	testing.SkipHeights(1)
}

func createPool() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*3)

	pl.CreatePool(cross, barPath, quxPath, 100, "79228162514264337593543950337")
	pl.CreatePool(cross, barPath, bazPath, 3000, "79228162514264337593543950337")

	ufmt.Printf("[EXPECTED] pools created successfully\n")
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
		int32(-50),
		int32(50),
		"50",
		"50",
		"1",
		"1",
		max_timeout,
		adminUser,
		adminUser,
		"",
	)

	owner, err := gnft.OwnerOf(positionIdFrom(positionId))
	if err != nil || owner != adminUser {
		panic("unexpected owner")
	}

	ufmt.Printf("[EXPECTED] position 01 minted: id=%d\n", positionId)
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
		"500000",
		"500000",
		"1",
		"1",
		max_timeout,
		adminUser,
		adminUser,
		"",
	)

	owner, err := gnft.OwnerOf(positionIdFrom(positionId))
	if err != nil || owner != adminUser {
		panic("unexpected owner")
	}

	ufmt.Printf("[EXPECTED] position 02 minted: id=%d\n", positionId)
	testing.SkipHeights(1)
}

func createExternalIncentiveBar() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	sr.CreateExternalIncentive(
		cross,
		poolPath,
		barPath,
		9_000_000_000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentive BAR created successfully\n")
	testing.SkipHeights(1)
}

func stakeToken_1_AND_2() {
	testing.SetRealm(adminRealm)

	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")

	ufmt.Printf("[EXPECTED] positions 01 and 02 staked successfully\n")
	testing.SkipHeights(1)
}

func beforeActive() {
	testing.SetRealm(adminRealm)

	oldBar := bar.BalanceOf(adminUser)

	sr.CollectReward(cross, 1, false)
	sr.CollectReward(cross, 2, false)

	newBar := bar.BalanceOf(adminUser)

	if newBar-oldBar != 0 {
		panic("expected no reward before incentive is active")
	}
	ufmt.Printf("[EXPECTED] no rewards before incentive is active: %d BAR\n", newBar-oldBar)
}

func after50Blocks() {
	println("[INFO] making external incentive active")
	testing.SkipHeights(850)

	println("[INFO] checking rewards after 50 blocks")
	testing.SetRealm(adminRealm)
	testing.SkipHeights(50)

	// block per reward is 2314
	// skip 50 block after active
	// 2314 * 50 = 115700

	// total inrange staked liquidity: 10272609
	// position-01 (inRange) liquditiy: 20026 => 0.1949456073%
	// > 115700 * 0.1949456073% = 225.5520676461

	// position-02 (inRange) liquditiy: 10252583 => 99.8050543927%
	// > 115700 * 99.8050543927% = 115474.4479323539

	// both of position is in warm up 70%

	oldBar := bar.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	newBar := bar.BalanceOf(adminUser)
	diff1 := newBar - oldBar
	ufmt.Printf("[EXPECTED] position 01 reward: %d BAR\n", diff1)

	sr.CollectReward(cross, 2, false)
	newBar2 := bar.BalanceOf(adminUser)
	diff2 := newBar2 - newBar
	ufmt.Printf("[EXPECTED] position 02 reward: %d BAR\n", diff2)
}

func makePosition1OutRange() {
	poolTick := pl.PoolGetSlot0Tick(poolPath)
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
		"100000",
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		"100",
		"0",
		max_timeout,
		"",
	)

	if tokenIn != "100000" || tokenOut != "-98873" {
		panic("unexpected swap result")
	}

	poolTick = pl.PoolGetSlot0Tick(poolPath)
	if poolTick != -195 {
		panic("expected pool tick to be -195")
	}

	ufmt.Printf("[EXPECTED] position 01 made out of range by swap, current tick: %d\n", poolTick)
}

func rewardNowAfter1Block() {
	testing.SetRealm(adminRealm)
	sr.CollectReward(cross, 1, false)
	sr.CollectReward(cross, 2, false)

	testing.SkipHeights(1)

	oldBar := bar.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	newBar := bar.BalanceOf(adminUser)
	diff1 := newBar - oldBar

	if diff1 != 0 {
		panic("expected no reward for out of range position")
	}
	ufmt.Printf("[EXPECTED] position 01 (out of range) reward: %d BAR\n", diff1)

	sr.CollectReward(cross, 2, false)
	newBar2 := bar.BalanceOf(adminUser)
	diff2 := newBar2 - newBar
	ufmt.Printf("[EXPECTED] position 02 (in range) reward: %d BAR\n", diff2)
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
// [EXPECTED] pools created successfully
//
// [SCENARIO] 3. Mint position 01 bar:qux:100
// [EXPECTED] position 01 minted: id=1
//
// [SCENARIO] 4. Mint position 02 bar:qux:100
// [EXPECTED] position 02 minted: id=2
//
// [SCENARIO] 5. Create external incentive with BAR
// [EXPECTED] external incentive BAR created successfully
//
// [SCENARIO] 6. Stake positions 01 and 02
// [EXPECTED] positions 01 and 02 staked successfully
//
// [SCENARIO] 7. Check rewards before incentive is active
// [EXPECTED] no rewards before incentive is active: 0 BAR
//
// [SCENARIO] 8. Check rewards after 50 blocks
// [INFO] making external incentive active
// [INFO] checking rewards after 50 blocks
// [EXPECTED] position 01 reward: 179 BAR
// [EXPECTED] position 02 reward: 92148 BAR
//
// [SCENARIO] 9. Make position 01 out of range via swap
// [EXPECTED] position 01 made out of range by swap, current tick: -195
//
// [SCENARIO] 10. Check rewards after position goes out of range
// [EXPECTED] position 01 (out of range) reward: 0 BAR
// [EXPECTED] position 02 (in range) reward: 1619 BAR
