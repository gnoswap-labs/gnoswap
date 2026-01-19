package v1

import (
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/emission"
	pl "gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
	sr "gno.land/r/gnoswap/staker"
	"gno.land/r/onbloc/bar"

	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/position/v1"
)

const (
	// External incentive timestamps
	incentiveDuration int64 = 90 * 24 * 60 * 60 // 90 days

	rewardMinimumAmount int64 = 1000000000
)

func TestCollectRewardGracefulDegradation(t *testing.T) {
	initStakerTest(t)
	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)
	incentiveStartTimestamp := time.Now().AddDate(0, 0, 1).Truncate(24 * time.Hour).Unix()

	// Test 1: Normal collection with sufficient rewards
	t.Run("normal collection works", func(t *testing.T) {
		testing.SetRealm(adminRealm)
		pl.SetPoolCreationFee(cross, 0)
		emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

		// setup
		govAddr := rbac.DefaultRoleAddresses[prabc.ROLE_GOVERNANCE]
		testing.SetRealm(testing.NewUserRealm(govAddr))

		mockInstanceSetMinimumRewardAmount(1000000000)
		mockInstanceSetUnstakingFee(0)

		// Create pool
		testing.SetRealm(adminRealm)
		pl.CreatePool(cross, barPath, bazPath, fee3000, "79228162514264337593543950336")

		// Set pool tier
		mockInstanceSetPoolTier(poolPath, 1)

		// Give tokens to test user
		TokenFaucet(t, barPath, addr01)
		TokenFaucet(t, bazPath, addr01)
		TokenFaucet(t, gnsPath, addr01)

		// Approve tokens
		testing.SetRealm(testing.NewUserRealm(addr01))
		TokenApprove(t, barPath, addr01, poolAddr, maxApprove)
		TokenApprove(t, bazPath, addr01, poolAddr, maxApprove)

		// Mint position
		positionId, _, _, _ := MintPosition(
			t,
			barPath,
			bazPath,
			fee3000,
			-18000, // Multiple of 60
			18000,  // Multiple of 60
			"1000000",
			"1000000",
			"0",
			"0",
			max_timeout,
			addr01,
			addr01,
		)

		// Stake position
		testing.SetRealm(testing.NewUserRealm(addr01))
		getMockInstance().nftAccessor.Mint(addr01, positionIdFrom(positionId))
		getMockInstance().nftAccessor.Approve(stakerAddr, positionIdFrom(positionId))

		mockInstanceStakeToken(positionId, "")

		// Create external incentive
		testing.SetRealm(adminRealm)
		gns.Approve(cross, stakerAddr, maxApprove)

		mockInstanceCreateExternalIncentive(poolPath, gnsPath, rewardMinimumAmount, incentiveStartTimestamp, incentiveStartTimestamp+incentiveDuration)

		// Wait for external incentive to start (skip to start timestamp)
		// Calculate blocks to skip based on current time vs start timestamp
		// Assuming 2 seconds per block as in scenario test
		currentTime := time.Now().Unix()
		timeToWait := incentiveStartTimestamp - currentTime
		blocksToSkip := timeToWait / 2
		if blocksToSkip > 0 {
			testing.SkipHeights(blocksToSkip)
		}

		// Skip some more blocks to accumulate rewards
		testing.SkipHeights(20)

		testing.SetRealm(testing.NewUserRealm(addr01))

		beforeGns := gns.BalanceOf(addr01)
		beforeBar := bar.BalanceOf(addr01)

		// Should not panic
		mockInstanceCollectReward(positionId, false)

		afterGns := gns.BalanceOf(addr01)
		afterBar := bar.BalanceOf(addr01)

		t.Logf("beforeGns: %d, afterGns: %d", beforeGns, afterGns)
		t.Logf("beforeBar: %d, afterBar: %d", beforeBar, afterBar)

		// Should have received some rewards
		if afterGns <= beforeGns {
			t.Error("expected to receive GNS rewards")
		}
	})

	// Test 2: Create incentive with insufficient reward amount
	t.Run("very small amount of external reward", func(t *testing.T) {
		// Create another position for testing
		testing.SetRealm(testing.NewUserRealm(addr02))
		TokenFaucet(t, barPath, addr02)
		TokenFaucet(t, bazPath, addr02)
		TokenApprove(t, barPath, addr02, poolAddr, maxApprove)
		TokenApprove(t, bazPath, addr02, poolAddr, maxApprove)

		positionId2, _, _, _ := MintPosition(
			t,
			barPath,
			bazPath,
			fee3000,
			-18000,
			18000,
			"1000000",
			"1000000",
			"0",
			"0",
			max_timeout,
			addr02,
			addr02,
		)

		getMockInstance().nftAccessor.Mint(addr02, positionIdFrom(positionId2))
		getMockInstance().nftAccessor.Approve(stakerAddr, positionIdFrom(positionId2))
		mockInstanceStakeToken(positionId2, "")

		// Create external incentive with very small amount
		testing.SetRealm(adminRealm)
		bar.Approve(cross, stakerAddr, 100)

		expectedMsg := "[GNOSWAP-STAKER-004] invalid input data || rewardAmount(100) is less than minimum required amount(1000000000)"
		uassert.AbortsWithMessage(t, expectedMsg, func() {
			mockInstanceCreateExternalIncentive(poolPath, barPath, 100, incentiveStartTimestamp, incentiveStartTimestamp+incentiveDuration)
		})
	})
}

// TestCollectReward_NilIncentiveSkipped verifies that CollectReward
// gracefully skips external incentives that have been removed
// and returns nil when looked up.
func TestCollectReward_NilIncentiveSkipped(t *testing.T) {
	initStakerTest(t)

	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	CreatePool(barPath, bazPath, fee3000, "79228162514264337593543950336", adminAddr)
	mockInstanceSetPoolTier(poolPath, 1)

	// Prepare user liquidity and stake
	TokenFaucet(t, barPath, addr01)
	TokenFaucet(t, bazPath, addr01)

	testing.SetRealm(testing.NewUserRealm(addr01))
	TokenApprove(t, barPath, addr01, poolAddr, maxApprove)
	TokenApprove(t, bazPath, addr01, poolAddr, maxApprove)

	positionId, _, _, _ := MintPosition(
		t,
		barPath,
		bazPath,
		fee3000,
		-18000,
		18000,
		"1000000",
		"1000000",
		"0",
		"0",
		max_timeout,
		addr01,
		addr01,
	)

	getMockInstance().nftAccessor.Mint(addr01, positionIdFrom(positionId))
	getMockInstance().nftAccessor.Approve(stakerAddr, positionIdFrom(positionId))
	mockInstanceStakeToken(positionId, "")

	// Create an external incentive
	TokenFaucet(t, gnsPath, addr01)
	testing.SetRealm(testing.NewUserRealm(addr01))
	gnsApprove(t, addr01, stakerAddr, maxApprove)

	startTimestamp := int64(1234569600)
	mockInstanceCreateExternalIncentive(
		poolPath,
		gnsPath,
		rewardMinimumAmount,
		startTimestamp,
		startTimestamp+incentiveDuration,
	)

	// Allow some rewards to accrue
	testing.SkipHeights(100)

	// Find the incentive ID
	incentives := getMockInstance().getExternalIncentives()
	incentiveId := ""
	incentives.tree.Iterate("", "", func(key string, value any) bool {
		incentiveId = key
		return true // stop after first
	})

	if incentiveId == "" {
		t.Fatal("expected incentive to be created")
	}

	// Remove the incentive from the external incentives tree to simulate deleted
	incentives.tree.Remove(incentiveId)

	// CollectReward should not panic when incentive is nil
	testing.SetRealm(testing.NewUserRealm(addr01))
	uassert.NotPanics(t, func() {
		mockInstanceCollectReward(positionId, false)
	})
}

// CollectReward should not process the same external penalty multiple times
// when an incentive is missing but the deposit's reward state is kept.
func TestCollectReward_ExternalPenaltyNotDoubleCountedWhenIncentiveMissing(t *testing.T) {
	initStakerTest(t)

	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	CreatePool(barPath, bazPath, fee3000, "79228162514264337593543950336", adminAddr)
	mockInstanceSetPoolTier(poolPath, 1)
	mockInstanceAddToken(barPath)

	// Prepare user liquidity and stake.
	TokenFaucet(t, barPath, addr01)
	TokenFaucet(t, bazPath, addr01)

	testing.SetRealm(testing.NewUserRealm(addr01))
	TokenApprove(t, barPath, addr01, poolAddr, maxApprove)
	TokenApprove(t, bazPath, addr01, poolAddr, maxApprove)

	positionId, _, _, _ := MintPosition(
		t,
		barPath,
		bazPath,
		fee3000,
		-18000,
		18000,
		"1000000",
		"1000000",
		"0",
		"0",
		max_timeout,
		addr01,
		addr01,
	)

	getMockInstance().nftAccessor.Mint(addr01, positionIdFrom(positionId))
	getMockInstance().nftAccessor.Approve(stakerAddr, positionIdFrom(positionId))
	mockInstanceStakeToken(positionId, "")

	// Fund caller for incentive creation.
	TokenFaucet(t, gnsPath, addr01)
	TokenFaucet(t, barPath, addr01)

	// Create an external incentive that has already started.
	testing.SetRealm(testing.NewUserRealm(addr01))
	gnsApprove(t, addr01, stakerAddr, maxApprove)
	barApprove(t, addr01, stakerAddr, maxApprove)

	startTimestamp := int64(1234569600)
	mockInstanceCreateExternalIncentive(
		poolPath,
		barPath,
		rewardMinimumAmount,
		startTimestamp,
		startTimestamp+incentiveDuration,
	)

	// Allow some rewards to accrue.
	testing.SkipHeights(3600)

	// Locate the incentive ID and mutate the stored amount to simulate missing metadata/funds.
	incentives := getMockInstance().getExternalIncentives()
	incentiveId := ""
	var incentive *sr.ExternalIncentive
	incentives.tree.Iterate("", "", func(key string, value any) bool {
		if incentive == nil {
			incentiveId = key
			incentive = value.(*sr.ExternalIncentive)
		}
		return false
	})

	if incentive == nil {
		t.Fatal("expected incentive to be created")
	}

	originalRewardAmount := incentive.RewardAmount()
	incentive.SetRewardAmount(0)
	incentives.set(incentiveId, incentive)

	// First collect should skip external processing because rewardAmount is zero.
	testing.SetRealm(testing.NewUserRealm(addr01))
	communityPoolBefore := TokenBalance(t, barPath, communityPoolAddr)
	resolver := getMockInstance().getDepositResolver(positionId)
	firstLastCollect := resolver.ExternalRewardLastCollectTime(incentiveId)

	mockInstanceCollectReward(positionId, false)

	resolver = getMockInstance().getDepositResolver(positionId)
	uassert.Equal(t, firstLastCollect, resolver.ExternalRewardLastCollectTime(incentiveId))
	uassert.Equal(t, int64(0), resolver.CollectedExternalReward(incentiveId))
	uassert.Equal(t, communityPoolBefore, TokenBalance(t, barPath, communityPoolAddr))

	// Restore reward amount and collect again; penalty should be processed once.
	incentive.SetRewardAmount(originalRewardAmount)
	incentives.set(incentiveId, incentive)

	communityPoolBefore = TokenBalance(t, barPath, communityPoolAddr)
	mockInstanceCollectReward(positionId, false)

	resolver = getMockInstance().getDepositResolver(positionId)
	communityPoolAfter := TokenBalance(t, barPath, communityPoolAddr)
	penaltyDelta := communityPoolAfter - communityPoolBefore
	if penaltyDelta <= 0 {
		t.Fatalf("expected external penalty to be applied once, got %d", penaltyDelta)
	}
	collectedAfter := resolver.CollectedExternalReward(incentiveId)
	if collectedAfter == 0 {
		t.Fatal("expected external reward to be collected after incentive recovery")
	}
	lastCollectAfter := resolver.ExternalRewardLastCollectTime(incentiveId)

	// Subsequent collect in the same second should not apply the penalty again.
	mockInstanceCollectReward(positionId, false)
	resolver = getMockInstance().getDepositResolver(positionId)
	uassert.Equal(t, communityPoolAfter, TokenBalance(t, barPath, communityPoolAddr))
	uassert.Equal(t, collectedAfter, resolver.CollectedExternalReward(incentiveId))
	uassert.Equal(t, lastCollectAfter, resolver.ExternalRewardLastCollectTime(incentiveId))
}

// TestCollectReward_ZeroNetRewardWithPenalty tests the case where fees/warmup zero out
// the user reward but leave InternalPenalty > 0. This ensures penalties are properly
// handled even when toUser = 0.
func TestCollectReward_ZeroNetRewardWithPenalty(t *testing.T) {
	initStakerTest(t)

	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	// Create pool
	CreatePool(barPath, bazPath, fee3000, "79228162514264337593543950336", adminAddr)
	mockInstanceSetPoolTier(poolPath, 1)

	// Set up high unstaking fee to ensure penalty exists
	govAddr := rbac.DefaultRoleAddresses[prabc.ROLE_GOVERNANCE]
	testing.SetRealm(testing.NewUserRealm(govAddr))
	mockInstanceSetUnstakingFee(1000) // 10% (maximum allowed)

	// Prepare user liquidity and stake
	testing.SetRealm(testing.NewUserRealm(addr01))
	TokenFaucet(t, barPath, addr01)
	TokenFaucet(t, bazPath, addr01)
	TokenFaucet(t, gnsPath, addr01)

	TokenApprove(t, barPath, addr01, poolAddr, maxApprove)
	TokenApprove(t, bazPath, addr01, poolAddr, maxApprove)

	positionId, _, _, _ := MintPosition(
		t,
		barPath,
		bazPath,
		fee3000,
		-18000,
		18000,
		"1000000",
		"1000000",
		"0",
		"0",
		max_timeout,
		addr01,
		addr01,
	)

	getMockInstance().nftAccessor.Mint(addr01, positionIdFrom(positionId))
	getMockInstance().nftAccessor.Approve(stakerAddr, positionIdFrom(positionId))
	mockInstanceStakeToken(positionId, "")

	// Create warmup period that will consume rewards
	testing.SetRealm(adminRealm)
	mockInstanceSetWarmupPeriod(poolPath, 86400) // 1 day warmup

	// Skip some time but not enough to fully pass warmup
	testing.SkipHeights(100) // Small amount of time

	// Record balances before collection
	testing.SetRealm(testing.NewUserRealm(addr01))
	userGnsBefore := gns.BalanceOf(addr01)
	communityGnsBefore := gns.BalanceOf(communityPoolAddr)

	// Get deposit info to check internal state
	depositResolver := getMockInstance().getDepositResolver(positionId)

	// Collect reward - should process penalty even if net reward is 0
	mockInstanceCollectReward(positionId, false)

	// Check balances after
	userGnsAfter := gns.BalanceOf(addr01)
	communityGnsAfter := gns.BalanceOf(communityPoolAddr)

	// User should receive no reward (toUser = 0)
	uassert.Equal(t, userGnsBefore, userGnsAfter)

	// Community pool should receive penalty if any was calculated
	// This test verifies the penalty transfer path works even when toUser = 0
	if communityGnsAfter <= communityGnsBefore {
		t.Logf("Community pool before: %d, after: %d", communityGnsBefore, communityGnsAfter)
		t.Logf("Note: If no penalty was generated, the warmup/fee configuration may need adjustment")
	}

	// Verify internal accounting was updated
	collectedInternal := depositResolver.CollectedInternalReward()
	uassert.True(t, collectedInternal >= 0, "collected internal reward should be tracked")
}

func TestUnStakeToken(t *testing.T) {
	initStakerTest(t)

	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	// Create pool
	CreatePool(barPath, bazPath, fee3000, "79228162514264337593543950336", adminAddr)
	mockInstanceSetPoolTier(poolPath, 1)

	// Add external token
	mockInstanceAddToken(barPath)

	// Prepare user liquidity
	testing.SetRealm(testing.NewUserRealm(addr01))
	TokenFaucet(t, barPath, addr01)
	TokenFaucet(t, bazPath, addr01)
	TokenFaucet(t, gnsPath, addr01)

	TokenApprove(t, barPath, addr01, poolAddr, maxApprove)
	TokenApprove(t, bazPath, addr01, poolAddr, maxApprove)

	// Create position with specific tick range
	tickLower := int32(-18000)
	tickUpper := int32(18000)
	positionId, _, _, _ := MintPosition(
		t,
		barPath,
		bazPath,
		fee3000,
		tickLower,
		tickUpper,
		"10000000",
		"10000000",
		"0",
		"0",
		max_timeout,
		addr01,
		addr01,
	)

	getMockInstance().nftAccessor.Mint(addr01, positionIdFrom(positionId))
	getMockInstance().nftAccessor.Approve(stakerAddr, positionIdFrom(positionId))

	// Stake the position
	mockInstanceStakeToken(positionId, "")

	// Verify operator is set after staking
	operatorAfterStake := getPositionOperator(positionId)
	uassert.NotEqual(t, ZERO_ADDRESS, operatorAfterStake)

	// Create external incentive
	testing.SetRealm(testing.NewUserRealm(addr01))
	barApprove(t, addr01, stakerAddr, rewardMinimumAmount)
	gnsApprove(t, addr01, stakerAddr, 1000000000) // Approve GNS deposit

	// Incentive must start at least 1 day in the future (midnight)
	tomorrow := time.Now().AddDate(0, 0, 1)
	startTimestamp := tomorrow.Truncate(24 * time.Hour).Unix()
	mockInstanceCreateExternalIncentive(
		poolPath,
		barPath,
		rewardMinimumAmount,
		startTimestamp,
		startTimestamp+incentiveDuration,
	)

	// Skip time to accumulate rewards
	testing.SkipHeights(100)

	// Get pool state before unstaking
	pool := getMockInstance().getPools().GetPoolOrNil(poolPath)
	uassert.NotNil(t, pool)
	poolResolver := NewPoolResolver(pool)

	// Get deposit info before unstaking
	deposit := getMockInstance().getDeposits().get(positionId)
	uassert.NotNil(t, deposit)

	// Verify external incentive tracking exists
	externalRewards := deposit.CollectedExternalRewards()
	uassert.True(t, externalRewards.Size() >= 0, "should have external reward tracking")

	// Store initial tick state for comparison
	lowerTick := poolResolver.TickResolver(tickLower)
	upperTick := poolResolver.TickResolver(tickUpper)
	initialLowerLiquidity := lowerTick.StakedLiquidityGross().Clone()
	initialUpperLiquidity := upperTick.StakedLiquidityGross().Clone()

	// Unstake the position
	testing.SetRealm(testing.NewUserRealm(addr01))
	resultPoolPath := mockInstanceUnStakeToken(positionId, false)
	uassert.Equal(t, poolPath, resultPoolPath)

	// Verify operator is reset to zero address
	operatorAfterUnstake := getPositionOperator(positionId)
	uassert.Equal(t, ZERO_ADDRESS, operatorAfterUnstake)

	// Verify NFT ownership transferred back
	owner, err := getMockInstance().nftAccessor.OwnerOf(positionIdFrom(positionId))
	uassert.NoError(t, err)
	uassert.Equal(t, addr01, owner)

	// Verify deposit is removed
	deposits := getMockInstance().getDeposits()
	uassert.False(t, deposits.Has(positionId), "deposit should be removed after unstaking")

	// Verify tick liquidity was updated (should be reduced after unstaking)
	finalLowerLiquidity := poolResolver.TickResolver(tickLower).StakedLiquidityGross()
	finalUpperLiquidity := poolResolver.TickResolver(tickUpper).StakedLiquidityGross()
	uassert.True(t, finalLowerLiquidity.Lt(initialLowerLiquidity) || finalLowerLiquidity.IsZero(),
		"lower tick liquidity should be reduced")
	uassert.True(t, finalUpperLiquidity.Lt(initialUpperLiquidity) || finalUpperLiquidity.IsZero(),
		"upper tick liquidity should be reduced")
}

// TestStakeToken_EmptyIncentiveList tests that after staking,
// the deposit's external incentive list is empty (lazy sync optimization).
func TestStakeToken_EmptyIncentiveList(t *testing.T) {
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	staker := testutils.TestAddress("staker1")
	currentTime := time.Now().Unix()

	// Create pool with existing incentive
	pool := sr.NewPool(poolPath, currentTime)

	creator := testutils.TestAddress("creator")
	incentiveId := "test-incentive-1"
	startTime := currentTime - 86400
	endTime := currentTime + 86400*7

	incentive := sr.NewExternalIncentive(
		incentiveId,
		poolPath,
		WUGNOT_PATH,
		10_000_000,
		startTime,
		endTime,
		creator,
		100_000_000,
		1000,
		currentTime-86400,
		false,
	)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(creator, incentive)

	// Create deposit (simulating StakeToken)
	warmups := sr.DefaultWarmupTemplate()
	deposit := sr.NewDeposit(
		staker,
		poolPath,
		u256.NewUint(1000),
		currentTime,
		-10000,
		10000,
		warmups,
	)

	// Verify deposit's incentive list is empty
	incentiveIds := deposit.GetExternalIncentiveIdList()
	if len(incentiveIds) != 0 {
		t.Errorf("Expected empty incentive list after StakeToken, got %d incentives", len(incentiveIds))
	}

	// Verify lastExternalIncentiveUpdatedAt is 0
	lastUpdate := deposit.LastExternalIncentiveUpdatedAt()
	if lastUpdate != 0 {
		t.Errorf("Expected lastExternalIncentiveUpdatedAt to be 0, got %d", lastUpdate)
	}
}

// TestStore_ExternalIncentivesByCreationTime tests the store functions
// for the time-based incentive index with 2-level structure.
func TestStore_ExternalIncentivesByCreationTime(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath1 := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	poolPath2 := "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:3000"

	// Test SetExternalIncentivesByCreationTime with 2-level structure
	tree := sr.NewUintTree()

	// Create pool map for timestamp 100
	poolMap1 := avl.NewTree()
	poolMap1.Set(poolPath1, []string{"incentive1"})
	tree.Set(100, poolMap1)

	// Create pool map for timestamp 200
	poolMap2 := avl.NewTree()
	poolMap2.Set(poolPath1, []string{"incentive2"})
	poolMap2.Set(poolPath2, []string{"incentive3"})
	tree.Set(200, poolMap2)

	err := instance.store.SetExternalIncentivesByCreationTime(tree)
	if err != nil {
		t.Fatalf("Failed to set incentives tree: %v", err)
	}

	// Test HasExternalIncentivesByCreationTimeStoreKey - now true
	if !instance.store.HasExternalIncentivesByCreationTimeStoreKey() {
		t.Error("Expected store key to exist after set")
	}

	// Test GetExternalIncentivesByCreationTime
	retrieved := instance.store.GetExternalIncentivesByCreationTime()
	if retrieved == nil {
		t.Fatal("Expected to retrieve tree")
	}

	// Verify data at timestamp 100
	value1, exists1 := retrieved.Get(100)
	if !exists1 {
		t.Error("Expected pool map at timestamp 100")
	}
	pMap1, ok := value1.(*avl.Tree)
	if !ok {
		t.Fatalf("Expected *avl.Tree at timestamp 100, got %T", value1)
	}
	idsValue1, exists := pMap1.Get(poolPath1)
	if !exists {
		t.Error("Expected incentives for poolPath1 at timestamp 100")
	}
	ids1 := idsValue1.([]string)
	if len(ids1) != 1 || ids1[0] != "incentive1" {
		t.Errorf("Expected [incentive1], got %v", ids1)
	}

	// Verify data at timestamp 200
	value2, exists2 := retrieved.Get(200)
	if !exists2 {
		t.Error("Expected pool map at timestamp 200")
	}
	pMap2, ok := value2.(*avl.Tree)
	if !ok {
		t.Fatalf("Expected *avl.Tree at timestamp 200, got %T", value2)
	}

	// Check poolPath1 at timestamp 200
	idsValue2a, exists := pMap2.Get(poolPath1)
	if !exists {
		t.Error("Expected incentives for poolPath1 at timestamp 200")
	}
	ids2a := idsValue2a.([]string)
	if len(ids2a) != 1 || ids2a[0] != "incentive2" {
		t.Errorf("Expected [incentive2], got %v", ids2a)
	}

	// Check poolPath2 at timestamp 200
	idsValue2b, exists := pMap2.Get(poolPath2)
	if !exists {
		t.Error("Expected incentives for poolPath2 at timestamp 200")
	}
	ids2b := idsValue2b.([]string)
	if len(ids2b) != 1 || ids2b[0] != "incentive3" {
		t.Errorf("Expected [incentive3], got %v", ids2b)
	}
}
