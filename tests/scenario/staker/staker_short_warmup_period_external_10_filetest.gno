// external incentive + warm up period testing scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"math"
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

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
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create bar:qux:100 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint position 01 (bar:qux:100)")
	mintBarQux100Position1()
	println()

	println("[SCENARIO] 4. Create external incentive")
	createExternalIncentive()
	println()

	println("[SCENARIO] 5. Stake token 01")
	stakeToken1()
	println()

	println("[SCENARIO] 6. Check rewards before active")
	checkRewardsBeforeActive()
	println()

	println("[SCENARIO] 7. Wait for external incentive to become active")
	waitForActiveExternal()
	println()

	println("[SCENARIO] 8. Collect rewards after duration")
	collectRewardsAfterDuration()
	println()

	println("[SCENARIO] 9. Mint and stake position 02")
	mintAndStakePosition2()
	println()

	println("[SCENARIO] 10. Collect rewards for all positions")
	collectRewardsForAllPositions()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] override warm-up period for testing")
	sr.SetWarmUpByAdmin(cross, 30, 150)
	sr.SetWarmUpByAdmin(cross, 50, 300)
	sr.SetWarmUpByAdmin(cross, 70, 900)
	sr.SetWarmUpByAdmin(cross, 100, math.MaxInt64)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve gns for pool creation")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*3)

	println("[INFO] create bar:qux:100 pool")
	pl.CreatePool(cross, barPath, quxPath, 100, "79228162514264337593543950337")

	ufmt.Printf("[EXPECTED] pool created successfully\n")
	testing.SkipHeights(1)
}

func mintBarQux100Position1() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint position 01 (bar:qux:100)")
	positionId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,      // token0
		quxPath,      // token1
		fee100,       // fee
		int32(-1000), // tickLower
		int32(1000),  // tickUpper
		"50",         // amount0Desired
		"50",         // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 01 minted: ID=%d, liquidity=%s\n", positionId, liquidity)

	if positionId != 1 {
		panic("position ID should be 1")
	}

	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	if owner != adminAddr {
		panic("position should be owned by admin")
	}

	testing.SkipHeights(1)
}

func createExternalIncentive() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for external incentive")
	bar.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive for bar:qux:100")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		barPath,
		9_000_000_000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentive created successfully\n")
	testing.SkipHeights(1)
}

func stakeToken1() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker and stake position 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	ufmt.Printf("[EXPECTED] position 01 staked successfully\n")
	testing.SkipHeights(1)
}

func checkRewardsBeforeActive() {
	testing.SetRealm(adminRealm)

	println("[INFO] mint and distribute GNS before active")
	emission.MintAndDistributeGns(cross)

	ufmt.Printf("[EXPECTED] checked rewards before external incentive becomes active\n")
	testing.SkipHeights(1)
}

func waitForActiveExternal() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to make external incentive active")
	testing.SkipHeights(849) // in active
	testing.SkipHeights(1)   // active but no block passed since active
	testing.SkipHeights(50)  // skip 50 more blocks

	ufmt.Printf("[EXPECTED] external incentive is now active\n")
}

func collectRewardsAfterDuration() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip duration 200 blocks")
	testing.SkipHeights(200)

	println("[INFO] collect reward for position 01")
	oldBar := bar.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	newBar := bar.BalanceOf(adminUser)
	reward := newBar - oldBar

	ufmt.Printf("[EXPECTED] collected reward: %d BAR tokens\n", reward)

	testing.SkipHeights(1)
}

func mintAndStakePosition2() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting position 02")
	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint position 02 (bar:qux:100)")
	positionId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,      // token0
		quxPath,      // token1
		fee100,       // fee
		int32(-1000), // tickLower
		int32(1000),  // tickUpper
		"50",         // amount0Desired
		"50",         // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 02 minted: ID=%d, liquidity=%s\n", positionId, liquidity)

	if positionId != 2 {
		panic("position ID should be 2")
	}

	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	if owner != adminAddr {
		panic("position should be owned by admin")
	}

	println("[INFO] stake position 02")
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")

	ufmt.Printf("[EXPECTED] position 02 staked successfully\n")
	testing.SkipHeights(1)
}

func collectRewardsForAllPositions() {
	testing.SetRealm(adminRealm)

	println("[INFO] clear previous rewards")
	sr.CollectReward(cross, 1, false)
	sr.CollectReward(cross, 2, false)

	println("[INFO] skip 10 blocks to accumulate rewards")
	testing.SkipHeights(10)

	// Block per reward is 23
	// Skip 10 blocks => reward 230
	// Position 01 and 02 have same liquidity
	// Each position's 100% reward = (230 / 2) = 115
	// Position 01 warm-up 70% = 115 * 0.7 = 80.5
	// Position 02 warm-up 30% = 115 * 0.3 = 34.5

	println("[INFO] collect reward for position 01")
	oldBar := bar.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	newBar := bar.BalanceOf(adminUser)
	reward1 := newBar - oldBar

	ufmt.Printf("[EXPECTED] position 01 reward (70%% warm-up): %d\n", reward1)

	println("[INFO] collect reward for position 02")
	oldBar = newBar
	sr.CollectReward(cross, 2, false)
	newBar = bar.BalanceOf(adminUser)
	reward2 := newBar - oldBar

	ufmt.Printf("[EXPECTED] position 02 reward (30%% warm-up): %d\n", reward2)

	println("[INFO] external incentive warm-up period test completed successfully")
}

func positionIdFrom(positionId any) grc721.TokenID {
	if positionId == nil {
		panic("positionId is nil")
	}

	switch positionId.(type) {
	case string:
		return grc721.TokenID(positionId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(positionId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId.(uint64))))
	case grc721.TokenID:
		return positionId.(grc721.TokenID)
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize and setup
// [INFO] override warm-up period for testing
// [INFO] set unstaking fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create bar:qux:100 pool
// [INFO] approve gns for pool creation
// [INFO] create bar:qux:100 pool
// [EXPECTED] pool created successfully
//
// [SCENARIO] 3. Mint position 01 (bar:qux:100)
// [INFO] approve tokens for minting
// [INFO] mint position 01 (bar:qux:100)
// [EXPECTED] position 01 minted: ID=1, liquidity=1025
//
// [SCENARIO] 4. Create external incentive
// [INFO] approve tokens for external incentive
// [INFO] create external incentive for bar:qux:100
// [EXPECTED] external incentive created successfully
//
// [SCENARIO] 5. Stake token 01
// [INFO] approve NFT to staker and stake position 01
// [EXPECTED] position 01 staked successfully
//
// [SCENARIO] 6. Check rewards before active
// [INFO] mint and distribute GNS before active
// [EXPECTED] checked rewards before external incentive becomes active
//
// [SCENARIO] 7. Wait for external incentive to become active
// [INFO] skip blocks to make external incentive active
// [EXPECTED] external incentive is now active
//
// [SCENARIO] 8. Collect rewards after duration
// [INFO] skip duration 200 blocks
// [INFO] collect reward for position 01
// [EXPECTED] collected reward: 409808 BAR tokens
//
// [SCENARIO] 9. Mint and stake position 02
// [INFO] approve tokens for minting position 02
// [INFO] mint position 02 (bar:qux:100)
// [EXPECTED] position 02 minted: ID=2, liquidity=1025
// [INFO] stake position 02
// [EXPECTED] position 02 staked successfully
//
// [SCENARIO] 10. Collect rewards for all positions
// [INFO] clear previous rewards
// [INFO] skip 10 blocks to accumulate rewards
// [INFO] collect reward for position 01
// [EXPECTED] position 01 reward (70% warm-up): 8098
// [INFO] collect reward for position 02
// [EXPECTED] position 02 reward (30% warm-up): 3470
// [INFO] external incentive warm-up period test completed successfully
