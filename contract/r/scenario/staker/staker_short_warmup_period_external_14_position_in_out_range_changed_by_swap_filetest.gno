// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"strconv"
	"testing"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	rr "gno.land/r/gnoswap/router"
	sr "gno.land/r/gnoswap/staker"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/sol"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
	solPath = "gno.land/r/gnoswap/test_token/sol"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	max_timeout      int64 = 9999999999
	maxInt64         int64 = 9223372036854775807
	depositGnsAmount int64 = 100000000000

	TIMESTAMP_90DAYS = int64(7776000)
	poolPath         = "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint position 01 atom:sol:100")
	mintAtomSol100_1()
	println()

	println("[SCENARIO] 4. Mint position 02 atom:sol:100")
	mintAtomSol100_2()
	println()

	println("[SCENARIO] 5. Create external incentive with ATOM")
	createExternalIncentiveAtom()
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

	pl.CreatePool(cross, atomPath, solPath, 100, "79228162514264337593543950337")
	pl.CreatePool(cross, atomPath, atonePath, 3000, "79228162514264337593543950337")

	ufmt.Printf("[EXPECTED] pools created successfully\n")
	testing.SkipHeights(1)
}

func mintAtomSol100_1() {
	testing.SetRealm(adminRealm)

	atom.Approve(cross, poolAddr, maxInt64)
	sol.Approve(cross, poolAddr, maxInt64)

	positionId, _, _, _ := pn.Mint(
		cross,
		atomPath,
		solPath,
		fee100,
		int32(-50),
		int32(50),
		"50",
		"50",
		"1",
		"1",
		max_timeout,
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

func mintAtomSol100_2() {
	testing.SetRealm(adminRealm)

	atom.Approve(cross, poolAddr, maxInt64)
	sol.Approve(cross, poolAddr, maxInt64)

	positionId, _, _, _ := pn.Mint(
		cross,
		atomPath,
		solPath,
		fee100,
		int32(-1000),
		int32(1000),
		"500000",
		"500000",
		"1",
		"1",
		max_timeout,
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

func createExternalIncentiveAtom() {
	testing.SetRealm(adminRealm)

	atom.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	sr.CreateExternalIncentive(
		cross,
		poolPath,
		atomPath,
		9_000_000_000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentive ATOM created successfully\n")
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

	oldAtom := atom.BalanceOf(adminUser)

	sr.CollectReward(cross, 1)
	sr.CollectReward(cross, 2)

	newAtom := atom.BalanceOf(adminUser)

	if newAtom-oldAtom != 0 {
		panic("expected no reward before incentive is active")
	}
	ufmt.Printf("[EXPECTED] no rewards before incentive is active: %d ATOM\n", newAtom-oldAtom)
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

	oldAtom := atom.BalanceOf(adminUser)
	sr.CollectReward(cross, 1)
	newAtom := atom.BalanceOf(adminUser)
	diff1 := newAtom - oldAtom
	ufmt.Printf("[EXPECTED] position 01 reward: %d ATOM\n", diff1)

	sr.CollectReward(cross, 2)
	newAtom2 := atom.BalanceOf(adminUser)
	diff2 := newAtom2 - newAtom
	ufmt.Printf("[EXPECTED] position 02 reward: %d ATOM\n", diff2)
}

func makePosition1OutRange() {
	testing.SetRealm(adminRealm)
	poolTick := pl.GetSlot0Tick(poolPath)
	if poolTick != 0 {
		panic("expected pool tick to be 0")
	}

	// ROUTER SWAP
	testing.SetRealm(adminRealm)

	atom.Approve(cross, poolAddr, maxInt64)
	sol.Approve(cross, poolAddr, maxInt64)

	atom.Approve(cross, routerAddr, maxInt64)
	sol.Approve(cross, routerAddr, maxInt64)

	tokenIn, tokenOut := rr.ExactInSwapRoute(
		cross,
		atomPath,
		solPath,
		"100000",
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100",
		"100",
		"0",
		max_timeout,
		"",
	)

	if tokenIn != "100000" || tokenOut != "-98873" {
		panic("unexpected swap result")
	}

	testing.SetRealm(adminRealm)
	poolTick = pl.GetSlot0Tick(poolPath)
	if poolTick != -195 {
		panic("expected pool tick to be -195")
	}

	ufmt.Printf("[EXPECTED] position 01 made out of range by swap, current tick: %d\n", poolTick)
}

func rewardNowAfter1Block() {
	testing.SetRealm(adminRealm)
	sr.CollectReward(cross, 1)
	sr.CollectReward(cross, 2)

	testing.SkipHeights(1)

	oldAtom := atom.BalanceOf(adminUser)
	sr.CollectReward(cross, 1)
	newAtom := atom.BalanceOf(adminUser)
	diff1 := newAtom - oldAtom

	if diff1 != 0 {
		panic("expected no reward for out of range position")
	}
	ufmt.Printf("[EXPECTED] position 01 (out of range) reward: %d ATOM\n", diff1)

	sr.CollectReward(cross, 2)
	newAtom2 := atom.BalanceOf(adminUser)
	diff2 := newAtom2 - newAtom
	ufmt.Printf("[EXPECTED] position 02 (in range) reward: %d ATOM\n", diff2)
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
// [SCENARIO] 3. Mint position 01 atom:sol:100
// [EXPECTED] position 01 minted: id=1
//
// [SCENARIO] 4. Mint position 02 atom:sol:100
// [EXPECTED] position 02 minted: id=2
//
// [SCENARIO] 5. Create external incentive with ATOM
// [EXPECTED] external incentive ATOM created successfully
//
// [SCENARIO] 6. Stake positions 01 and 02
// [EXPECTED] positions 01 and 02 staked successfully
//
// [SCENARIO] 7. Check rewards before incentive is active
// [EXPECTED] no rewards before incentive is active: 0 ATOM
//
// [SCENARIO] 8. Check rewards after 50 blocks
// [INFO] making external incentive active
// [INFO] checking rewards after 50 blocks
// [EXPECTED] position 01 reward: 6360 ATOM
// [EXPECTED] position 02 reward: 3256379 ATOM
//
// [SCENARIO] 9. Make position 01 out of range via swap
// [EXPECTED] position 01 made out of range by swap, current tick: -195
//
// [SCENARIO] 10. Check rewards after position goes out of range
// [EXPECTED] position 01 (out of range) reward: 0 ATOM
// [EXPECTED] position 02 (in range) reward: 5784 ATOM
