package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestRewardState_IsClaimable(t *testing.T) {
	tests := []struct {
		name                string
		claimableTime       int64
		currentHeight       int64
		expectedIsClaimable bool
		expectedHasError    bool
		expectedError       string
	}{
		{
			name:                "is claimable return false when current height is before claimable height",
			claimableTime:       100,
			currentHeight:       50,
			expectedIsClaimable: false,
			expectedHasError:    false,
		},
		{
			name:                "is claimable return true when current height equals claimable height",
			claimableTime:       100,
			currentHeight:       100,
			expectedIsClaimable: true,
			expectedHasError:    false,
		},
		{
			name:                "is claimable return true when current height is after claimable height",
			claimableTime:       100,
			currentHeight:       150,
			expectedIsClaimable: true,
			expectedHasError:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			state := &RewardState{
				claimableTime: tt.claimableTime,
			}

			// Execute
			result := state.IsClaimable(tt.currentHeight)

			// Verify
			uassert.Equal(t, result, tt.expectedIsClaimable)
		})
	}
}

func TestRewardState_CalculateReward(t *testing.T) {
	tests := []struct {
		name                    string
		priceDebt               *u256.Uint
		depositAmount           int64
		claimedAmount           int64
		accumRewardPerDeposit   *u256.Uint
		expectedReward          int64
		expectedClaimableReward int64
		expectedHasError        bool
		expectedError           string
	}{
		{
			name:                    "calculate reward return correct reward for first claim",
			priceDebt:               u256.NewUintFromInt64(100),
			depositAmount:           1000,
			claimedAmount:           0,
			accumRewardPerDeposit:   u256.NewUintFromInt64(200),
			expectedReward:          100 * 1000,
			expectedClaimableReward: 100 * 1000,
			expectedHasError:        false,
		},
		{
			name:                    "calculate reward return correct reward with previous claims",
			priceDebt:               u256.NewUintFromInt64(100),
			depositAmount:           1000,
			claimedAmount:           50,
			accumRewardPerDeposit:   u256.NewUintFromInt64(200),
			expectedReward:          100 * 1000,
			expectedClaimableReward: 100*1000 - 50,
			expectedHasError:        false,
		},
		{
			name:                    "calculate reward return zero when no new rewards",
			priceDebt:               u256.NewUintFromInt64(200),
			depositAmount:           1000,
			claimedAmount:           0,
			accumRewardPerDeposit:   u256.NewUintFromInt64(200),
			expectedReward:          0 * 1000,
			expectedClaimableReward: 0 * 1000,
			expectedHasError:        false,
		},
		{
			name:                    "calculate claimable reward return zero when reward equals claimedAmount",
			priceDebt:               u256.NewUintFromInt64(100),
			depositAmount:           1000,
			claimedAmount:           100 * 1000,
			accumRewardPerDeposit:   u256.NewUintFromInt64(200),
			expectedReward:          100 * 1000,
			expectedClaimableReward: 0,
			expectedHasError:        false,
		},
		{
			name:                    "calculate claimable reward return zero when reward less than claimedAmount",
			priceDebt:               u256.NewUintFromInt64(100),
			depositAmount:           1000,
			claimedAmount:           100*1000 + 100,
			accumRewardPerDeposit:   u256.NewUintFromInt64(200),
			expectedReward:          100 * 1000,
			expectedClaimableReward: 0,
			expectedHasError:        false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			state := &RewardState{
				priceDebtX128: u256.Zero().Lsh(tt.priceDebt, 128),
				depositAmount: tt.depositAmount,
				claimedAmount: tt.claimedAmount,
			}

			// Execute
			accumRewardPerDepositX128 := u256.Zero().Lsh(tt.accumRewardPerDeposit, 128)
			resultReward := state.calculateReward(accumRewardPerDepositX128)
			resultClaimableReward := state.calculateClaimableReward(accumRewardPerDepositX128)

			// Verify
			uassert.Equal(t, resultReward, tt.expectedReward)
			uassert.Equal(t, resultClaimableReward, tt.expectedClaimableReward)
		})
	}
}

func TestRewardState_NewRewardState(t *testing.T) {
	tests := []struct {
		name                string
		priceDebt           *u256.Uint
		depositAmount       int64
		distributeStartTime int64
		distributeEndTime   int64
		claimableTime       int64
		expectedHasError    bool
		expectedError       string
	}{
		{
			name:                "new reward state create valid state with correct values",
			priceDebt:           u256.NewUintFromInt64(100),
			depositAmount:       1000,
			distributeStartTime: 100,
			distributeEndTime:   200,
			claimableTime:       100,
			expectedHasError:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			accumulatedRewardPerDepositX128 := u256.Zero().Lsh(tt.priceDebt, 128)
			// Execute
			state := NewRewardState(
				accumulatedRewardPerDepositX128,
				tt.depositAmount,
				tt.distributeStartTime,
				tt.distributeEndTime,
				tt.claimableTime,
			)

			// Verify
			statePriceDebt := u256.Zero().Rsh(state.PriceDebtX128(), 128).Int64()
			uassert.Equal(t, tt.priceDebt.Int64(), statePriceDebt)
			uassert.Equal(t, tt.depositAmount, state.DepositAmount())
			uassert.Equal(t, tt.distributeStartTime, state.DistributeStartTime())
			uassert.Equal(t, tt.distributeEndTime, state.DistributeEndTime())
			uassert.Equal(t, tt.claimableTime, state.ClaimableTime())
		})
	}
}
