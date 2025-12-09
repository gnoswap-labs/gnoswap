package v1

import (
	"chain/runtime"
	"math"
	"strconv"
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	sr "gno.land/r/gnoswap/staker"
)

// Test getInitialCollectTime

func TestGetInitialCollectTime(t *testing.T) {
	tests := []struct {
		name                    string
		depositStakeTime        int64
		incentiveStartTimestamp int64
		expected                int64
	}{
		{
			name:                    "deposit staked before incentive starts",
			depositStakeTime:        1000,
			incentiveStartTimestamp: 2000,
			expected:                2000,
		},
		{
			name:                    "deposit staked after incentive starts",
			depositStakeTime:        3000,
			incentiveStartTimestamp: 2000,
			expected:                3000,
		},
		{
			name:                    "deposit and incentive start at same time",
			depositStakeTime:        2000,
			incentiveStartTimestamp: 2000,
			expected:                2000,
		},
		{
			name:                    "deposit staked much earlier",
			depositStakeTime:        100,
			incentiveStartTimestamp: 10000,
			expected:                10000,
		},
		{
			name:                    "incentive started much earlier",
			depositStakeTime:        10000,
			incentiveStartTimestamp: 100,
			expected:                10000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			deposit := &sr.Deposit{}
			deposit.SetStakeTime(tt.depositStakeTime)

			incentive := &sr.ExternalIncentive{}
			incentive.SetStartTimestamp(tt.incentiveStartTimestamp)

			result := getInitialCollectTime(deposit, incentive)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

// Test Reward struct initialization

func TestRewardStructInitialization(t *testing.T) {
	tests := []struct {
		name            string
		internal        int64
		internalPenalty int64
		external        map[string]int64
		externalPenalty map[string]int64
	}{
		{
			name:            "all fields set",
			internal:        1000,
			internalPenalty: 100,
			external:        map[string]int64{"incentive1": 500},
			externalPenalty: map[string]int64{"incentive1": 50},
		},
		{
			name:            "zero values",
			internal:        0,
			internalPenalty: 0,
			external:        map[string]int64{},
			externalPenalty: map[string]int64{},
		},
		{
			name:            "large values",
			internal:        9999999999,
			internalPenalty: 1111111111,
			external:        map[string]int64{"incentive1": 8888888888},
			externalPenalty: map[string]int64{"incentive1": 2222222222},
		},
		{
			name:            "multiple external incentives",
			internal:        5000,
			internalPenalty: 500,
			external:        map[string]int64{"inc1": 1000, "inc2": 2000, "inc3": 3000},
			externalPenalty: map[string]int64{"inc1": 100, "inc2": 200, "inc3": 300},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			reward := Reward{
				Internal:        tt.internal,
				InternalPenalty: tt.internalPenalty,
				External:        tt.external,
				ExternalPenalty: tt.externalPenalty,
			}

			uassert.Equal(t, tt.internal, reward.Internal)
			uassert.Equal(t, tt.internalPenalty, reward.InternalPenalty)
			uassert.NotNil(t, reward.External)
			uassert.NotNil(t, reward.ExternalPenalty)

			for key, expectedValue := range tt.external {
				actualValue, exists := reward.External[key]
				uassert.True(t, exists)
				uassert.Equal(t, expectedValue, actualValue)
			}

			for key, expectedValue := range tt.externalPenalty {
				actualValue, exists := reward.ExternalPenalty[key]
				uassert.True(t, exists)
				uassert.Equal(t, expectedValue, actualValue)
			}
		})
	}
}

// Test CalcPositionRewardParam struct

func TestCalcPositionRewardParamStructure(t *testing.T) {
	currentTime := time.Now().Unix()
	currentHeight := int64(1000)
	positionId := uint64(123)

	param := &CalcPositionRewardParam{
		CurrentHeight: currentHeight,
		CurrentTime:   currentTime,
		Deposits:      nil,
		Pools:         nil,
		PoolTier:      nil,
		PositionId:    positionId,
	}

	uassert.Equal(t, currentHeight, param.CurrentHeight)
	uassert.Equal(t, currentTime, param.CurrentTime)
	uassert.Equal(t, positionId, param.PositionId)
}

// Edge case tests

func TestGetInitialCollectTime_BoundaryValues(t *testing.T) {
	tests := []struct {
		name                    string
		depositStakeTime        int64
		incentiveStartTimestamp int64
		expected                int64
	}{
		{
			name:                    "both zero",
			depositStakeTime:        0,
			incentiveStartTimestamp: 0,
			expected:                0,
		},
		{
			name:                    "deposit zero, incentive positive",
			depositStakeTime:        0,
			incentiveStartTimestamp: 1000,
			expected:                1000,
		},
		{
			name:                    "deposit positive, incentive zero",
			depositStakeTime:        1000,
			incentiveStartTimestamp: 0,
			expected:                1000,
		},
		{
			name:                    "very large values",
			depositStakeTime:        9223372036854775807, // max int64
			incentiveStartTimestamp: 1000,
			expected:                9223372036854775807,
		},
		{
			name:                    "deposit by 1 second",
			depositStakeTime:        1001,
			incentiveStartTimestamp: 1000,
			expected:                1001,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			deposit := &sr.Deposit{}
			deposit.SetStakeTime(tt.depositStakeTime)

			incentive := &sr.ExternalIncentive{}
			incentive.SetStartTimestamp(tt.incentiveStartTimestamp)

			result := getInitialCollectTime(deposit, incentive)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestReward_NilMaps(t *testing.T) {
	reward := Reward{
		Internal:        1000,
		InternalPenalty: 100,
		External:        nil,
		ExternalPenalty: nil,
	}

	uassert.Equal(t, int64(1000), reward.Internal)
	uassert.Equal(t, int64(100), reward.InternalPenalty)
}

func TestReward_EmptyMaps(t *testing.T) {
	reward := Reward{
		Internal:        500,
		InternalPenalty: 50,
		External:        make(map[string]int64),
		ExternalPenalty: make(map[string]int64),
	}

	uassert.Equal(t, int64(500), reward.Internal)
	uassert.Equal(t, int64(50), reward.InternalPenalty)
	uassert.Equal(t, 0, len(reward.External))
	uassert.Equal(t, 0, len(reward.ExternalPenalty))
}

func TestReward_SingleIncentive(t *testing.T) {
	incentiveId := "test-incentive-1"
	rewardAmount := int64(1000000)
	penaltyAmount := int64(50000)

	reward := Reward{
		Internal:        5000000,
		InternalPenalty: 100000,
		External:        map[string]int64{incentiveId: rewardAmount},
		ExternalPenalty: map[string]int64{incentiveId: penaltyAmount},
	}

	// Verify external reward
	externalReward, exists := reward.External[incentiveId]
	uassert.True(t, exists)
	uassert.Equal(t, rewardAmount, externalReward)

	// Verify external penalty
	externalPenalty, exists := reward.ExternalPenalty[incentiveId]
	uassert.True(t, exists)
	uassert.Equal(t, penaltyAmount, externalPenalty)
}

func TestReward_MultipleIncentives(t *testing.T) {
	reward := Reward{
		Internal:        1000000,
		InternalPenalty: 50000,
		External: map[string]int64{
			"incentive1": 100000,
			"incentive2": 200000,
			"incentive3": 300000,
		},
		ExternalPenalty: map[string]int64{
			"incentive1": 10000,
			"incentive2": 20000,
			"incentive3": 30000,
		},
	}

	// Verify total external rewards
	totalExternal := int64(0)
	for _, amount := range reward.External {
		totalExternal += amount
	}
	uassert.Equal(t, int64(600000), totalExternal)

	// Verify total external penalties
	totalPenalty := int64(0)
	for _, amount := range reward.ExternalPenalty {
		totalPenalty += amount
	}
	uassert.Equal(t, int64(60000), totalPenalty)
}

func TestGetInitialCollectTime_RealisticScenarios(t *testing.T) {
	// Scenario 1: Position staked Jan 1, incentive starts Jan 15
	jan1 := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC).Unix()
	jan15 := time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC).Unix()

	deposit1 := &sr.Deposit{}
	deposit1.SetStakeTime(jan1)
	incentive1 := &sr.ExternalIncentive{}
	incentive1.SetStartTimestamp(jan15)

	result1 := getInitialCollectTime(deposit1, incentive1)
	uassert.Equal(t, jan15, result1)

	// Scenario 2: Incentive started Jan 1, position staked Jan 15
	deposit2 := &sr.Deposit{}
	deposit2.SetStakeTime(jan15)
	incentive2 := &sr.ExternalIncentive{}
	incentive2.SetStartTimestamp(jan1)

	result2 := getInitialCollectTime(deposit2, incentive2)
	uassert.Equal(t, jan15, result2)

	// Scenario 3: Both start at the same time
	deposit3 := &sr.Deposit{}
	deposit3.SetStakeTime(jan1)
	incentive3 := &sr.ExternalIncentive{}
	incentive3.SetStartTimestamp(jan1)

	result3 := getInitialCollectTime(deposit3, incentive3)
	uassert.Equal(t, jan1, result3)
}

func TestCalcPositionRewardParam_AllFields(t *testing.T) {
	currentTime := time.Now().Unix()
	currentHeight := int64(5000)
	positionId := uint64(999)

	// Create mock instances
	deposits := NewDeposits()
	pools := NewPools()

	param := &CalcPositionRewardParam{
		CurrentHeight: currentHeight,
		CurrentTime:   currentTime,
		Deposits:      deposits,
		Pools:         pools,
		PoolTier:      nil, // Use nil for simplicity in test
		PositionId:    positionId,
	}

	// Verify all fields are set correctly
	uassert.Equal(t, currentHeight, param.CurrentHeight)
	uassert.Equal(t, currentTime, param.CurrentTime)
	uassert.NotNil(t, param.Deposits)
	uassert.NotNil(t, param.Pools)
	uassert.Equal(t, positionId, param.PositionId)
}

func TestReward_ZeroInternalWithExternalRewards(t *testing.T) {
	reward := Reward{
		Internal:        0,
		InternalPenalty: 0,
		External:        map[string]int64{"incentive1": 500000},
		ExternalPenalty: map[string]int64{"incentive1": 25000},
	}

	uassert.Equal(t, int64(0), reward.Internal)
	uassert.Equal(t, int64(0), reward.InternalPenalty)

	externalReward, exists := reward.External["incentive1"]
	uassert.True(t, exists)
	uassert.Equal(t, int64(500000), externalReward)
}

func TestReward_InternalOnlyNoExternal(t *testing.T) {
	reward := Reward{
		Internal:        1000000,
		InternalPenalty: 50000,
		External:        map[string]int64{},
		ExternalPenalty: map[string]int64{},
	}

	uassert.Equal(t, int64(1000000), reward.Internal)
	uassert.Equal(t, int64(50000), reward.InternalPenalty)
	uassert.Equal(t, 0, len(reward.External))
	uassert.Equal(t, 0, len(reward.ExternalPenalty))
}

func TestCalcPositionReward_ExternalPenaltyOnly(t *testing.T) {
	canonical := Setup(t)

	// Make the first warmup emit 0% reward so only penalties accumulate
	originalWarmups := append([]sr.Warmup(nil), getMockInstance().store.GetWarmupTemplate()...)
	modifiedWarmups := append([]sr.Warmup(nil), originalWarmups...)
	modifiedWarmups[0].WarmupRatio = 0
	getMockInstance().store.SetWarmupTemplate(modifiedWarmups)
	defer getMockInstance().store.SetWarmupTemplate(originalWarmups)

	poolPath := "gno.land/r/gnoswap/pool/external-penalty-only-2"
	canonical.CreatePool(poolPath, 1, 0)

	startTs := time.Now().Unix() - 5
	endTs := startTs + 100
	rewardAmount := int64(1_000)

	incentiveId := canonical.CreateExternalIncentive(
		poolPath,
		gnsPath,
		rewardAmount,
		startTs,
		endTs,
		addr01,
		runtime.ChainHeight(),
	)

	positionId := uint64(888)
	owner := testutils.TestAddress("extPenaltyOwner")
	liquidity := u256.NewUint(1)

	err := canonical.StakeToken(positionId, poolPath, owner, -10, 10, liquidity)
	if err != nil {
		t.Fatalf("failed to stake token: %v", err)
	}

	currentTimestamp := time.Now().Unix() + 1
	currentHeight := runtime.ChainHeight() + 1

	reward := getMockInstance().calcPositionReward(currentHeight, currentTimestamp, positionId)

	_, hasExternalReward := reward.External[incentiveId]
	uassert.False(t, hasExternalReward)

	penalty, hasPenalty := reward.ExternalPenalty[incentiveId]
	uassert.True(t, hasPenalty)
	uassert.True(t, penalty > 0)
}

// TestCalcPositionReward tests the calcPositionReward function
// using a table-driven approach to verify various edge cases for internal and external rewards.
func TestCalcPositionReward(t *testing.T) {
	baseTime := time.Now().Unix()
	baseHeight := int64(100)

	tests := []struct {
		name string
		// Setup configuration
		setupFunc func(t *testing.T, s *stakerV1, baseTime int64) (positionId uint64, poolPath string)
		// Input parameters
		currentHeight    int64
		currentTimestamp int64
		// Expected results
		expectInternalReward   bool
		expectInternalPenalty  bool
		expectExternalReward   bool
		expectExternalPenalty  bool
		minInternalReward      int64
		maxInternalReward      int64
		minInternalPenalty     int64
		minExternalRewardCount int
		validateFunc           func(t *testing.T, reward Reward)
	}{
		{
			name: "no_rewards_when_pool_has_no_tier",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/no_tier_pool"
				positionId := uint64(1001)

				// Create pool without tier (tier 0)
				pool := sr.NewPool(poolPath, baseTime)
				s.getPools().set(poolPath, pool)

				// Create deposit
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner1"),
					poolPath,
					u256.NewUint(1000000),
					baseTime,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Initialize pool state
				poolResolver := NewPoolResolver(pool)
				poolResolver.GlobalRewardRatioAccumulation().Set(baseTime, u256.Zero())
				poolResolver.HistoricalTick().Set(baseTime, int32(0))
				poolResolver.StakedLiquidity().Set(baseTime, u256.NewUint(1000000))

				return positionId, poolPath
			},
			currentHeight:         baseHeight + 10,
			currentTimestamp:      baseTime + 100,
			expectInternalReward:  false,
			expectInternalPenalty: false,
			expectExternalReward:  false,
			expectExternalPenalty: false,
			minInternalReward:     0,
			maxInternalReward:     0,
		},
		{
			name: "internal_reward_with_30_percent_warmup",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/tier1_warmup30"
				positionId := uint64(1002)

				// Create pool with tier 1
				pool := sr.NewPool(poolPath, baseTime)
				s.getPools().set(poolPath, pool)

				// Create deposit with 30% warmup (first warmup period)
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner2"),
					poolPath,
					u256.NewUint(1000000),
					baseTime,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Setup pool tier
				poolTier := s.getPoolTier()
				poolTier.changeTier(baseHeight, baseTime, s.getPools(), poolPath, 1)

				// Initialize pool state
				poolResolver := NewPoolResolver(pool)
				poolResolver.GlobalRewardRatioAccumulation().Set(baseTime, u256.Zero())
				poolResolver.HistoricalTick().Set(baseTime, int32(0))
				poolResolver.StakedLiquidity().Set(baseTime, u256.NewUint(1000000))
				poolResolver.RewardCache().Set(baseTime, int64(1000000)) // 1M reward per second

				return positionId, poolPath
			},
			currentHeight:         baseHeight + 10,
			currentTimestamp:      baseTime + 10, // Within first warmup period (5 days)
			expectInternalReward:  true,
			expectInternalPenalty: true,
			expectExternalReward:  false,
			expectExternalPenalty: false,
			minInternalReward:     1, // Should have some reward
			maxInternalReward:     math.MaxInt64,
			validateFunc: func(t *testing.T, reward Reward) {
				// With 30% warmup, penalty should be 70% of total
				totalReward := reward.Internal + reward.InternalPenalty
				if totalReward > 0 {
					expectedPenaltyRatio := float64(reward.InternalPenalty) / float64(totalReward)
					// Allow some margin for rounding
					uassert.True(t, expectedPenaltyRatio >= 0.65 && expectedPenaltyRatio <= 0.75,
						"penalty ratio should be around 70%")
				}
			},
		},
		{
			name: "internal_reward_with_100_percent_warmup",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/tier1_warmup100"
				positionId := uint64(1003)

				// Create pool with tier 1
				pool := sr.NewPool(poolPath, baseTime-86400*31) // Started 31 days ago
				s.getPools().set(poolPath, pool)

				// Create deposit that started 31 days ago (past all warmup periods)
				stakeTime := baseTime - 86400*31
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), stakeTime)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner3"),
					poolPath,
					u256.NewUint(1000000),
					stakeTime,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Setup pool tier
				poolTier := s.getPoolTier()
				poolTier.changeTier(baseHeight, stakeTime, s.getPools(), poolPath, 1)

				// Initialize pool state
				poolResolver := NewPoolResolver(pool)
				poolResolver.GlobalRewardRatioAccumulation().Set(stakeTime, u256.Zero())
				poolResolver.HistoricalTick().Set(stakeTime, int32(0))
				poolResolver.StakedLiquidity().Set(stakeTime, u256.NewUint(1000000))
				poolResolver.RewardCache().Set(stakeTime, int64(1000000))

				return positionId, poolPath
			},
			currentHeight:         baseHeight + 10,
			currentTimestamp:      baseTime,
			expectInternalReward:  true,
			expectInternalPenalty: true, // Penalties from earlier warmup periods are accumulated
			expectExternalReward:  false,
			expectExternalPenalty: false,
			minInternalReward:     1,
			maxInternalReward:     math.MaxInt64,
			validateFunc: func(t *testing.T, reward Reward) {
				// With 31 days of staking, the position has gone through all warmup periods
				// Rewards from earlier periods (30%, 50%, 70%) still have their respective penalties
				// Only rewards earned after 30 days have 100% ratio (no penalty)
				totalReward := reward.Internal + reward.InternalPenalty
				uassert.True(t, totalReward > 0, "should have total reward")
				uassert.True(t, reward.Internal > 0, "should have internal reward")
			},
		},
		{
			name: "external_reward_single_incentive",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/external_single"
				positionId := uint64(1004)

				// Create pool
				pool := sr.NewPool(poolPath, baseTime-100)
				s.getPools().set(poolPath, pool)

				// Create external incentive
				incentiveStartTime := baseTime - 50
				incentiveEndTime := baseTime + 1000
				rewardAmount := int64(10000)
				incentiveId := "test-incentive-1"

				incentive := sr.NewExternalIncentive(
					incentiveId,
					poolPath,
					gnsPath,
					rewardAmount,
					incentiveStartTime,
					incentiveEndTime,
					testutils.TestAddress("refundee"),
					0,
					baseHeight,
					baseTime-100,
					false,
				)
				incentive.SetRewardPerSecond(rewardAmount / (incentiveEndTime - incentiveStartTime))

				poolResolver := NewPoolResolver(pool)
				poolResolver.IncentivesResolver().create(testutils.TestAddress("refundee"), incentive)

				// Create deposit
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime-50)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner4"),
					poolPath,
					u256.NewUint(1000000),
					baseTime-50,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Initialize pool state
				poolResolver.GlobalRewardRatioAccumulation().Set(baseTime-100, u256.Zero())
				poolResolver.HistoricalTick().Set(baseTime-100, int32(0))
				poolResolver.StakedLiquidity().Set(baseTime-100, u256.NewUint(1000000))

				return positionId, poolPath
			},
			currentHeight:          baseHeight + 10,
			currentTimestamp:       baseTime + 10,
			expectInternalReward:   false,
			expectInternalPenalty:  false,
			expectExternalReward:   true,
			expectExternalPenalty:  true,
			minExternalRewardCount: 1,
			validateFunc: func(t *testing.T, reward Reward) {
				uassert.True(t, len(reward.External) >= 1, "should have at least one external reward")
			},
		},
		{
			name: "external_reward_multiple_incentives",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/external_multi"
				positionId := uint64(1005)

				// Create pool
				pool := sr.NewPool(poolPath, baseTime-100)
				s.getPools().set(poolPath, pool)

				poolResolver := NewPoolResolver(pool)

				// Create multiple external incentives
				for i := 0; i < 3; i++ {
					incentiveStartTime := baseTime - 50
					incentiveEndTime := baseTime + 1000
					rewardAmount := int64((i + 1) * 1000)
					incentiveId := "test-incentive-multi-" + strconv.Itoa(i)

					incentive := sr.NewExternalIncentive(
						incentiveId,
						poolPath,
						gnsPath,
						rewardAmount,
						incentiveStartTime,
						incentiveEndTime,
						testutils.TestAddress("refundee"),
						0,
						baseHeight,
						baseTime-100,
						false,
					)
					incentive.SetRewardPerSecond(rewardAmount / (incentiveEndTime - incentiveStartTime))
					poolResolver.IncentivesResolver().create(testutils.TestAddress("refundee"), incentive)
				}

				// Create deposit
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime-50)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner5"),
					poolPath,
					u256.NewUint(1000000),
					baseTime-50,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Initialize pool state
				poolResolver.GlobalRewardRatioAccumulation().Set(baseTime-100, u256.Zero())
				poolResolver.HistoricalTick().Set(baseTime-100, int32(0))
				poolResolver.StakedLiquidity().Set(baseTime-100, u256.NewUint(1000000))

				return positionId, poolPath
			},
			currentHeight:          baseHeight + 10,
			currentTimestamp:       baseTime + 10,
			expectInternalReward:   false,
			expectInternalPenalty:  false,
			expectExternalReward:   true,
			expectExternalPenalty:  true,
			minExternalRewardCount: 1, // At least one incentive should have rewards
			validateFunc: func(t *testing.T, reward Reward) {
				// External rewards may be aggregated or split by incentive
				hasExternalReward := false
				for _, v := range reward.External {
					if v > 0 {
						hasExternalReward = true
						break
					}
				}
				uassert.True(t, hasExternalReward, "should have external rewards")
			},
		},
		{
			name: "position_out_of_range_no_reward",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/out_of_range"
				positionId := uint64(1006)

				// Create pool with tick at 500 (outside position range)
				pool := sr.NewPool(poolPath, baseTime)
				s.getPools().set(poolPath, pool)

				// Create deposit with tick range -100 to 100, but current tick is 500
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner6"),
					poolPath,
					u256.NewUint(1000000),
					baseTime,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Setup pool tier
				poolTier := s.getPoolTier()
				poolTier.changeTier(baseHeight, baseTime, s.getPools(), poolPath, 1)

				// Initialize pool state with tick at 500 (out of range)
				poolResolver := NewPoolResolver(pool)
				poolResolver.GlobalRewardRatioAccumulation().Set(baseTime, u256.Zero())
				poolResolver.HistoricalTick().Set(baseTime, int32(500))   // Out of range
				poolResolver.StakedLiquidity().Set(baseTime, u256.Zero()) // No in-range liquidity
				poolResolver.RewardCache().Set(baseTime, int64(1000000))

				return positionId, poolPath
			},
			currentHeight:         baseHeight + 10,
			currentTimestamp:      baseTime + 100,
			expectInternalReward:  false,
			expectInternalPenalty: false,
			expectExternalReward:  false,
			expectExternalPenalty: false,
			minInternalReward:     0,
			maxInternalReward:     0,
		},
		{
			name: "zero_liquidity_position",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/zero_liquidity"
				positionId := uint64(1007)

				// Create pool with tier 1
				pool := sr.NewPool(poolPath, baseTime)
				s.getPools().set(poolPath, pool)

				// Create deposit with zero liquidity
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner7"),
					poolPath,
					u256.Zero(), // Zero liquidity
					baseTime,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Setup pool tier
				poolTier := s.getPoolTier()
				poolTier.changeTier(baseHeight, baseTime, s.getPools(), poolPath, 1)

				// Initialize pool state
				poolResolver := NewPoolResolver(pool)
				poolResolver.GlobalRewardRatioAccumulation().Set(baseTime, u256.Zero())
				poolResolver.HistoricalTick().Set(baseTime, int32(0))
				poolResolver.StakedLiquidity().Set(baseTime, u256.NewUint(1000000))
				poolResolver.RewardCache().Set(baseTime, int64(1000000))

				return positionId, poolPath
			},
			currentHeight:         baseHeight + 10,
			currentTimestamp:      baseTime + 100,
			expectInternalReward:  false,
			expectInternalPenalty: false,
			expectExternalReward:  false,
			expectExternalPenalty: false,
			minInternalReward:     0,
			maxInternalReward:     0,
		},
		{
			name: "incentive_not_yet_started",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/incentive_not_started"
				positionId := uint64(1008)

				// Create pool
				pool := sr.NewPool(poolPath, baseTime)
				s.getPools().set(poolPath, pool)

				// Create external incentive that starts in the future
				incentiveStartTime := baseTime + 1000 // Future
				incentiveEndTime := baseTime + 2000
				rewardAmount := int64(10000)
				incentiveId := "future-incentive"

				incentive := sr.NewExternalIncentive(
					incentiveId,
					poolPath,
					gnsPath,
					rewardAmount,
					incentiveStartTime,
					incentiveEndTime,
					testutils.TestAddress("refundee"),
					0,
					baseHeight,
					baseTime,
					false,
				)
				incentive.SetRewardPerSecond(rewardAmount / (incentiveEndTime - incentiveStartTime))

				poolResolver := NewPoolResolver(pool)
				poolResolver.IncentivesResolver().create(testutils.TestAddress("refundee"), incentive)

				// Create deposit
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner8"),
					poolPath,
					u256.NewUint(1000000),
					baseTime,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Initialize pool state
				poolResolver.GlobalRewardRatioAccumulation().Set(baseTime, u256.Zero())
				poolResolver.HistoricalTick().Set(baseTime, int32(0))
				poolResolver.StakedLiquidity().Set(baseTime, u256.NewUint(1000000))

				return positionId, poolPath
			},
			currentHeight:          baseHeight + 10,
			currentTimestamp:       baseTime + 100, // Before incentive starts
			expectInternalReward:   false,
			expectInternalPenalty:  false,
			expectExternalReward:   false,
			expectExternalPenalty:  false,
			minExternalRewardCount: 0,
		},
		{
			name: "incentive_already_ended",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/incentive_ended"
				positionId := uint64(1009)

				// Create pool
				pool := sr.NewPool(poolPath, baseTime-2000)
				s.getPools().set(poolPath, pool)

				// Create external incentive that already ended
				incentiveStartTime := baseTime - 2000
				incentiveEndTime := baseTime - 1000 // Already ended
				rewardAmount := int64(10000)
				incentiveId := "ended-incentive"

				incentive := sr.NewExternalIncentive(
					incentiveId,
					poolPath,
					gnsPath,
					rewardAmount,
					incentiveStartTime,
					incentiveEndTime,
					testutils.TestAddress("refundee"),
					0,
					baseHeight,
					baseTime-2000,
					false,
				)
				incentive.SetRewardPerSecond(rewardAmount / (incentiveEndTime - incentiveStartTime))

				poolResolver := NewPoolResolver(pool)
				poolResolver.IncentivesResolver().create(testutils.TestAddress("refundee"), incentive)

				// Create deposit (staked after incentive ended)
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime-500)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner9"),
					poolPath,
					u256.NewUint(1000000),
					baseTime-500,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Initialize pool state
				poolResolver.GlobalRewardRatioAccumulation().Set(baseTime-2000, u256.Zero())
				poolResolver.HistoricalTick().Set(baseTime-2000, int32(0))
				poolResolver.StakedLiquidity().Set(baseTime-2000, u256.NewUint(1000000))

				return positionId, poolPath
			},
			currentHeight:          baseHeight + 10,
			currentTimestamp:       baseTime,
			expectInternalReward:   false,
			expectInternalPenalty:  false,
			expectExternalReward:   false,
			expectExternalPenalty:  false,
			minExternalRewardCount: 0,
		},
		{
			name: "internal_and_external_rewards_combined",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/combined_rewards"
				positionId := uint64(1010)

				// Create pool with tier 1
				pool := sr.NewPool(poolPath, baseTime-100)
				s.getPools().set(poolPath, pool)

				// Setup pool tier
				poolTier := s.getPoolTier()
				poolTier.changeTier(baseHeight, baseTime-100, s.getPools(), poolPath, 1)

				// Create external incentive
				incentiveStartTime := baseTime - 50
				incentiveEndTime := baseTime + 1000
				rewardAmount := int64(10000)
				incentiveId := "combined-incentive"

				incentive := sr.NewExternalIncentive(
					incentiveId,
					poolPath,
					gnsPath,
					rewardAmount,
					incentiveStartTime,
					incentiveEndTime,
					testutils.TestAddress("refundee"),
					0,
					baseHeight,
					baseTime-100,
					false,
				)
				incentive.SetRewardPerSecond(rewardAmount / (incentiveEndTime - incentiveStartTime))

				poolResolver := NewPoolResolver(pool)
				poolResolver.IncentivesResolver().create(testutils.TestAddress("refundee"), incentive)

				// Create deposit
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime-50)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner10"),
					poolPath,
					u256.NewUint(1000000),
					baseTime-50,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Initialize pool state
				poolResolver.GlobalRewardRatioAccumulation().Set(baseTime-100, u256.Zero())
				poolResolver.HistoricalTick().Set(baseTime-100, int32(0))
				poolResolver.StakedLiquidity().Set(baseTime-100, u256.NewUint(1000000))
				poolResolver.RewardCache().Set(baseTime-100, int64(1000000))

				return positionId, poolPath
			},
			currentHeight:          baseHeight + 10,
			currentTimestamp:       baseTime + 10,
			expectInternalReward:   true,
			expectInternalPenalty:  true,
			expectExternalReward:   true,
			expectExternalPenalty:  true,
			minExternalRewardCount: 1,
			validateFunc: func(t *testing.T, reward Reward) {
				uassert.True(t, reward.Internal > 0, "should have internal reward")
				uassert.True(t, len(reward.External) >= 1, "should have external reward")
			},
		},
		{
			name: "warmup_transition_50_percent",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/warmup50"
				positionId := uint64(1011)

				// Create pool with tier 1
				// Stake time is 6 days ago (past 5-day warmup, in 50% warmup period)
				stakeTime := baseTime - 86400*6
				pool := sr.NewPool(poolPath, stakeTime)
				s.getPools().set(poolPath, pool)

				// Setup pool tier
				poolTier := s.getPoolTier()
				poolTier.changeTier(baseHeight, stakeTime, s.getPools(), poolPath, 1)

				// Create deposit
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), stakeTime)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner11"),
					poolPath,
					u256.NewUint(1000000),
					stakeTime,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Initialize pool state
				poolResolver := NewPoolResolver(pool)
				poolResolver.GlobalRewardRatioAccumulation().Set(stakeTime, u256.Zero())
				poolResolver.HistoricalTick().Set(stakeTime, int32(0))
				poolResolver.StakedLiquidity().Set(stakeTime, u256.NewUint(1000000))
				poolResolver.RewardCache().Set(stakeTime, int64(1000000))

				return positionId, poolPath
			},
			currentHeight:         baseHeight + 10,
			currentTimestamp:      baseTime,
			expectInternalReward:  true,
			expectInternalPenalty: true,
			minInternalReward:     1,
			maxInternalReward:     math.MaxInt64,
			validateFunc: func(t *testing.T, reward Reward) {
				// After 6 days: 5 days in 30% warmup, 1 day in 50% warmup
				// The penalty ratio reflects the weighted average of penalties across all periods
				totalReward := reward.Internal + reward.InternalPenalty
				uassert.True(t, totalReward > 0, "should have total reward")
				uassert.True(t, reward.Internal > 0, "should have internal reward")
				uassert.True(t, reward.InternalPenalty > 0, "should have internal penalty")
			},
		},
		{
			name: "warmup_transition_70_percent",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/warmup70"
				positionId := uint64(1012)

				// Create pool with tier 1
				// Stake time is 15 days ago (past 10-day warmup, in 70% warmup period)
				stakeTime := baseTime - 86400*15
				pool := sr.NewPool(poolPath, stakeTime)
				s.getPools().set(poolPath, pool)

				// Setup pool tier
				poolTier := s.getPoolTier()
				poolTier.changeTier(baseHeight, stakeTime, s.getPools(), poolPath, 1)

				// Create deposit
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), stakeTime)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner12"),
					poolPath,
					u256.NewUint(1000000),
					stakeTime,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Initialize pool state
				poolResolver := NewPoolResolver(pool)
				poolResolver.GlobalRewardRatioAccumulation().Set(stakeTime, u256.Zero())
				poolResolver.HistoricalTick().Set(stakeTime, int32(0))
				poolResolver.StakedLiquidity().Set(stakeTime, u256.NewUint(1000000))
				poolResolver.RewardCache().Set(stakeTime, int64(1000000))

				return positionId, poolPath
			},
			currentHeight:         baseHeight + 10,
			currentTimestamp:      baseTime,
			expectInternalReward:  true,
			expectInternalPenalty: true,
			minInternalReward:     1,
			maxInternalReward:     math.MaxInt64,
			validateFunc: func(t *testing.T, reward Reward) {
				// After 15 days: 5 days in 30%, 5 days in 50%, 5 days in 70% warmup
				// The penalty ratio reflects the weighted average of penalties across all periods
				totalReward := reward.Internal + reward.InternalPenalty
				uassert.True(t, totalReward > 0, "should have total reward")
				uassert.True(t, reward.Internal > 0, "should have internal reward")
				uassert.True(t, reward.InternalPenalty > 0, "should have internal penalty")
			},
		},
		{
			name: "same_timestamp_no_change",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/same_timestamp"
				positionId := uint64(1013)

				// Create pool with tier 1
				pool := sr.NewPool(poolPath, baseTime)
				s.getPools().set(poolPath, pool)

				// Setup pool tier
				poolTier := s.getPoolTier()
				poolTier.changeTier(baseHeight, baseTime, s.getPools(), poolPath, 1)

				// Create deposit at same timestamp as query
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner13"),
					poolPath,
					u256.NewUint(1000000),
					baseTime,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Initialize pool state
				poolResolver := NewPoolResolver(pool)
				poolResolver.GlobalRewardRatioAccumulation().Set(baseTime, u256.Zero())
				poolResolver.HistoricalTick().Set(baseTime, int32(0))
				poolResolver.StakedLiquidity().Set(baseTime, u256.NewUint(1000000))
				poolResolver.RewardCache().Set(baseTime, int64(1000000))

				return positionId, poolPath
			},
			currentHeight:         baseHeight,
			currentTimestamp:      baseTime, // Same as stake time
			expectInternalReward:  false,
			expectInternalPenalty: false,
			expectExternalReward:  false,
			expectExternalPenalty: false,
			minInternalReward:     0,
			maxInternalReward:     0,
		},
		{
			name: "large_liquidity_value",
			setupFunc: func(t *testing.T, s *stakerV1, baseTime int64) (uint64, string) {
				poolPath := "gno.land/r/test/large_liquidity"
				positionId := uint64(1014)

				// Create pool with tier 1
				pool := sr.NewPool(poolPath, baseTime)
				s.getPools().set(poolPath, pool)

				// Setup pool tier
				poolTier := s.getPoolTier()
				poolTier.changeTier(baseHeight, baseTime, s.getPools(), poolPath, 1)

				// Create deposit with very large liquidity
				largeLiquidity := u256.MustFromDecimal("340282366920938463463374607431768211455") // Near max u256
				warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime)
				deposit := sr.NewDeposit(
					testutils.TestAddress("owner14"),
					poolPath,
					largeLiquidity,
					baseTime,
					-100,
					100,
					warmups,
				)
				s.getDeposits().set(positionId, deposit)

				// Initialize pool state
				poolResolver := NewPoolResolver(pool)
				poolResolver.GlobalRewardRatioAccumulation().Set(baseTime, u256.Zero())
				poolResolver.HistoricalTick().Set(baseTime, int32(0))
				poolResolver.StakedLiquidity().Set(baseTime, largeLiquidity)
				poolResolver.RewardCache().Set(baseTime, int64(1000000))

				return positionId, poolPath
			},
			currentHeight:         baseHeight + 10,
			currentTimestamp:      baseTime + 100,
			expectInternalReward:  true,
			expectInternalPenalty: true,
			expectExternalReward:  false,
			expectExternalPenalty: false,
			minInternalReward:     1,
			maxInternalReward:     math.MaxInt64,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset mock instance for each test
			initStakerTest(t)
			s := getMockInstance()

			// Setup test data
			positionId, _ := tt.setupFunc(t, s, baseTime)

			// Execute
			reward := s.calcPositionReward(tt.currentHeight, tt.currentTimestamp, positionId)

			// Validate internal reward expectations
			if tt.expectInternalReward {
				uassert.True(t, reward.Internal > 0,
					"expected internal reward but got 0")
				if tt.minInternalReward > 0 {
					uassert.True(t, reward.Internal >= tt.minInternalReward,
						"internal reward below minimum")
				}
				if tt.maxInternalReward > 0 && tt.maxInternalReward < math.MaxInt64 {
					uassert.True(t, reward.Internal <= tt.maxInternalReward,
						"internal reward above maximum")
				}
			} else {
				uassert.Equal(t, int64(0), reward.Internal,
					"expected no internal reward")
			}

			// Validate internal penalty expectations
			if tt.expectInternalPenalty {
				uassert.True(t, reward.InternalPenalty > 0,
					"expected internal penalty but got 0")
			} else {
				uassert.Equal(t, int64(0), reward.InternalPenalty,
					"expected no internal penalty")
			}

			// Validate external reward expectations
			if tt.expectExternalReward {
				hasExternal := false
				for _, v := range reward.External {
					if v > 0 {
						hasExternal = true
						break
					}
				}
				uassert.True(t, hasExternal,
					"expected external reward but got none")
			}
			if tt.minExternalRewardCount > 0 {
				uassert.True(t, len(reward.External) >= tt.minExternalRewardCount,
					"insufficient external reward count")
			}

			// Validate external penalty expectations
			if tt.expectExternalPenalty {
				hasPenalty := false
				for _, v := range reward.ExternalPenalty {
					if v > 0 {
						hasPenalty = true
						break
					}
				}
				uassert.True(t, hasPenalty,
					"expected external penalty but got none")
			}

			// Run custom validation if provided
			if tt.validateFunc != nil {
				tt.validateFunc(t, reward)
			}
		})
	}
}

// TestCalcPositionReward_BoundaryConditions tests edge cases at boundaries.
func TestCalcPositionReward_BoundaryConditions(t *testing.T) {
	tests := []struct {
		name          string
		tickLower     int32
		tickUpper     int32
		currentTick   int32
		expectInRange bool
	}{
		{
			name:          "exactly_at_lower_bound",
			tickLower:     -100,
			tickUpper:     100,
			currentTick:   -100,
			expectInRange: true,
		},
		{
			name:          "exactly_at_upper_bound_minus_one",
			tickLower:     -100,
			tickUpper:     100,
			currentTick:   99,
			expectInRange: true,
		},
		{
			name:          "exactly_at_upper_bound",
			tickLower:     -100,
			tickUpper:     100,
			currentTick:   100,
			expectInRange: false, // Upper bound is exclusive
		},
		{
			name:          "one_below_lower_bound",
			tickLower:     -100,
			tickUpper:     100,
			currentTick:   -101,
			expectInRange: false,
		},
		{
			name:          "wide_range_in_middle",
			tickLower:     -887220,
			tickUpper:     887220,
			currentTick:   0,
			expectInRange: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)
			s := getMockInstance()

			baseTime := time.Now().Unix()
			baseHeight := int64(100)
			poolPath := "gno.land/r/test/boundary_" + tt.name
			positionId := uint64(4001)

			// Create pool with tier 1
			pool := sr.NewPool(poolPath, baseTime)
			s.getPools().set(poolPath, pool)

			// Setup pool tier
			poolTier := s.getPoolTier()
			poolTier.changeTier(baseHeight, baseTime, s.getPools(), poolPath, 1)

			// Create deposit with specified tick range
			warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime)
			deposit := sr.NewDeposit(
				testutils.TestAddress("boundaryOwner"),
				poolPath,
				u256.NewUint(1000000),
				baseTime,
				tt.tickLower,
				tt.tickUpper,
				warmups,
			)
			s.getDeposits().set(positionId, deposit)

			// Initialize pool state with specified current tick
			poolResolver := NewPoolResolver(pool)
			poolResolver.GlobalRewardRatioAccumulation().Set(baseTime, u256.Zero())
			poolResolver.HistoricalTick().Set(baseTime, tt.currentTick)
			if tt.expectInRange {
				poolResolver.StakedLiquidity().Set(baseTime, u256.NewUint(1000000))
			} else {
				poolResolver.StakedLiquidity().Set(baseTime, u256.Zero())
			}
			poolResolver.RewardCache().Set(baseTime, int64(1000000))

			// Execute
			reward := s.calcPositionReward(baseHeight+10, baseTime+100, positionId)

			// Verify
			if tt.expectInRange {
				totalReward := reward.Internal + reward.InternalPenalty
				uassert.True(t, totalReward > 0,
					"position in range should have rewards")
			} else {
				uassert.Equal(t, int64(0), reward.Internal,
					"position out of range should have no internal reward")
			}
		})
	}
}

// TestCalcPositionReward_RewardAggregation tests that rewards from multiple warmup periods
func TestCalcPositionReward_RewardAggregation(t *testing.T) {
	initStakerTest(t)
	s := getMockInstance()

	baseTime := time.Now().Unix()
	baseHeight := int64(100)
	poolPath := "gno.land/r/test/aggregation"
	positionId := uint64(2001)

	// Create pool with tier 1
	pool := sr.NewPool(poolPath, baseTime)
	s.getPools().set(poolPath, pool)

	// Setup pool tier
	poolTier := s.getPoolTier()
	poolTier.changeTier(baseHeight, baseTime, s.getPools(), poolPath, 1)

	// Create deposit
	warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime)
	deposit := sr.NewDeposit(
		testutils.TestAddress("aggOwner"),
		poolPath,
		u256.NewUint(1000000),
		baseTime,
		-100,
		100,
		warmups,
	)
	s.getDeposits().set(positionId, deposit)

	// Initialize pool state
	poolResolver := NewPoolResolver(pool)
	poolResolver.GlobalRewardRatioAccumulation().Set(baseTime, u256.Zero())
	poolResolver.HistoricalTick().Set(baseTime, int32(0))
	poolResolver.StakedLiquidity().Set(baseTime, u256.NewUint(1000000))
	poolResolver.RewardCache().Set(baseTime, int64(1000000))

	// Execute at different time points and verify aggregation
	times := []int64{
		baseTime + 100,
		baseTime + 1000,
		baseTime + 10000,
	}

	var prevReward int64
	for _, ts := range times {
		reward := s.calcPositionReward(baseHeight+10, ts, positionId)

		// Total reward should always be positive and increasing over time
		totalReward := reward.Internal + reward.InternalPenalty
		uassert.True(t, totalReward >= prevReward,
			"total reward should not decrease over time")
		prevReward = totalReward
	}
}

// TestCalcPositionReward_ExternalRewardMapIntegrity tests that external reward maps
func TestCalcPositionReward_ExternalRewardMapIntegrity(t *testing.T) {
	initStakerTest(t)
	s := getMockInstance()

	baseTime := time.Now().Unix()
	baseHeight := int64(100)
	poolPath := "gno.land/r/test/map_integrity"
	positionId := uint64(3001)

	// Create pool
	pool := sr.NewPool(poolPath, baseTime-100)
	s.getPools().set(poolPath, pool)

	// Create multiple external incentives
	poolResolver := NewPoolResolver(pool)
	for i := 0; i < 5; i++ {
		incentive := sr.NewExternalIncentive(
			"integrity-incentive-"+string(rune('A'+i)),
			poolPath,
			gnsPath,
			int64(1000*(i+1)),
			baseTime-50,
			baseTime+1000,
			testutils.TestAddress("refundee"),
			0,
			baseHeight,
			baseTime-100,
			false,
		)
		incentive.SetRewardPerSecond(int64(1000 * (i + 1) / 1050))
		poolResolver.IncentivesResolver().create(testutils.TestAddress("refundee"), incentive)
	}

	// Create deposit
	warmups := instantiateWarmup(sr.DefaultWarmupTemplate(), baseTime-50)
	deposit := sr.NewDeposit(
		testutils.TestAddress("integrityOwner"),
		poolPath,
		u256.NewUint(1000000),
		baseTime-50,
		-100,
		100,
		warmups,
	)
	s.getDeposits().set(positionId, deposit)

	// Initialize pool state
	poolResolver.GlobalRewardRatioAccumulation().Set(baseTime-100, u256.Zero())
	poolResolver.HistoricalTick().Set(baseTime-100, int32(0))
	poolResolver.StakedLiquidity().Set(baseTime-100, u256.NewUint(1000000))

	// Get first reward
	reward1 := s.calcPositionReward(baseHeight+10, baseTime+10, positionId)

	// Modify the returned map (should not affect future calls)
	reward1.External["modified-key"] = 999999
	reward1.ExternalPenalty["modified-key"] = 888888

	// Get second reward
	reward2 := s.calcPositionReward(baseHeight+20, baseTime+20, positionId)

	// Verify the modification didn't affect reward2
	_, hasModified := reward2.External["modified-key"]
	uassert.False(t, hasModified, "reward maps should be independent")

	_, hasModifiedPenalty := reward2.ExternalPenalty["modified-key"]
	uassert.False(t, hasModifiedPenalty, "penalty maps should be independent")
}
