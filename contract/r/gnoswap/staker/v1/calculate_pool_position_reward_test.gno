package v1

import (
	"testing"
	"time"

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
		name                string
		internal            int64
		internalPenalty     int64
		external            map[string]int64
		externalPenalty     map[string]int64
	}{
		{
			name:                "all fields set",
			internal:            1000,
			internalPenalty:     100,
			external:            map[string]int64{"incentive1": 500},
			externalPenalty:     map[string]int64{"incentive1": 50},
		},
		{
			name:                "zero values",
			internal:            0,
			internalPenalty:     0,
			external:            map[string]int64{},
			externalPenalty:     map[string]int64{},
		},
		{
			name:                "large values",
			internal:            9999999999,
			internalPenalty:     1111111111,
			external:            map[string]int64{"incentive1": 8888888888},
			externalPenalty:     map[string]int64{"incentive1": 2222222222},
		},
		{
			name:                "multiple external incentives",
			internal:            5000,
			internalPenalty:     500,
			external:            map[string]int64{"inc1": 1000, "inc2": 2000, "inc3": 3000},
			externalPenalty:     map[string]int64{"inc1": 100, "inc2": 200, "inc3": 300},
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
