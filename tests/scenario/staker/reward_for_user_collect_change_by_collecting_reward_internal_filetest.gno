// reward for user collect change by collecting reward (internal) scenario test

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

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint and stake position")
	mintAndStakePosition()
	println()

	println("[SCENARIO] 4. First reward collection period")
	firstRewardCollection()
	println()

	println("[SCENARIO] 5. Second reward collection period")
	secondRewardCollection()
	println()

	println("[SCENARIO] 6. Third reward collection with longer interval")
	thirdRewardCollectionLonger()
	println()

	println("[SCENARIO] 7. Compare reward accumulation patterns")
	compareRewardPatterns()
	println()

	println("[SCENARIO] 8. Final verification with multiple collections")
	finalVerificationMultipleCollections()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:100 pool")
	pl.CreatePool(cross, barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	println("[INFO] set pool to tier 1")
	sr.SetPoolTierByAdmin(cross, poolPath, 1)

	testing.SkipHeights(1)
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

func firstRewardCollection() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip 5 blocks for first reward accumulation")
	testing.SkipHeights(5)

	println("[INFO] collect first reward")
	beforeGns1 := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns1 := gns.BalanceOf(adminUser)
	firstReward := afterGns1 - beforeGns1

	ufmt.Printf("[EXPECTED] first reward (5 blocks): %d\n", firstReward)

	if firstReward <= 0 {
		panic("should have received first reward")
	}

	println("[INFO] first reward collection completed")
}

func secondRewardCollection() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip 5 blocks for second reward accumulation")
	testing.SkipHeights(5)

	println("[INFO] collect second reward")
	beforeGns2 := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns2 := gns.BalanceOf(adminUser)
	secondReward := afterGns2 - beforeGns2

	ufmt.Printf("[EXPECTED] second reward (5 blocks): %d\n", secondReward)

	if secondReward <= 0 {
		panic("should have received second reward")
	}

	println("[INFO] second reward collection completed")
}

func thirdRewardCollectionLonger() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip 10 blocks for third reward accumulation (longer period)")
	testing.SkipHeights(10)

	println("[INFO] collect third reward")
	beforeGns3 := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns3 := gns.BalanceOf(adminUser)
	thirdReward := afterGns3 - beforeGns3

	ufmt.Printf("[EXPECTED] third reward (10 blocks): %d\n", thirdReward)

	if thirdReward <= 0 {
		panic("should have received third reward")
	}

	println("[INFO] third reward collection completed")
}

func compareRewardPatterns() {
	testing.SetRealm(adminRealm)

	println("[INFO] analyze reward accumulation patterns")

	// Test multiple small collections vs one large collection
	println("[INFO] test pattern: frequent small collections")
	totalFromFrequentCollections := int64(0)

	// Collect rewards every 2 blocks, 5 times (total 10 blocks)
	for i := 0; i < 5; i++ {
		testing.SkipHeights(2)
		beforeGns := gns.BalanceOf(adminUser)
		sr.CollectReward(cross, 1, false)
		afterGns := gns.BalanceOf(adminUser)
		rewardFromSmallCollection := afterGns - beforeGns
		totalFromFrequentCollections += rewardFromSmallCollection
		ufmt.Printf("[INFO] small collection %d (2 blocks): %d\n", i+1, rewardFromSmallCollection)
	}

	ufmt.Printf("[EXPECTED] total from frequent collections (10 blocks): %d\n", totalFromFrequentCollections)

	// Now test one large collection for comparison
	println("[INFO] test pattern: single large collection")
	testing.SkipHeights(10)
	beforeGnsLarge := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGnsLarge := gns.BalanceOf(adminUser)
	rewardFromLargeCollection := afterGnsLarge - beforeGnsLarge

	ufmt.Printf("[EXPECTED] single large collection (10 blocks): %d\n", rewardFromLargeCollection)

	println("[INFO] reward pattern analysis:")
	ufmt.Printf("[INFO] - Frequent collections total: %d\n", totalFromFrequentCollections)
	ufmt.Printf("[INFO] - Single large collection: %d\n", rewardFromLargeCollection)

	if totalFromFrequentCollections != rewardFromLargeCollection {
		println("[INFO] reward amounts may vary due to emission timing and block-based calculations")
	} else {
		println("[INFO] reward amounts are consistent regardless of collection frequency")
	}
}

func finalVerificationMultipleCollections() {
	testing.SetRealm(adminRealm)

	println("[INFO] final verification with multiple rapid collections")

	// Record initial balance
	initialBalance := gns.BalanceOf(adminUser)
	ufmt.Printf("[INFO] initial GNS balance: %d\n", initialBalance)

	// Skip some blocks to accumulate rewards
	testing.SkipHeights(15)

	// Perform multiple collections in sequence
	println("[INFO] perform 3 consecutive collections")

	collection1Before := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	collection1After := gns.BalanceOf(adminUser)
	reward1 := collection1After - collection1Before
	ufmt.Printf("[EXPECTED] consecutive collection 1: %d\n", reward1)

	collection2Before := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	collection2After := gns.BalanceOf(adminUser)
	reward2 := collection2After - collection2Before
	ufmt.Printf("[EXPECTED] consecutive collection 2: %d\n", reward2)

	collection3Before := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	collection3After := gns.BalanceOf(adminUser)
	reward3 := collection3After - collection3Before
	ufmt.Printf("[EXPECTED] consecutive collection 3: %d\n", reward3)

	// Only the first collection should yield rewards, subsequent ones should be 0
	if reward1 <= 0 {
		panic("first collection should have yielded rewards")
	}

	if reward2 != 0 {
		panic("second consecutive collection should yield 0 rewards")
	}

	if reward3 != 0 {
		panic("third consecutive collection should yield 0 rewards")
	}

	finalBalance := gns.BalanceOf(adminUser)
	totalGained := finalBalance - initialBalance
	ufmt.Printf("[EXPECTED] total GNS gained in this test: %d\n", totalGained)

	println("[INFO] reward collection pattern scenario completed successfully")
	println("[INFO] confirmed: rewards accumulate over time and are collected when requested")
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
// [INFO] set pool to tier 1
//
// [SCENARIO] 3. Mint and stake position
// [INFO] approve tokens for minting
// [INFO] mint position 01 (tick range: -100 ~ 100)
// [EXPECTED] position ID: 1
// [EXPECTED] liquidity: 200510
// [INFO] approve NFT to staker and stake position
// [EXPECTED] position staked successfully
//
// [SCENARIO] 4. First reward collection period
// [INFO] skip 5 blocks for first reward accumulation
// [INFO] collect first reward
// [EXPECTED] first reward (5 blocks): 9631848
// [INFO] first reward collection completed
//
// [SCENARIO] 5. Second reward collection period
// [INFO] skip 5 blocks for second reward accumulation
// [INFO] collect second reward
// [EXPECTED] second reward (5 blocks): 8026540
// [INFO] second reward collection completed
//
// [SCENARIO] 6. Third reward collection with longer interval
// [INFO] skip 10 blocks for third reward accumulation (longer period)
// [INFO] collect third reward
// [EXPECTED] third reward (10 blocks): 16053080
// [INFO] third reward collection completed
//
// [SCENARIO] 7. Compare reward accumulation patterns
// [INFO] analyze reward accumulation patterns
// [INFO] test pattern: frequent small collections
// [INFO] small collection 1 (2 blocks): 3210615
// [INFO] small collection 2 (2 blocks): 3210615
// [INFO] small collection 3 (2 blocks): 3210615
// [INFO] small collection 4 (2 blocks): 3210615
// [INFO] small collection 5 (2 blocks): 3210615
// [EXPECTED] total from frequent collections (10 blocks): 16053075
// [INFO] test pattern: single large collection
// [EXPECTED] single large collection (10 blocks): 16053080
// [INFO] reward pattern analysis:
// [INFO] - Frequent collections total: 16053075
// [INFO] - Single large collection: 16053080
// [INFO] reward amounts may vary due to emission timing and block-based calculations
//
// [SCENARIO] 8. Final verification with multiple collections
// [INFO] final verification with multiple rapid collections
// [INFO] initial GNS balance: 100000065817623
// [INFO] perform 3 consecutive collections
// [EXPECTED] consecutive collection 1: 24079621
// [EXPECTED] consecutive collection 2: 0
// [EXPECTED] consecutive collection 3: 0
// [EXPECTED] total GNS gained in this test: 24079621
// [INFO] reward collection pattern scenario completed successfully
// [INFO] confirmed: rewards accumulate over time and are collected when requested
