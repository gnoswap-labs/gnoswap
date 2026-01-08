package v1

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"

	u256 "gno.land/p/gnoswap/uint256"

	sr "gno.land/r/gnoswap/staker"
)

// testState holds a complete test state setup for getter tests.
// This allows setting up state once and verifying multiple getters.
type testState struct {
	instance         *stakerV1
	poolPath         string
	incentiveId      string
	positionId       uint64
	owner            address
	incentive        *sr.ExternalIncentive
	deposit          *sr.Deposit
	pool             *sr.Pool
	fixedTimestamp   int64
	fixedBlockHeight int64
}

// setupBasicTestState creates a minimal test state for getter tests.
// Uses manager methods where possible, direct store access for complex items.
func setupBasicTestState(t *testing.T) *testState {
	t.Helper()
	initStakerTest(t)

	state := &testState{
		instance:         getMockInstance(),
		poolPath:         "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000",
		incentiveId:      "test-incentive-1",
		positionId:       uint64(1),
		owner:            addr01,
		fixedTimestamp:   int64(1000000),
		fixedBlockHeight: int64(100),
	}

	// Setup allowed tokens via manager method
	state.instance.AddToken(barPath)
	state.instance.AddToken(bazPath)

	// Setup config values via manager methods
	state.instance.SetDepositGnsAmount(1_000_000_000)
	state.instance.SetMinimumRewardAmount(500_000)
	state.instance.SetUnStakingFee(100) // 1%

	// Setup warmup template via manager method
	state.instance.SetWarmUp(30, 86400*5) // 30%, 5 days

	// Direct store access for complex state: Pool
	state.pool = sr.NewPool(state.poolPath, state.fixedTimestamp)
	state.instance.store.GetPools().Set(state.poolPath, state.pool)

	// Direct store access for complex state: ExternalIncentive
	state.incentive = sr.NewExternalIncentive(
		state.incentiveId,
		state.poolPath,
		barPath,
		10_000_000,                // rewardAmount
		state.fixedTimestamp,      // startTimestamp
		state.fixedTimestamp+3600, // endTimestamp (1 hour)
		state.owner,               // refundee
		1_000_000_000,             // depositGnsAmount
		state.fixedBlockHeight,    // createdHeight
		state.fixedTimestamp,      // currentTime
		false,                     // isRequestUnwrap
	)
	state.pool.Incentives().SetIncentive(state.incentiveId, state.incentive)
	state.instance.store.GetExternalIncentives().Set(state.incentiveId, state.incentive)

	// Direct store access for complex state: Deposit
	warmups := []sr.Warmup{
		{Index: 0, TimeDuration: 86400 * 5, NextWarmupTime: state.fixedTimestamp + 86400*5, WarmupRatio: 30},
		{Index: 1, TimeDuration: 86400 * 10, NextWarmupTime: state.fixedTimestamp + 86400*10, WarmupRatio: 50},
		{Index: 2, TimeDuration: 86400 * 30, NextWarmupTime: state.fixedTimestamp + 86400*30, WarmupRatio: 70},
	}
	state.deposit = sr.NewDeposit(
		state.owner,
		state.poolPath,
		u256.NewUint(1000000),
		state.fixedTimestamp,
		-100, // tickLower
		100,  // tickUpper
		warmups,
	)
	state.deposit.SetCollectedInternalReward(5000)
	state.deposit.SetCollectedExternalReward(state.incentiveId, 2500)
	state.deposit.SetExternalRewardLastCollectTime(state.incentiveId, state.fixedTimestamp+100)
	state.deposit.AddExternalIncentiveId(state.incentiveId)
	state.instance.store.GetDeposits().Set(sr.EncodeUint(state.positionId), state.deposit)

	// Setup stakers tree (address -> depositId -> *Deposit)
	stakersTree := state.instance.store.GetStakers()
	depositTree := avl.NewTree()
	depositTree.Set(sr.EncodeUint(state.positionId), state.deposit)
	stakersTree.Set(state.owner.String(), depositTree)

	// Setup pool tier
	state.instance.store.GetPoolTierMemberships().Set(state.poolPath, uint64(1))
	counts := state.instance.store.GetPoolTierCounts()
	counts[1] = 1
	state.instance.store.SetPoolTierCounts(counts)
	state.instance.store.SetPoolTierRatio(sr.TierRatio{Tier1: 50, Tier2: 30, Tier3: 20})

	// Setup total emission sent
	state.instance.store.SetTotalEmissionSent(100000)

	return state
}

func TestGetterIncentiveBasicProperties(t *testing.T) {
	state := setupBasicTestState(t)

	tests := []struct {
		name     string
		getter   func() any
		expected any
	}{
		{
			name:     "GetIncentiveStartTimestamp",
			getter:   func() any { return state.instance.GetIncentiveStartTimestamp(state.poolPath, state.incentiveId) },
			expected: state.fixedTimestamp,
		},
		{
			name:     "GetIncentiveEndTimestamp",
			getter:   func() any { return state.instance.GetIncentiveEndTimestamp(state.poolPath, state.incentiveId) },
			expected: state.fixedTimestamp + 3600,
		},
		{
			name:     "GetTargetPoolPathByIncentiveId",
			getter:   func() any { return state.instance.GetTargetPoolPathByIncentiveId(state.poolPath, state.incentiveId) },
			expected: state.poolPath,
		},
		{
			name:     "GetCreatedHeightOfIncentive",
			getter:   func() any { return state.instance.GetCreatedHeightOfIncentive(state.poolPath, state.incentiveId) },
			expected: state.fixedBlockHeight,
		},
		{
			name:     "GetIncentiveCreatedTimestamp",
			getter:   func() any { return state.instance.GetIncentiveCreatedTimestamp(state.poolPath, state.incentiveId) },
			expected: state.fixedTimestamp,
		},
		{
			name:     "GetIncentiveDepositGnsAmount",
			getter:   func() any { return state.instance.GetIncentiveDepositGnsAmount(state.poolPath, state.incentiveId) },
			expected: int64(1_000_000_000),
		},
		{
			name:     "GetIncentiveRefunded",
			getter:   func() any { return state.instance.GetIncentiveRefunded(state.poolPath, state.incentiveId) },
			expected: false,
		},
		{
			name:     "GetIncentiveRewardToken",
			getter:   func() any { return state.instance.GetIncentiveRewardToken(state.poolPath, state.incentiveId) },
			expected: barPath,
		},
		{
			name:     "GetIncentiveRefundee",
			getter:   func() any { return state.instance.GetIncentiveRefundee(state.poolPath, state.incentiveId) },
			expected: state.owner,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.getter()
			uassert.Equal(t, tt.expected, result)
		})
	}
}

// TestGetterIncentiveRewardAmounts tests derived reward values together.
// remaining = total - distributed
func TestGetterIncentiveRewardAmounts(t *testing.T) {
	state := setupBasicTestState(t)

	// Set distributed amount to create derived relationship
	state.incentive.SetDistributedRewardAmount(3_000_000)

	totalReward := state.instance.GetIncentiveTotalRewardAmount(state.poolPath, state.incentiveId)
	distributedReward := state.instance.GetIncentiveDistributedRewardAmount(state.poolPath, state.incentiveId)
	remainingReward := state.instance.GetIncentiveRemainingRewardAmount(state.poolPath, state.incentiveId)

	// Verify individual values
	uassert.Equal(t, int64(10_000_000), totalReward)
	uassert.Equal(t, int64(3_000_000), distributedReward)

	// Note: RewardAmount is the remaining reward (set at creation, then updated)
	// The NewExternalIncentive sets rewardAmount = totalRewardAmount initially
	// So remaining should be 10_000_000 (initial) since we haven't modified it
	uassert.Equal(t, int64(10_000_000), remainingReward)

	// Test reward per second
	rewardPerSecond := state.instance.GetIncentiveRewardPerSecond(state.poolPath, state.incentiveId)
	// rewardPerSecond = 10_000_000 / 3600 = 2777
	uassert.Equal(t, int64(2777), rewardPerSecond)

	// Test u256 variants
	rewardAmount := state.instance.GetIncentiveRewardAmount(state.poolPath, state.incentiveId)
	rewardAmountStr := state.instance.GetIncentiveRewardAmountAsString(state.poolPath, state.incentiveId)
	uassert.Equal(t, "10000000", rewardAmount.ToString())
	uassert.Equal(t, "10000000", rewardAmountStr)
}

func TestGetterPoolIncentiveDepositObjects(t *testing.T) {
	state := setupBasicTestState(t)

	pool := state.instance.GetPool(state.poolPath)
	uassert.Equal(t, state.poolPath, pool.PoolPath())

	incentive := state.instance.GetIncentive(state.poolPath, state.incentiveId)
	uassert.Equal(t, state.incentiveId, incentive.IncentiveId())
	uassert.Equal(t, barPath, incentive.RewardToken())

	deposit := state.instance.GetDeposit(state.positionId)
	uassert.Equal(t, state.owner, deposit.Owner())
	uassert.Equal(t, state.poolPath, deposit.TargetPoolPath())
}

func TestGetterCollectableRewards(t *testing.T) {
	state := setupBasicTestState(t)

	internal := state.instance.CollectableEmissionReward(state.positionId)
	uassert.Equal(t, int64(0), internal)

	external := state.instance.CollectableExternalIncentiveReward(state.positionId, state.incentiveId)
	uassert.Equal(t, int64(0), external)
}

func TestGetterPoolIncentiveIdList(t *testing.T) {
	state := setupBasicTestState(t)

	// Add another incentive
	incentive2 := sr.NewExternalIncentive(
		"test-incentive-2",
		state.poolPath,
		bazPath,
		5_000_000,
		state.fixedTimestamp,
		state.fixedTimestamp+7200,
		state.owner,
		500_000_000,
		state.fixedBlockHeight,
		state.fixedTimestamp,
		false,
	)
	state.pool.Incentives().SetIncentive("test-incentive-2", incentive2)

	ids := state.instance.GetPoolIncentiveIdList(state.poolPath)

	uassert.Equal(t, 2, len(ids))
}

func TestGetterExternalIncentiveByPoolPath(t *testing.T) {
	state := setupBasicTestState(t)

	incentives := state.instance.GetExternalIncentiveByPoolPath(state.poolPath)

	uassert.Equal(t, 1, len(incentives))
	uassert.Equal(t, state.incentiveId, incentives[0].IncentiveId())
}

func TestGetterDepositBasicProperties(t *testing.T) {
	state := setupBasicTestState(t)

	tests := []struct {
		name     string
		getter   func() any
		expected any
	}{
		{
			name:     "GetDepositOwner",
			getter:   func() any { return state.instance.GetDepositOwner(state.positionId) },
			expected: state.owner,
		},
		{
			name:     "GetDepositStakeTime",
			getter:   func() any { return state.instance.GetDepositStakeTime(state.positionId) },
			expected: state.fixedTimestamp,
		},
		{
			name:     "GetDepositTargetPoolPath",
			getter:   func() any { return state.instance.GetDepositTargetPoolPath(state.positionId) },
			expected: state.poolPath,
		},
		{
			name:     "GetDepositTickLower",
			getter:   func() any { return state.instance.GetDepositTickLower(state.positionId) },
			expected: int32(-100),
		},
		{
			name:     "GetDepositTickUpper",
			getter:   func() any { return state.instance.GetDepositTickUpper(state.positionId) },
			expected: int32(100),
		},
		{
			name:     "GetDepositStakeTimestamp",
			getter:   func() any { return state.instance.GetDepositStakeTimestamp(state.positionId) },
			expected: state.fixedTimestamp,
		},
		{
			name:     "GetDepositInternalRewardLastCollectTimestamp",
			getter:   func() any { return state.instance.GetDepositInternalRewardLastCollectTimestamp(state.positionId) },
			expected: state.fixedTimestamp,
		},
		{
			name:     "GetDepositCollectedInternalReward",
			getter:   func() any { return state.instance.GetDepositCollectedInternalReward(state.positionId) },
			expected: int64(5000),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.getter()
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestGetterDepositLiquidity(t *testing.T) {
	state := setupBasicTestState(t)

	liquidity := state.instance.GetDepositLiquidity(state.positionId)
	liquidityStr := state.instance.GetDepositLiquidityAsString(state.positionId)

	uassert.Equal(t, "1000000", liquidity.ToString())
	uassert.Equal(t, "1000000", liquidityStr)

	// Verify that returned liquidity is a clone
	liquidity.Add(liquidity, u256.NewUint(100))
	originalLiquidity := state.instance.GetDepositLiquidity(state.positionId)
	uassert.Equal(t, "1000000", originalLiquidity.ToString())
}

func TestGetterDepositExternalRewards(t *testing.T) {
	state := setupBasicTestState(t)

	// Test collected external reward
	collectedReward := state.instance.GetDepositCollectedExternalReward(state.positionId, state.incentiveId)
	uassert.Equal(t, int64(2500), collectedReward)

	// Test last collect timestamp
	lastCollectTime := state.instance.GetDepositExternalRewardLastCollectTimestamp(state.positionId, state.incentiveId)
	uassert.Equal(t, state.fixedTimestamp+100, lastCollectTime)

	// Test external incentive id list
	incentiveIds := state.instance.GetDepositExternalIncentiveIdList(state.positionId)
	uassert.Equal(t, 1, len(incentiveIds))
	uassert.Equal(t, state.incentiveId, incentiveIds[0])
}

func TestGetterDepositWarmUp(t *testing.T) {
	state := setupBasicTestState(t)

	warmups := state.instance.GetDepositWarmUp(state.positionId)

	uassert.Equal(t, 3, len(warmups))
	uassert.Equal(t, uint64(30), warmups[0].WarmupRatio)
	uassert.Equal(t, uint64(50), warmups[1].WarmupRatio)
	uassert.Equal(t, uint64(70), warmups[2].WarmupRatio)
}

func TestGetterIsStaked(t *testing.T) {
	state := setupBasicTestState(t)

	tests := []struct {
		name       string
		positionId uint64
		expected   bool
	}{
		{
			name:       "staked position returns true",
			positionId: state.positionId,
			expected:   true,
		},
		{
			name:       "non-staked position returns false",
			positionId: uint64(999),
			expected:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := state.instance.IsStaked(tt.positionId)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestGetterPoolTierProperties(t *testing.T) {
	state := setupBasicTestState(t)

	// Test pool tier
	tier := state.instance.GetPoolTier(state.poolPath)
	uassert.Equal(t, uint64(1), tier)

	// Test pool tier ratio
	ratio := state.instance.GetPoolTierRatio(state.poolPath)
	uassert.Equal(t, uint64(50), ratio)

	// Test pool tier count
	count := state.instance.GetPoolTierCount(1)
	uassert.Equal(t, uint64(1), count)

	// Test tier 0 returns 0
	countTier0 := state.instance.GetPoolTierCount(0)
	uassert.Equal(t, uint64(0), countTier0)
}

func TestGetterPoolsByTier(t *testing.T) {
	state := setupBasicTestState(t)

	// Add another pool to tier 1
	pool2Path := "gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:500"
	state.instance.store.GetPoolTierMemberships().Set(pool2Path, uint64(1))

	pools := state.instance.GetPoolsByTier(1)
	uassert.Equal(t, 2, len(pools))

	// Test tier 0 returns empty
	poolsTier0 := state.instance.GetPoolsByTier(0)
	uassert.Equal(t, 0, len(poolsTier0))

	// Test non-existent tier
	poolsTier99 := state.instance.GetPoolsByTier(99)
	uassert.Equal(t, 0, len(poolsTier99))
}

func TestGetterGlobalConfigValues(t *testing.T) {
	state := setupBasicTestState(t)

	tests := []struct {
		name     string
		getter   func() any
		expected any
	}{
		{
			name:     "GetDepositGnsAmount",
			getter:   func() any { return state.instance.GetDepositGnsAmount() },
			expected: int64(1_000_000_000),
		},
		{
			name:     "GetMinimumRewardAmount",
			getter:   func() any { return state.instance.GetMinimumRewardAmount() },
			expected: int64(500_000),
		},
		{
			name:     "GetUnstakingFee",
			getter:   func() any { return state.instance.GetUnstakingFee() },
			expected: int64(100),
		},
		{
			name:     "GetTotalEmissionSent",
			getter:   func() any { return state.instance.GetTotalEmissionSent() },
			expected: int64(100000),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.getter()
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestGetterAllowedTokens(t *testing.T) {
	state := setupBasicTestState(t)

	tokens := state.instance.GetAllowedTokens()

	// Should contain default tokens plus added ones
	uassert.True(t, len(tokens) >= 2)

	// Verify returned slice is a copy
	originalLen := len(tokens)
	tokens = append(tokens, "fake-token")
	newTokens := state.instance.GetAllowedTokens()
	uassert.Equal(t, originalLen, len(newTokens))
}

func TestGetterWarmupTemplate(t *testing.T) {
	state := setupBasicTestState(t)

	warmups := state.instance.GetWarmupTemplate()

	// Should have warmup entries
	uassert.True(t, len(warmups) > 0)

	// Verify returned slice is a copy
	originalLen := len(warmups)
	warmups = append(warmups, sr.Warmup{})
	newWarmups := state.instance.GetWarmupTemplate()
	uassert.Equal(t, originalLen, len(newWarmups))
}

func TestGetterStakedPositionCount(t *testing.T) {
	state := setupBasicTestState(t)

	// Initial count should be 1
	count := state.instance.GetTotalStakedPositionCount()
	uassert.Equal(t, uint64(1), count)

	// Add another deposit
	deposit2 := sr.NewDeposit(
		addr02,
		state.poolPath,
		u256.NewUint(2000000),
		state.fixedTimestamp,
		-200,
		200,
		[]sr.Warmup{},
	)
	state.instance.store.GetDeposits().Set(sr.EncodeUint(uint64(2)), deposit2)

	depositTree2 := avl.NewTree()
	depositTree2.Set(sr.EncodeUint(uint64(2)), deposit2)
	state.instance.store.GetStakers().Set(addr02.String(), depositTree2)

	count = state.instance.GetTotalStakedPositionCount()
	uassert.Equal(t, uint64(2), count)
}

func TestGetterStakedPositionsByUser(t *testing.T) {
	state := setupBasicTestState(t)

	// Test owner with positions
	positions := state.instance.GetStakedPositionsByUser(state.owner, 0, 10)
	uassert.Equal(t, 1, len(positions))
	uassert.Equal(t, state.positionId, positions[0])

	// Test owner without positions
	positionsEmpty := state.instance.GetStakedPositionsByUser(addr02, 0, 10)
	uassert.Equal(t, 0, len(positionsEmpty))
}

func TestGetterNonExistentIncentive(t *testing.T) {
	state := setupBasicTestState(t)

	uassert.PanicsContains(t, "incentive does not exist", func() {
		state.instance.GetIncentiveStartTimestamp(state.poolPath, "non-existent-incentive")
	})
}

func TestGetterNonExistentDeposit(t *testing.T) {
	state := setupBasicTestState(t)

	uassert.PanicsContains(t, "not found", func() {
		state.instance.GetDepositOwner(uint64(999))
	})
}

func TestGetterNonExistentPool(t *testing.T) {
	state := setupBasicTestState(t)

	uassert.PanicsContains(t, "does not exist", func() {
		state.instance.GetPoolIncentiveIdList("non-existent-pool")
	})
}

func TestGetterPoolTierForUntieredPool(t *testing.T) {
	state := setupBasicTestState(t)

	// Create a new pool without tier
	untieredPoolPath := "gno.land/r/test:gno.land/r/test2:500"
	untieredPool := sr.NewPool(untieredPoolPath, state.fixedTimestamp)
	state.instance.store.GetPools().Set(untieredPoolPath, untieredPool)

	// Should return 0 for untiered pool
	tier := state.instance.GetPoolTier(untieredPoolPath)
	uassert.Equal(t, uint64(0), tier)
}

func TestGetterMultipleDepositsForSameOwner(t *testing.T) {
	state := setupBasicTestState(t)

	// Add second deposit for same owner
	deposit2 := sr.NewDeposit(
		state.owner,
		state.poolPath,
		u256.NewUint(2000000),
		state.fixedTimestamp+100,
		-50,
		50,
		[]sr.Warmup{},
	)
	positionId2 := uint64(2)
	state.instance.store.GetDeposits().Set(sr.EncodeUint(positionId2), deposit2)

	// Update stakers tree
	stakersTree := state.instance.store.GetStakers()
	depositTreeI, _ := stakersTree.Get(state.owner.String())
	depositTree := depositTreeI.(*avl.Tree)
	depositTree.Set(sr.EncodeUint(positionId2), deposit2)

	positionsPage1 := state.instance.GetStakedPositionsByUser(state.owner, 0, 1)
	positionsPage2 := state.instance.GetStakedPositionsByUser(state.owner, 1, 1)
	uassert.Equal(t, 1, len(positionsPage1))
	uassert.Equal(t, 1, len(positionsPage2))
	uassert.Equal(t, state.positionId, positionsPage1[0])
	uassert.Equal(t, positionId2, positionsPage2[0])

	// Verify both positions can be queried
	owner1 := state.instance.GetDepositOwner(state.positionId)
	owner2 := state.instance.GetDepositOwner(positionId2)
	uassert.Equal(t, state.owner, owner1)
	uassert.Equal(t, state.owner, owner2)
}

func TestGetterIncentiveActiveStatus(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	poolPath := "gno.land/r/test/pool:3000"
	fixedTime := int64(1000)

	// Create pool
	pool := sr.NewPool(poolPath, fixedTime)
	instance.store.GetPools().Set(poolPath, pool)

	tests := []struct {
		name           string
		incentiveId    string
		startTimestamp int64
		endTimestamp   int64
		refunded       bool
	}{
		{
			name:           "future incentive (not yet started)",
			incentiveId:    "future-incentive",
			startTimestamp: fixedTime + 1000,
			endTimestamp:   fixedTime + 2000,
			refunded:       false,
		},
		{
			name:           "past incentive (already ended)",
			incentiveId:    "past-incentive",
			startTimestamp: fixedTime - 2000,
			endTimestamp:   fixedTime - 1000,
			refunded:       false,
		},
		{
			name:           "refunded incentive",
			incentiveId:    "refunded-incentive",
			startTimestamp: fixedTime - 100,
			endTimestamp:   fixedTime + 100,
			refunded:       true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			incentive := sr.NewExternalIncentive(
				tt.incentiveId,
				poolPath,
				barPath,
				1_000_000,
				tt.startTimestamp,
				tt.endTimestamp,
				addr01,
				100_000,
				100,
				fixedTime,
				false,
			)
			if tt.refunded {
				incentive.SetRefunded(true)
			}
			pool.Incentives().SetIncentive(tt.incentiveId, incentive)

			// IsIncentiveActive uses time.Now(), so we just verify it doesn't panic
			_ = instance.IsIncentiveActive(poolPath, tt.incentiveId)
		})
	}
}
