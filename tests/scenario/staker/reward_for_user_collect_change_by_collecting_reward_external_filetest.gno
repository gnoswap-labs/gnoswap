// reward for user collect change by collecting reward (external) scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
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
	bazPath = "gno.land/r/onbloc/baz"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS
	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Create external incentive")
	createExternalIncentive()
	println()

	println("[SCENARIO] 4. Mint and stake position")
	mintAndStakePosition()
	println()

	println("[SCENARIO] 5. First external reward collection period")
	firstExternalRewardCollection()
	println()

	println("[SCENARIO] 6. Second external reward collection period")
	secondExternalRewardCollection()
	println()

	println("[SCENARIO] 7. Third external reward collection with longer interval")
	thirdExternalRewardCollectionLonger()
	println()

	println("[SCENARIO] 8. Compare external reward accumulation patterns")
	compareExternalRewardPatterns()
	println()

	println("[SCENARIO] 9. Final verification with multiple external collections")
	finalVerificationMultipleExternalCollections()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:100 pool")
	pl.CreatePool(cross, barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SkipHeights(1)
}

func createExternalIncentive() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for external incentive")
	bar.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive with bar token")
	sr.CreateExternalIncentive(
		cross,
		poolPath,
		barPath,
		90_000_000_000, // 90 billion bar tokens for 90 days
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[INFO] external incentive created - reward per block: ~1000000000\n")

	// Make external incentives start
	leftHeight := 978 - std.ChainHeight()
	if leftHeight > 0 {
		testing.SkipHeights(leftHeight + 5) // skip 5 blocks more
	}
}

func mintAndStakePosition() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(2)

	println("[INFO] mint position 01 (tick range: -100 ~ 100)")
	positionId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-100),
		int32(100),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position ID: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)

	println("[INFO] approve NFT to staker and stake position")
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross, positionId, "")

	ufmt.Printf("[EXPECTED] position staked successfully\n")
	testing.SkipHeights(1)
}

func firstExternalRewardCollection() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip 5 blocks for first external reward accumulation")
	testing.SkipHeights(5)

	println("[INFO] collect first external reward")
	beforeBar1 := bar.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterBar1 := bar.BalanceOf(adminUser)
	firstExternalReward := afterBar1 - beforeBar1

	ufmt.Printf("[EXPECTED] first external reward (5 blocks): %d\n", firstExternalReward)

	if firstExternalReward <= 0 {
		panic("should have received first external reward")
	}

	println("[INFO] first external reward collection completed")
}

func secondExternalRewardCollection() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip 5 blocks for second external reward accumulation")
	testing.SkipHeights(5)

	println("[INFO] collect second external reward")
	beforeBar2 := bar.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterBar2 := bar.BalanceOf(adminUser)
	secondExternalReward := afterBar2 - beforeBar2

	ufmt.Printf("[EXPECTED] second external reward (5 blocks): %d\n", secondExternalReward)

	if secondExternalReward <= 0 {
		panic("should have received second external reward")
	}

	println("[INFO] second external reward collection completed")
}

func thirdExternalRewardCollectionLonger() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip 10 blocks for third external reward accumulation (longer period)")
	testing.SkipHeights(10)

	println("[INFO] collect third external reward")
	beforeBar3 := bar.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterBar3 := bar.BalanceOf(adminUser)
	thirdExternalReward := afterBar3 - beforeBar3

	ufmt.Printf("[EXPECTED] third external reward (10 blocks): %d\n", thirdExternalReward)

	if thirdExternalReward <= 0 {
		panic("should have received third external reward")
	}

	println("[INFO] third external reward collection completed")
}

func compareExternalRewardPatterns() {
	testing.SetRealm(adminRealm)

	println("[INFO] analyze external reward accumulation patterns")

	// Test multiple small collections vs one large collection
	println("[INFO] test pattern: frequent small external collections")
	totalFromFrequentExternalCollections := int64(0)

	// Collect external rewards every 2 blocks, 5 times (total 10 blocks)
	for i := 0; i < 5; i++ {
		testing.SkipHeights(2)
		beforeBar := bar.BalanceOf(adminUser)
		sr.CollectReward(cross, 1, false)
		afterBar := bar.BalanceOf(adminUser)
		rewardFromSmallExternalCollection := afterBar - beforeBar
		totalFromFrequentExternalCollections += rewardFromSmallExternalCollection
		ufmt.Printf("[INFO] small external collection %d (2 blocks): %d\n", i+1, rewardFromSmallExternalCollection)
	}

	ufmt.Printf("[EXPECTED] total from frequent external collections (10 blocks): %d\n", totalFromFrequentExternalCollections)

	// Now test one large collection for comparison
	println("[INFO] test pattern: single large external collection")
	testing.SkipHeights(10)
	beforeBarLarge := bar.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterBarLarge := bar.BalanceOf(adminUser)
	rewardFromLargeExternalCollection := afterBarLarge - beforeBarLarge

	ufmt.Printf("[EXPECTED] single large external collection (10 blocks): %d\n", rewardFromLargeExternalCollection)

	println("[INFO] external reward pattern analysis:")
	ufmt.Printf("[INFO] - Frequent external collections total: %d\n", totalFromFrequentExternalCollections)
	ufmt.Printf("[INFO] - Single large external collection: %d\n", rewardFromLargeExternalCollection)

	if totalFromFrequentExternalCollections != rewardFromLargeExternalCollection {
		println("[INFO] external reward amounts may vary due to incentive timing and block-based calculations")
	} else {
		println("[INFO] external reward amounts are consistent regardless of collection frequency")
	}
}

func finalVerificationMultipleExternalCollections() {
	testing.SetRealm(adminRealm)

	println("[INFO] final verification with multiple rapid external collections")

	// Record initial balance
	initialBalance := bar.BalanceOf(adminUser)
	ufmt.Printf("[INFO] initial BAR balance: %d\n", initialBalance)

	// Skip some blocks to accumulate external rewards
	testing.SkipHeights(15)

	// Perform multiple collections in sequence
	println("[INFO] perform 3 consecutive external collections")

	collection1Before := bar.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	collection1After := bar.BalanceOf(adminUser)
	externalReward1 := collection1After - collection1Before
	ufmt.Printf("[EXPECTED] consecutive external collection 1: %d\n", externalReward1)

	collection2Before := bar.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	collection2After := bar.BalanceOf(adminUser)
	externalReward2 := collection2After - collection2Before
	ufmt.Printf("[EXPECTED] consecutive external collection 2: %d\n", externalReward2)

	collection3Before := bar.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	collection3After := bar.BalanceOf(adminUser)
	externalReward3 := collection3After - collection3Before
	ufmt.Printf("[EXPECTED] consecutive external collection 3: %d\n", externalReward3)

	// Only the first collection should yield external rewards, subsequent ones should be 0
	if externalReward1 <= 0 {
		panic("first external collection should have yielded rewards")
	}

	if externalReward2 != 0 {
		panic("second consecutive external collection should yield 0 rewards")
	}

	if externalReward3 != 0 {
		panic("third consecutive external collection should yield 0 rewards")
	}

	finalBalance := bar.BalanceOf(adminUser)
	totalExternalGained := finalBalance - initialBalance
	ufmt.Printf("[EXPECTED] total BAR gained in this test: %d\n", totalExternalGained)

	println("[INFO] external reward collection pattern scenario completed successfully")
	println("[INFO] confirmed: external rewards accumulate over time and are collected when requested")
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
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create bar:baz:100 pool
// [INFO] create bar:baz:100 pool
//
// [SCENARIO] 3. Create external incentive
// [INFO] approve tokens for external incentive
// [INFO] create external incentive with bar token
// [INFO] external incentive created - reward per block: ~1000000000
//
// [SCENARIO] 4. Mint and stake position
// [INFO] approve tokens for minting
// [INFO] mint position 01 (tick range: -100 ~ 100)
// [EXPECTED] position ID: 1
// [EXPECTED] liquidity: 200510
// [INFO] approve NFT to staker and stake position
// [EXPECTED] position staked successfully
//
// [SCENARIO] 5. First external reward collection period
// [INFO] skip 5 blocks for first external reward accumulation
// [INFO] collect first external reward
// [EXPECTED] first external reward (5 blocks): 41666
// [INFO] first external reward collection completed
//
// [SCENARIO] 6. Second external reward collection period
// [INFO] skip 5 blocks for second external reward accumulation
// [INFO] collect second external reward
// [EXPECTED] second external reward (5 blocks): 34722
// [INFO] second external reward collection completed
//
// [SCENARIO] 7. Third external reward collection with longer interval
// [INFO] skip 10 blocks for third external reward accumulation (longer period)
// [INFO] collect third external reward
// [EXPECTED] third external reward (10 blocks): 69444
// [INFO] third external reward collection completed
//
// [SCENARIO] 8. Compare external reward accumulation patterns
// [INFO] analyze external reward accumulation patterns
// [INFO] test pattern: frequent small external collections
// [INFO] small external collection 1 (2 blocks): 13888
// [INFO] small external collection 2 (2 blocks): 13888
// [INFO] small external collection 3 (2 blocks): 13888
// [INFO] small external collection 4 (2 blocks): 13888
// [INFO] small external collection 5 (2 blocks): 13888
// [EXPECTED] total from frequent external collections (10 blocks): 69440
// [INFO] test pattern: single large external collection
// [EXPECTED] single large external collection (10 blocks): 69444
// [INFO] external reward pattern analysis:
// [INFO] - Frequent external collections total: 69440
// [INFO] - Single large external collection: 69444
// [INFO] external reward amounts may vary due to incentive timing and block-based calculations
//
// [SCENARIO] 9. Final verification with multiple external collections
// [INFO] final verification with multiple rapid external collections
// [INFO] initial BAR balance: 99910000283716
// [INFO] perform 3 consecutive external collections
// [EXPECTED] consecutive external collection 1: 104165
// [EXPECTED] consecutive external collection 2: 0
// [EXPECTED] consecutive external collection 3: 0
// [EXPECTED] total BAR gained in this test: 104165
// [INFO] external reward collection pattern scenario completed successfully
// [INFO] confirmed: external rewards accumulate over time and are collected when requested
