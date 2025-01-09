package launchpad

import (
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestValidateRewardCollection(t *testing.T) {
	currentHeight := uint64(100)

	tests := []struct {
		name        string
		deposit     Deposit
		height      uint64
		shouldError bool
		errorMsg    string
	}{
		{
			name: "Valid reward ready to collect",
			deposit: Deposit{
				claimableHeight:   50, // Less than current height
				rewardCollectTime: 0,
			},
			height:      currentHeight,
			shouldError: false,
		},
		{
			name: "Reward not yet claimable",
			deposit: Deposit{
				claimableHeight:   150, // Greater than current height
				rewardCollectTime: 0,
			},
			height:      currentHeight,
			shouldError: true,
			errorMsg:    "reward not yet claimable",
		},
		{
			name: "Already collected reward can be collected before claimable height",
			deposit: Deposit{
				claimableHeight:   150,
				rewardCollectTime: 1, // Already collected before
			},
			height:      currentHeight,
			shouldError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateRewardCollection(tt.deposit, tt.height)
			if tt.shouldError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestCalculateDepositRatioX128(t *testing.T) {
	q128 = u256.MustFromDecimal("18446744073709551616")

	tests := []struct {
		name       string
		tierAmount uint64
		amount     uint64
		expected   string
	}{
		{
			name:       "Equal amounts",
			tierAmount: 1000,
			amount:     1000,
			expected:   "79228162514264337593543950336", // 1.0 in Q96
		},
		{
			name:       "Half amount",
			tierAmount: 1000,
			amount:     500,
			expected:   "39614081257132168796771975168", // 0.5 in Q96
		},
		{
			name:       "Double amount",
			tierAmount: 500,
			amount:     1000,
			expected:   "158456325028528675187087900672", // 2.0 in Q96
		},
		{
			name:       "Zero amount",
			tierAmount: 1000,
			amount:     0,
			expected:   "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ratio := calcDepositRatioX128(tt.tierAmount, tt.amount)
			expected := u256.MustFromDecimal(tt.expected)
			uassert.Equal(t, 0, ratio.Cmp(expected))
		})
	}
}

func TestProcessDepositReward(t *testing.T) {
	tests := []struct {
		name           string
		deposit        Deposit
		rewardX128     *u256.Uint
		tierAmount     uint64
		expectedReward uint64
		shouldError    bool
	}{
		{
			name: "Normal reward calculation",
			deposit: Deposit{
				amount: 1000,
				//rewardAmount: 0,
			},
			rewardX128:      u256.NewUint(1000).Mul(u256.NewUint(1000), q128),
			tierAmount:     2000,
			expectedReward: 500, // (1000/2000) * 1000 = 500
			shouldError:    false,
		},
		/*
		   {
		       name: "Tier amount is 0",
		       deposit: Deposit{
		           amount:       1000,
		           //rewardAmount: 0,
		       },
		       rewardX96:      u256.NewUint(1000),
		       tierAmount:     0,
		       expectedReward: 0,
		       shouldError:    true,
		   },*/
		{
			name: "Reward is accumulated",
			deposit: Deposit{
				amount: 1000,
				//rewardAmount: 100,
			},
			rewardX128:      u256.NewUint(1000).Mul(u256.NewUint(1000), q128),
			tierAmount:     2000,
			expectedReward: 500, // 600, // Existing 100 + New reward 500
			shouldError:    false,
		},
	}

	for i, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			state := NewRewardState(tt.rewardX128	, 1000, 2000)
			depositId := ufmt.Sprintf("depositId-%d", i)
			state.AddStake(1000, depositId, tt.deposit.amount)
			state.TotalStake = tt.tierAmount // force overriding total stake
			state.finalize(1001)

			reward := state.CalculateReward(depositId)
			uassert.Equal(t, tt.expectedReward, reward)
		})
	}
}

func TestCalculateTierRewards(t *testing.T) {
	tests := []struct {
		name              string
		tier              Tier
		currentHeight     uint64
		lastCalcHeight    uint64
		expectedRewardX128 string
		expectedReward    uint64
		shouldBeZero      bool
	}{
		{
			name: "tierAmountPerBlockX96 is 0",
			tier: Tier{
				tierAmountPerBlockX128: u256.Zero(),
				ended:                 TimeInfo{height: 1000},
			},
			currentHeight:  500,
			lastCalcHeight: 400,
			shouldBeZero:   true,
		},
		{
			name: "sinceLast is 0",
			tier: Tier{
				tierAmountPerBlockX128: u256.NewUint(1000),
				ended:                 TimeInfo{height: 1000},
			},
			currentHeight:  500,
			lastCalcHeight: 500,
			shouldBeZero:   true,
		},
		{
			name: "Current height exceeds end height",
			tier: Tier{
				tierAmountPerBlockX128: u256.NewUint(1000),
				ended:                 TimeInfo{height: 450},
			},
			currentHeight:     500,
			lastCalcHeight:    400,
			expectedRewardX128: "50000", // 1000 * (450-400)
			expectedReward:    0,       // (50000 / Q96)
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rewardX128, reward, err := calculateTierRewards(tt.tier, tt.currentHeight, tt.lastCalcHeight)

			uassert.NoError(t, err)

			if tt.shouldBeZero {
				uassert.Equal(t, true, rewardX128.IsZero())
				uassert.Equal(t, uint64(0), reward)
			} else {
				expected := u256.MustFromDecimal(tt.expectedRewardX128)
				uassert.Equal(t, 0, rewardX128.Cmp(expected))
				uassert.Equal(t, tt.expectedReward, reward)
			}
		})
	}
}
