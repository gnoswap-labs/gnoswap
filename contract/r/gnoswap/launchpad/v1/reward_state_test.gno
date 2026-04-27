package v1

import (
	"testing"

	"gno.land/r/gnoswap/launchpad"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

const maxUint256 = "115792089237316195423570985008687907853269984665640564039457584007913129639935"

func wrappedPriceDebtForDelta(deltaX128 *u256.Uint) *u256.Uint {
	return u256.Zero().Neg(deltaX128)
}

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
			state := launchpad.NewRewardState(u256.Zero(), 1000, 100, 200, tt.claimableTime)

			// Execute
			result := isRewardStateClaimable(state, tt.currentHeight)

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
			state := launchpad.NewRewardState(u256.Zero().Lsh(tt.priceDebt, 128), tt.depositAmount, 100, 200, 100)
			state.SetClaimedAmount(tt.claimedAmount)

			// Execute
			accumRewardPerDepositX128 := u256.Zero().Lsh(tt.accumRewardPerDeposit, 128)
			resultReward := calculateReward(state, accumRewardPerDepositX128)
			resultClaimableReward := calculateClaimableReward(state, accumRewardPerDepositX128)

			// Verify
			uassert.Equal(t, resultReward, tt.expectedReward)
			uassert.Equal(t, resultClaimableReward, tt.expectedClaimableReward)
		})
	}
}

func TestRewardState_CalculateClaimableRewardWrappedAccumulator(t *testing.T) {
	state := launchpad.NewRewardState(
		u256.MustFromDecimal(maxUint256),
		1,
		100,
		200,
		100,
	)

	reward := calculateReward(state, q128.Clone())
	claimable := calculateClaimableReward(state, q128.Clone())
	uassert.Equal(t, int64(1), reward)
	uassert.Equal(t, int64(1), claimable)
}

func TestRewardState_CalculateClaimableRewardWrappedAccumulatorVariants(t *testing.T) {
	tests := []struct {
		name              string
		deltaX128         *u256.Uint
		depositAmount     int64
		claimedAmount     int64
		expectedReward    int64
		expectedClaimable int64
	}{
		{
			name:              "wrapped delta returns 13 reward",
			deltaX128:         u256.Zero().Mul(q128.Clone(), u256.NewUint(13)),
			depositAmount:     1,
			claimedAmount:     0,
			expectedReward:    13,
			expectedClaimable: 13,
		},
		{
			name:              "wrapped delta returns 16 reward",
			deltaX128:         u256.Zero().Mul(q128.Clone(), u256.NewUint(16)),
			depositAmount:     1,
			claimedAmount:     0,
			expectedReward:    16,
			expectedClaimable: 16,
		},
		{
			name:              "wrapped delta is floored to zero reward",
			deltaX128:         u256.Zero().Sub(q128.Clone(), u256.One()),
			depositAmount:     1,
			claimedAmount:     0,
			expectedReward:    0,
			expectedClaimable: 0,
		},
		{
			name:              "wrapped delta subtracts claimed amount",
			deltaX128:         u256.Zero().Mul(q128.Clone(), u256.NewUint(13)),
			depositAmount:     1,
			claimedAmount:     5,
			expectedReward:    13,
			expectedClaimable: 8,
		},
		{
			name:              "wrapped delta equal to claimed amount yields zero claimable",
			deltaX128:         u256.Zero().Mul(q128.Clone(), u256.NewUint(13)),
			depositAmount:     1,
			claimedAmount:     13,
			expectedReward:    13,
			expectedClaimable: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			state := launchpad.NewRewardState(
				wrappedPriceDebtForDelta(tt.deltaX128),
				tt.depositAmount,
				100,
				200,
				100,
			)
			state.SetClaimedAmount(tt.claimedAmount)

			reward := calculateReward(state, u256.Zero())
			claimable := calculateClaimableReward(state, u256.Zero())

			uassert.Equal(t, tt.expectedReward, reward)
			uassert.Equal(t, tt.expectedClaimable, claimable)
		})
	}
}

func TestRewardState_newRewardState(t *testing.T) {
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
			state := launchpad.NewRewardState(
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
