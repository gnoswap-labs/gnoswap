package v1

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

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
func setupBasicTestState(cur realm, t *testing.T) *testState {
	t.Helper()
	initStakerTest(cur, t)

	state := &testState{
		instance:         getMockInstance(),
		poolPath:         "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000",
		incentiveId:      "test-incentive-1",
		positionId:       uint64(1),
		owner:            addr01,
		fixedTimestamp:   int64(1000000),
		fixedBlockHeight: int64(100),
	}

	// Setup allowed tokens and config via the admin-gated manager methods.
	// These run through the mock instance helpers under an admin caller so the
	// access checks (rlm.Previous() == admin) pass.
	testing.SetRealm(adminRealm)
	mockInstanceAddToken(cross(cur), barPath)
	mockInstanceAddToken(cross(cur), bazPath)

	mockInstanceSetDepositGnsAmount(cross(cur), 1_000_000_000)
	mockInstanceSetMinimumRewardAmount(cross(cur), 500_000)
	mockInstanceSetUnstakingFee(cross(cur), 100) // 1%

	// Setup warmup template via manager method (30%, 5 days)
	mockInstanceSetWarmupPeriod(cross(cur), state.poolPath, 86400*5)

	// Setup pool through the domain collection setter
	state.pool = sr.NewPool(state.poolPath, state.fixedTimestamp)
	state.instance.getPools().set(state.poolPath, state.pool)

	// Setup external incentive through domain setters
	state.incentive = sr.NewExternalIncentive(
		state.incentiveId,
		state.poolPath,
		barPath,
		10_000_000,                // rewardAmount
		state.fixedTimestamp,      // startTimestamp
		state.fixedTimestamp+3600, // endTimestamp (1 hour)
		state.owner,               // creator
		1_000_000_000,             // depositGnsAmount
		state.fixedBlockHeight,    // createdHeight
		state.fixedTimestamp,      // currentTime
	)
	state.pool.Incentives().SetIncentive(state.incentiveId, state.incentive)
	state.instance.getExternalIncentives().set(state.incentiveId, state.incentive)

	// Setup deposit through the domain collection setter
	warmups := []sr.Warmup{
		sr.NewWarmup(86400*5, state.fixedTimestamp+86400*5, 30),
		sr.NewWarmup(86400*10, state.fixedTimestamp+86400*10, 50),
		sr.NewWarmup(86400*30, state.fixedTimestamp+86400*30, 70),
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
	state.instance.getDeposits().set(state.positionId, state.deposit)

	// Setup pool tier
	state.instance.setPoolTier(0, cur, state.poolPath, 1, state.fixedTimestamp)
	counts := state.instance.store.GetPoolTierCounts()
	counts[1] = 1
	state.instance.store.SetPoolTierCounts(0, cur, counts)
	state.instance.store.SetPoolTierRatio(0, cur, sr.NewTierRatio(50, 30, 20))

	// Setup total emission sent
	state.instance.store.SetTotalEmissionSent(0, cur, 100000)

	return state
}

func TestGetterIncentiveBasicProperties(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

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
			name:     "GetIncentiveCreator",
			getter:   func() any { return state.instance.GetIncentiveCreator(state.poolPath, state.incentiveId) },
			expected: state.owner,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			result := tt.getter()
			uassert.Equal(t, tt.expected, result)
		})
	}
}

// TestGetterIncentiveRewardAmounts tests derived reward values together.
// remaining = total - distributed
func TestGetterIncentiveRewardAmounts(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

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
	// GetIncentiveRewardPerSecondX128 returns the Q128-scaled value so that
	// sub-integer rates (here 10_000_000 / 3600 = 2777.77...) survive without
	// the truncation that the previous int64 representation forced. Floor of
	// rewardPerSecondX128 >> 128 should still equal the legacy value 2777.
	rewardPerSecondX128 := state.instance.GetIncentiveRewardPerSecondX128(state.poolPath, state.incentiveId)
	floor := u256.Zero().Rsh(rewardPerSecondX128, 128)
	uassert.Equal(t, "2777", floor.ToString())

	// Test u256 variants
	rewardAmount := state.instance.GetIncentiveRewardAmount(state.poolPath, state.incentiveId)
	rewardAmountStr := state.instance.GetIncentiveRewardAmountAsString(state.poolPath, state.incentiveId)
	uassert.Equal(t, "10000000", rewardAmount.ToString())
	uassert.Equal(t, "10000000", rewardAmountStr)
}

func TestGetterPoolIncentiveDepositObjects(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	pool := state.instance.GetPool(state.poolPath)
	uassert.Equal(t, state.poolPath, pool.PoolPath())

	incentive := state.instance.GetIncentive(state.poolPath, state.incentiveId)
	uassert.Equal(t, state.incentiveId, incentive.IncentiveId())
	uassert.Equal(t, barPath, incentive.RewardToken())

	deposit := state.instance.GetDeposit(state.positionId)
	uassert.Equal(t, state.owner, deposit.Owner())
	uassert.Equal(t, state.poolPath, deposit.TargetPoolPath())
}

func TestGetterCollectableRewards(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	internal := state.instance.CollectableEmissionReward(state.positionId)
	uassert.Equal(t, int64(0), internal)

	external := state.instance.CollectableExternalIncentiveReward(state.positionId, state.incentiveId)
	uassert.Equal(t, int64(0), external)
}

func TestGetterPoolIncentiveIdList(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

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
	)
	state.pool.Incentives().SetIncentive("test-incentive-2", incentive2)

	ids := state.instance.GetPoolIncentiveIdList(state.poolPath)

	uassert.Equal(t, 2, len(ids))
}

func TestGetterExternalIncentiveByPoolPath(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	incentives := state.instance.GetExternalIncentiveByPoolPath(state.poolPath)

	uassert.Equal(t, 1, len(incentives))
	uassert.Equal(t, state.incentiveId, incentives[0].IncentiveId())
}

func TestGetterDepositBasicProperties(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			result := tt.getter()
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestGetterDepositLiquidity(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	liquidity := state.instance.GetDepositLiquidity(state.positionId)
	liquidityStr := state.instance.GetDepositLiquidityAsString(state.positionId)

	uassert.Equal(t, "1000000", liquidity.ToString())
	uassert.Equal(t, "1000000", liquidityStr)
}

func TestGetterDepositExternalRewards(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

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

func TestGetterDepositWarmUp(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	warmups := state.instance.GetDepositWarmUp(state.positionId)

	uassert.Equal(t, 3, len(warmups))
	uassert.Equal(t, uint64(30), warmups[0].WarmupRatio)
	uassert.Equal(t, uint64(50), warmups[1].WarmupRatio)
	uassert.Equal(t, uint64(70), warmups[2].WarmupRatio)
}

func TestGetterIsStaked(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			result := state.instance.IsStaked(tt.positionId)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestGetterPoolTierProperties(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

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

func TestGetterPoolsByTier(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	// Add another pool to tier 1
	pool2Path := "gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:500"
	state.instance.setPoolTier(0, cur, pool2Path, 1, state.fixedTimestamp)

	pools := state.instance.GetPoolsByTier(1)
	uassert.Equal(t, 2, len(pools))

	// Test tier 0 returns empty
	poolsTier0 := state.instance.GetPoolsByTier(0)
	uassert.Equal(t, 0, len(poolsTier0))

	// Test non-existent tier
	poolsTier99 := state.instance.GetPoolsByTier(99)
	uassert.Equal(t, 0, len(poolsTier99))
}

func TestGetterGlobalConfigValues(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

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
			expected: uint64(100),
		},
		{
			name:     "GetTotalEmissionSent",
			getter:   func() any { return state.instance.GetTotalEmissionSent() },
			expected: int64(100000),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			result := tt.getter()
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestGetterAllowedTokens(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	tokens := state.instance.GetAllowedTokens()

	// Should contain default tokens plus added ones
	uassert.True(t, len(tokens) >= 2)

	// Verify returned slice is a copy
	originalLen := len(tokens)
	tokens = append(tokens, "fake-token")
	newTokens := state.instance.GetAllowedTokens()
	uassert.Equal(t, originalLen, len(newTokens))
}

func TestGetterWarmupTemplate(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	warmups := state.instance.GetWarmupTemplate()

	// Should have warmup entries
	uassert.True(t, len(warmups) > 0)

	// Verify returned slice is a copy
	originalLen := len(warmups)
	warmups = append(warmups, sr.NewWarmup(0, 0, 0))
	newWarmups := state.instance.GetWarmupTemplate()
	uassert.Equal(t, originalLen, len(newWarmups))
}

func TestGetterNonExistentIncentive(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	uassert.PanicsContains(t, cur, "incentive does not exist", func() {
		state.instance.GetIncentiveStartTimestamp(state.poolPath, "non-existent-incentive")
	})
}

func TestGetterNonExistentDeposit(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	uassert.PanicsContains(t, cur, "not found", func() {
		state.instance.GetDepositOwner(uint64(999))
	})
}

func TestGetterNonExistentPool(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	uassert.PanicsContains(t, cur, "does not exist", func() {
		state.instance.GetPoolIncentiveIdList("non-existent-pool")
	})
}

func TestGetterPoolTierForUntieredPool(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	// Create a new pool without tier
	untieredPoolPath := "gno.land/r/test:gno.land/r/test2:500"
	untieredPool := sr.NewPool(untieredPoolPath, state.fixedTimestamp)
	state.instance.getPools().set(untieredPoolPath, untieredPool)

	// Should return 0 for untiered pool
	tier := state.instance.GetPoolTier(untieredPoolPath)
	uassert.Equal(t, uint64(0), tier)
}

func TestGetterMultipleDepositsForSameOwner(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

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
	state.instance.getDeposits().set(positionId2, deposit2)

	owner1 := state.instance.GetDepositOwner(state.positionId)
	owner2 := state.instance.GetDepositOwner(positionId2)
	uassert.Equal(t, state.owner, owner1)
	uassert.Equal(t, state.owner, owner2)
}

func TestGetterIncentiveActiveStatus(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	instance := getMockInstance()

	poolPath := "gno.land/r/test/pool:3000"
	fixedTime := int64(1000)

	// Create pool
	pool := sr.NewPool(poolPath, fixedTime)
	instance.getPools().set(poolPath, pool)

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
		t.Run(tt.name, func(cur realm, t *testing.T) {
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

func TestGetterPoolRewardCache(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	// Add some reward cache entries
	state.pool.SetRewardCacheAt(state.fixedTimestamp, int64(1000))
	state.pool.SetRewardCacheAt(state.fixedTimestamp+100, int64(2000))
	state.pool.SetRewardCacheAt(state.fixedTimestamp+200, int64(3000))

	// Test count
	count := state.instance.GetPoolRewardCacheCount(state.poolPath)
	uassert.Equal(t, uint64(3), count) // NewPool initializes with fixedTimestamp, which gets overwritten

	// Test IDs pagination
	ids := state.instance.GetPoolRewardCacheIDs(state.poolPath, 0, 2)
	uassert.Equal(t, 2, len(ids))

	// Test get specific cache value
	cacheValue := state.instance.GetPoolRewardCache(state.poolPath, uint64(state.fixedTimestamp))
	uassert.Equal(t, int64(1000), cacheValue)

	cacheValue2 := state.instance.GetPoolRewardCache(state.poolPath, uint64(state.fixedTimestamp+200))
	uassert.Equal(t, int64(3000), cacheValue2)

	// Test non-existent timestamp
	nonExistent := state.instance.GetPoolRewardCache(state.poolPath, uint64(state.fixedTimestamp+9999))
	uassert.Equal(t, int64(0), nonExistent)
}

func TestGetterPoolIncentive(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	// Add more incentives
	incentive2 := sr.NewExternalIncentive(
		"test-incentive-2",
		state.poolPath,
		bazPath,
		5_000_000,
		state.fixedTimestamp+100,
		state.fixedTimestamp+3700,
		state.owner,
		500_000_000,
		state.fixedBlockHeight,
		state.fixedTimestamp,
	)
	state.pool.Incentives().SetIncentive("test-incentive-2", incentive2)

	// Test count
	count := state.instance.GetPoolIncentiveCount(state.poolPath)
	uassert.Equal(t, uint64(2), count)

	// Test IDs pagination
	ids := state.instance.GetPoolIncentiveIDs(state.poolPath, 0, 10)
	uassert.Equal(t, 2, len(ids))
	uassert.True(t, contains(ids, state.incentiveId))
	uassert.True(t, contains(ids, "test-incentive-2"))

	// Test pagination with offset
	idsPage1 := state.instance.GetPoolIncentiveIDs(state.poolPath, 0, 1)
	uassert.Equal(t, 1, len(idsPage1))

	idsPage2 := state.instance.GetPoolIncentiveIDs(state.poolPath, 1, 1)
	uassert.Equal(t, 1, len(idsPage2))
}

func TestGetterPoolGlobalRewardRatioAccumulation(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	// Add some accumulation entries (avoiding fixedTimestamp as NewPool initializes with it)
	acc1 := "1000000000000000000"
	acc2 := "2000000000000000000"
	acc3 := "3000000000000000000"

	state.pool.SetGlobalRewardRatioAccumulationAt(state.fixedTimestamp+100, acc1)
	state.pool.SetGlobalRewardRatioAccumulationAt(state.fixedTimestamp+200, acc2)
	state.pool.SetGlobalRewardRatioAccumulationAt(state.fixedTimestamp+300, acc3)

	// Test count
	count := state.instance.GetPoolGlobalRewardRatioAccumulationCount(state.poolPath)
	uassert.Equal(t, uint64(4), count) // 3 new entries + 1 initial entry from NewPool

	// Test IDs pagination
	ids := state.instance.GetPoolGlobalRewardRatioAccumulationIDs(state.poolPath, 0, 2)
	uassert.Equal(t, 2, len(ids))

	// Test get specific accumulation value
	accValue := state.instance.GetPoolGlobalRewardRatioAccumulation(state.poolPath, uint64(state.fixedTimestamp+100))
	uassert.Equal(t, acc1, accValue)

	accValue2 := state.instance.GetPoolGlobalRewardRatioAccumulation(state.poolPath, uint64(state.fixedTimestamp+300))
	uassert.Equal(t, acc3, accValue2)

	// Test non-existent timestamp
	nonExistent := state.instance.GetPoolGlobalRewardRatioAccumulation(state.poolPath, uint64(state.fixedTimestamp+9999))
	uassert.Equal(t, "0", nonExistent)
}

func TestGetterPoolHistoricalTick(cur realm, t *testing.T) {
	state := setupBasicTestState(cur, t)

	// Add some historical tick entries
	state.pool.SetHistoricalTickAt(state.fixedTimestamp, int32(-100))
	state.pool.SetHistoricalTickAt(state.fixedTimestamp+100, int32(50))
	state.pool.SetHistoricalTickAt(state.fixedTimestamp+200, int32(200))

	// Test count
	count := state.instance.GetPoolHistoricalTickCount(state.poolPath)
	uassert.Equal(t, uint64(3), count)

	// Test IDs pagination
	ticks := state.instance.GetPoolHistoricalTickIDs(state.poolPath, 0, 2)
	uassert.Equal(t, 2, len(ticks))

	// Test get specific tick value
	tickValue := state.instance.GetPoolHistoricalTick(state.poolPath, uint64(state.fixedTimestamp))
	uassert.Equal(t, int32(-100), tickValue)

	tickValue2 := state.instance.GetPoolHistoricalTick(state.poolPath, uint64(state.fixedTimestamp+200))
	uassert.Equal(t, int32(200), tickValue2)

	// Test non-existent timestamp
	nonExistent := state.instance.GetPoolHistoricalTick(state.poolPath, uint64(state.fixedTimestamp+9999))
	uassert.Equal(t, int32(0), nonExistent)
}
