package launchpad

import (
	"strconv"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/launchpad"
)

const (
	preDepositTestRewardAmount  = int64(100_000)
	preDepositTestStartTime     = int64(1000)
	preDepositTestEndTime       = int64(2000)
	preDepositTestDepositAmount = int64(1_000_000)
)

func depositAt(t *testing.T, manager *launchpad.RewardManager, depositID string, totalDepositAmount, currentTime int64) *launchpad.RewardState {
	uassert.NoError(t, updateRewardPerDepositX128(manager, totalDepositAmount, currentTime))

	deposit := newDeposit(depositID, "p", projectTier30, "", preDepositTestDepositAmount, 1, currentTime, manager.DistributeEndTime())

	return addRewardStateByDeposit(manager, *deposit)
}

func TestNewRewardManager_AccumulatedTimeStartsAtDistributeStart(t *testing.T) {
	manager := newRewardManager(preDepositTestRewardAmount, preDepositTestStartTime, preDepositTestEndTime, 0)

	uassert.Equal(t, preDepositTestStartTime, manager.AccumulatedTime())
	uassert.True(t, isPreDepositRewardRefundable(manager))
}

func TestUpdateRewardPerDepositX128_WithoutDeposit(t *testing.T) {
	tests := []struct {
		name                    string
		currentTimes            []int64
		expectedAccumulatedTime int64
	}{
		{"before start", []int64{500}, preDepositTestStartTime},
		{"during distribution", []int64{1500}, 1500},
		{"after end", []int64{2500}, preDepositTestEndTime},
		{"earlier time", []int64{1500, 1200}, 1500},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			manager := newRewardManager(preDepositTestRewardAmount, preDepositTestStartTime, preDepositTestEndTime, 0)

			for _, currentTime := range tt.currentTimes {
				uassert.NoError(t, updateRewardPerDepositX128(manager, 0, currentTime))
			}

			uassert.Equal(t, tt.expectedAccumulatedTime, manager.AccumulatedTime())
			uassert.True(t, manager.AccumulatedRewardPerDepositX128().IsZero())
		})
	}
}

func TestPreDepositReward_Refundable(t *testing.T) {
	tests := []struct {
		name               string
		depositTimes       []int64
		expectedRewards    []int64
		expectedRefundable int64
	}{
		{
			name:               "single deposit at start",
			depositTimes:       []int64{1000},
			expectedRewards:    []int64{100_000},
			expectedRefundable: 0,
		},
		{
			name:               "single deposit at midpoint",
			depositTimes:       []int64{1500},
			expectedRewards:    []int64{50_000},
			expectedRefundable: 50_000,
		},
		{
			name:               "multiple deposits after start",
			depositTimes:       []int64{1200, 1600},
			expectedRewards:    []int64{60_000, 20_000}, // 40_000 alone + 20_000 shared, 20_000 shared
			expectedRefundable: 20_000,
		},
		{
			name:               "pre-start deposit",
			depositTimes:       []int64{500, 1500},
			expectedRewards:    []int64{75_000, 25_000},
			expectedRefundable: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			manager := newRewardManager(preDepositTestRewardAmount, preDepositTestStartTime, preDepositTestEndTime, 0)

			rewardStates := make([]*launchpad.RewardState, len(tt.depositTimes))
			for i, depositTime := range tt.depositTimes {
				totalDepositAmount := int64(i) * preDepositTestDepositAmount
				rewardStates[i] = depositAt(t, manager, strconv.Itoa(i+1), totalDepositAmount, depositTime)
			}

			totalDepositAmount := int64(len(tt.depositTimes)) * preDepositTestDepositAmount
			uassert.NoError(t, updateRewardPerDepositX128(manager, totalDepositAmount, preDepositTestEndTime))

			totalReward := int64(0)
			for i, rewardState := range rewardStates {
				reward := calculateClaimableReward(rewardState, manager.AccumulatedRewardPerDepositX128())
				uassertInRange(t, reward, tt.expectedRewards[i]-1, tt.expectedRewards[i])
				totalReward += reward
			}

			reserved := calculateMaximumClaimableRewardsForActiveDeposits(manager)
			uassert.True(t, reserved >= totalReward)

			refundable := preDepositTestRewardAmount - reserved
			uassertInRange(t, refundable, tt.expectedRefundable, tt.expectedRefundable+int64(len(tt.depositTimes)))
		})
	}
}

func TestPreDepositReward_ZeroAccumulatedTimePaysFirstDepositor(t *testing.T) {
	manager := launchpad.NewRewardManager(preDepositTestRewardAmount, preDepositTestStartTime, preDepositTestEndTime, 0)
	updateDistributeAmountPerSecondX128(manager, preDepositTestRewardAmount, preDepositTestStartTime, preDepositTestEndTime)
	uassert.False(t, isPreDepositRewardRefundable(manager))

	rewardState := depositAt(t, manager, "1", 0, 1500)
	uassert.Equal(t, int64(0), manager.AccumulatedTime())

	uassert.NoError(t, updateRewardPerDepositX128(manager, preDepositTestDepositAmount, preDepositTestEndTime))

	reward := calculateClaimableReward(rewardState, manager.AccumulatedRewardPerDepositX128())
	uassertInRange(t, reward, preDepositTestRewardAmount-1, preDepositTestRewardAmount)
}

func uassertInRange(t *testing.T, actual, min, max int64) {
	if actual < min || actual > max {
		t.Errorf("expected [%d, %d], got %d", min, max, actual)
	}
}
