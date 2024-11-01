package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

type mockExternalData struct {
	incentiveId    string
	tokenAmountX96 *u256.Uint
}

type TestFixture struct {
	TokenId       uint64
	IncentiveId   string
	StartTime     int64
	StakeTime     int64
	BlockHeight   int64
	Externals     map[uint64][]mockExternalData
	LastExternals map[string]*u256.Uint
}

func newTestFixture(t *testing.T) *TestFixture {
	t.Helper()

	mockTokenId := uint64(1)
	mockIncentiveId := "test-incentive"

	return &TestFixture{
		TokenId:     mockTokenId,
		IncentiveId: mockIncentiveId,
		StartTime:   time.Now().Add(-24 * time.Hour).Unix(),
		StakeTime:   time.Now().Add(-12 * time.Hour).Unix(),
		BlockHeight: std.GetHeight(),
		Externals: map[uint64][]mockExternalData{
			mockTokenId: {
				{
					incentiveId:    mockIncentiveId,
					tokenAmountX96: new(u256.Uint).SetUint64(1000000),
				},
			},
		},
		LastExternals: map[string]*u256.Uint{
			mockIncentiveId: new(u256.Uint).SetUint64(500000),
		},
	}
}

func (tf *TestFixture) setup() {
	// Initialize global state
	incentives = map[string]ExternalIncentive{
		tf.IncentiveId: {
			startTimestamp: tf.StartTime,
		},
	}

	deposits = map[uint64]Deposit{
		tf.TokenId: {
			stakeTimestamp: tf.StakeTime,
		},
	}

	warmUp = map[int64]int64{
		50:  150,
		70:  300,
		100: 900,
	}

	positionExternal = map[uint64]map[string]externalRewards{
		tf.TokenId: {
			tf.IncentiveId: externalRewards{
				incentiveId:    tf.IncentiveId,
				tokenAmountX96: new(u256.Uint).SetUint64(1000000),
			},
		},
	}

	positionLastExternal = map[uint64]map[string]*u256.Uint{
		tf.TokenId: {
			tf.IncentiveId: new(u256.Uint).SetUint64(500000),
		},
	}

	positionsExternalLastCalculatedHeight = map[uint64]map[string]int64{
		tf.TokenId: {
			tf.IncentiveId: 0,
		},
	}

	positionsExternalWarmUpAmount = map[uint64]map[string]warmUpAmount{
		tf.TokenId: {
			tf.IncentiveId: {},
		},
	}
}

func TestCalculator_New(t *testing.T) {
	tf := newTestFixture(t)

	tests := []struct {
		name              string
		tokenId           uint64
		incentiveId       string
		wantCurrentHeight int64
	}{
		{
			name:              "creates new calculator instance",
			tokenId:           tf.TokenId,
			incentiveId:       tf.IncentiveId,
			wantCurrentHeight: tf.BlockHeight,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			calculator := NewCalculator(tt.tokenId, tt.incentiveId)

			uassert.Equal(t, tt.tokenId, calculator.state.TokenId)
			uassert.Equal(t, tt.incentiveId, calculator.state.IncentiveId)
			uassert.Equal(t, tt.wantCurrentHeight, calculator.state.CurrentHeight)
		})
	}
}

func TestCalculator_CalculateDistribution(t *testing.T) {
	tests := []struct {
		name       string
		external   externalRewards
		lastAmount *u256.Uint
		want       *u256.Uint
	}{
		{
			name: "calculates distribution correctly",
			external: externalRewards{
				incentiveId:    "test",
				tokenAmountX96: new(u256.Uint).SetUint64(1000000),
			},
			lastAmount: new(u256.Uint).SetUint64(500000),
			want:       new(u256.Uint).SetUint64(500000),
		},
		{
			name: "handles zero last amount",
			external: externalRewards{
				incentiveId:    "test",
				tokenAmountX96: new(u256.Uint).SetUint64(1000000),
			},
			lastAmount: new(u256.Uint).SetUint64(0),
			want:       new(u256.Uint).SetUint64(1000000),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := calculateDistributionExternalRewards(tt.external, tt.lastAmount)
			uassert.True(t, tt.want.Eq(got))
		})
	}
}

func TestCalculator_CalculateRewardPeriod(t *testing.T) {
	tests := []struct {
		name        string
		blockAmount *u256.Uint
		timeSpan    TimeSpan
		want        RewardPeriod
	}{
		{
			name:        "calculates period reward correctly",
			blockAmount: new(u256.Uint).SetUint64(1000),
			timeSpan: TimeSpan{
				Start:    0,
				End:      100,
				Duration: 100,
				Ratio:    RatioThirty,
			},
			want: RewardPeriod{
				TimeSpan: TimeSpan{
					Start:    0,
					End:      100,
					Duration: 100,
					Ratio:    RatioThirty,
				},
				Amount: new(u256.Uint).SetUint64(100000),
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := calculatePeriodReward(tt.blockAmount, tt.timeSpan)
			uassert.Equal(t, tt.want.Start, got.Start)
			uassert.Equal(t, tt.want.End, got.End)
			uassert.Equal(t, tt.want.Duration, got.Duration)
			uassert.Equal(t, tt.want.Ratio, got.Ratio)
			uassert.True(t, tt.want.Amount.Eq(got.Amount))
		})
	}
}

func TestCalculator_AccumulateRewards(t *testing.T) {
	tests := []struct {
		name    string
		periods []RewardPeriod
		want    warmUpAmount
	}{
		{
			name: "accumulates rewards correctly for all ratios",
			periods: []RewardPeriod{
				{
					TimeSpan: TimeSpan{Ratio: RatioThirty},
					Amount:   new(u256.Uint).SetUint64(1000),
				},
				{
					TimeSpan: TimeSpan{Ratio: RatioFifty},
					Amount:   new(u256.Uint).SetUint64(1000),
				},
				{
					TimeSpan: TimeSpan{Ratio: RatioSeventy},
					Amount:   new(u256.Uint).SetUint64(1000),
				},
				{
					TimeSpan: TimeSpan{Ratio: RatioHundred},
					Amount:   new(u256.Uint).SetUint64(1000),
				},
			},
			want: warmUpAmount{
				full30:  1000,
				give30:  300,
				left30:  700,
				full50:  1000,
				give50:  500,
				left50:  500,
				full70:  1000,
				give70:  700,
				left70:  300,
				full100: 1000,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := accumulateRewards(tt.periods)

			uassert.Equal(t, tt.want.full30, got.full30)
			uassert.Equal(t, tt.want.give30, got.give30)
			uassert.Equal(t, tt.want.left30, got.left30)
			uassert.Equal(t, tt.want.full50, got.full50)
			uassert.Equal(t, tt.want.give50, got.give50)
			uassert.Equal(t, tt.want.left50, got.left50)
			uassert.Equal(t, tt.want.full70, got.full70)
			uassert.Equal(t, tt.want.give70, got.give70)
			uassert.Equal(t, tt.want.left70, got.left70)
			uassert.Equal(t, tt.want.full100, got.full100)
		})
	}
}

func TestCalculator_CalculateTimePeriods(t *testing.T) {
	warmUp = map[int64]int64{
		50:  150,
		70:  300,
		100: 900,
	}

	type testCase struct {
		name                 string
		currentHeight        int64
		stakedDuration       int64
		lastCalculatedHeight uint64
		expected             []TimeSpan
	}

	tests := []testCase{
		{
			name:                 "new stake - starts at 30% ratio",
			currentHeight:        1000,
			stakedDuration:       10,
			lastCalculatedHeight: 990,
			expected: []TimeSpan{
				{
					Start:    990,
					End:      1000,
					Duration: 10,
					Ratio:    RatioThirty,
				},
			},
		},
		{
			name:                 "transition from 30% to 50% ratio",
			currentHeight:        1000,
			stakedDuration:       200,
			lastCalculatedHeight: 800,
			expected: []TimeSpan{
				{
					Start:    800,
					End:      949, // warmUp[50] = 150, end exclusive
					Duration: 149,
					Ratio:    RatioThirty,
				},
				{
					Start:    950,
					End:      1000,
					Duration: 50,
					Ratio:    RatioFifty,
				},
			},
		},
		{
			name:                 "multiple transitions - 30% to 50% to 70%",
			currentHeight:        1000,
			stakedDuration:       400,
			lastCalculatedHeight: 600,
			expected: []TimeSpan{
				{
					Start:    600,
					End:      749, // warmUp[50] = 150
					Duration: 149,
					Ratio:    RatioThirty,
				},
				{
					Start:    750,
					End:      899, // warmUp[70] = 300
					Duration: 149,
					Ratio:    RatioFifty,
				},
				{
					Start:    900,
					End:      1000,
					Duration: 100,
					Ratio:    RatioSeventy,
				},
			},
		},
		{
			name:                 "very short duration - only 30%",
			currentHeight:        100,
			stakedDuration:       5,
			lastCalculatedHeight: 95,
			expected: []TimeSpan{
				{
					Start:    95,
					End:      100,
					Duration: 5,
					Ratio:    RatioThirty,
				},
			},
		},
		{
			name:                 "exactly at transition point - 50% to 70%",
			currentHeight:        1000,
			stakedDuration:       300, // exactly warmUp[70]
			lastCalculatedHeight: 700,
			expected: []TimeSpan{
				{
					Start:    700,
					End:      849, // warmUp[50] = 150
					Duration: 149,
					Ratio:    RatioThirty,
				},
				{
					Start:    850,
					End:      999,
					Duration: 149,
					Ratio:    RatioFifty,
				},
			},
		},
		{
			name:                 "last calculation at current height",
			currentHeight:        1000,
			stakedDuration:       100,
			lastCalculatedHeight: 1000,
			expected:             []TimeSpan{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			calculator := NewCalculator(1, "test")
			calculator.state.CurrentHeight = tt.currentHeight
			calculator.state.StakedOrExternalDuration = tt.stakedDuration
			calculator.lastCalcHeight = tt.lastCalculatedHeight

			periods := calculator.calculateTimePeriods()

			uassert.Equal(t, len(tt.expected), len(periods))

			for i, expectedPeriod := range tt.expected {
				actualPeriod := periods[i]
				uassert.Equal(t, expectedPeriod.Start, actualPeriod.Start)
				uassert.Equal(t, expectedPeriod.End, actualPeriod.End)
				uassert.Equal(t, expectedPeriod.Duration, actualPeriod.Duration)
				uassert.Equal(t, expectedPeriod.Ratio, actualPeriod.Ratio)
				// duration sanity check
				uassert.Equal(t, expectedPeriod.Duration, expectedPeriod.End-expectedPeriod.Start)
			}

			// period continuity check
			for i := 1; i < len(periods); i++ {
				prevPeriod := periods[i-1]
				currentPeriod := periods[i]

				uassert.Equal(t, prevPeriod.End, currentPeriod.Start-1)
				uassert.True(t, prevPeriod.Ratio < currentPeriod.Ratio)
			}
		})
	}
}

func TestCalculator_ComputeRewards(t *testing.T) {
	const milion = new(u256.Uint).SetUint64(1000000)
	const zero = new(u256.Uint).SetUint64(0)

	type testCase struct {
		name        string
		setup       func(*TestFixture)
		tokenId     uint64
		incentiveId string
		want        struct {
			full    uint64
			give    uint64
			wantErr bool
			errMsg  string
		}
	}

	tests := []testCase{
		{
			name: "error - token not found",
			setup: func(tf *TestFixture) {
				tf.setup()
				delete(positionExternal, tf.TokenId)
			},
			tokenId:     1,
			incentiveId: "test-incentive",
			want: struct {
				full    uint64
				give    uint64
				wantErr bool
				errMsg  string
			}{
				wantErr: true,
				errMsg:  "no externals found for token 1",
			},
		},
		{
			name: "error - incentive not found",
			setup: func(tf *TestFixture) {
				tf.setup()
				delete(positionExternal[tf.TokenId], tf.IncentiveId)
			},
			tokenId:     1,
			incentiveId: "test-incentive",
			want: struct {
				full    uint64
				give    uint64
				wantErr bool
				errMsg  string
			}{
				wantErr: true,
				errMsg:  "no external found for token 1 and incentive test-incentive",
			},
		},
		{
			name: "success - single period 30%",
			setup: func(tf *TestFixture) {
				tf.setup()
				baseHeight := int64(1000)

				tf.BlockHeight = baseHeight
				positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 100

				// configure durations
				tf.StakeTime = time.Now().Add(-10 * time.Minute).Unix()
				deposits[tf.TokenId] = Deposit{
					stakeTimestamp: tf.StakeTime,
					stakeHeight:    baseHeight - 100,
				}

				// set reward amount
				external := positionExternal[tf.TokenId][tf.IncentiveId]
				external.tokenAmountX96 = milion
				positionExternal[tf.TokenId][tf.IncentiveId] = external

				positionLastExternal[tf.TokenId][tf.IncentiveId] = zero
			},
			tokenId:     1,
			incentiveId: "test-incentive",
			want: struct {
				full    uint64
				give    uint64
				wantErr bool
				errMsg  string
			}{
				full:    1000000,
				give:    300000, // 30% of full amount
				wantErr: false,
			},
		},
		{
			name: "success - multiple periods",
			setup: func(tf *TestFixture) {
				tf.setup()
				baseHeight := int64(2000)

				// set current state
				tf.BlockHeight = baseHeight
				positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 400

				// configure for multiple periods
				tf.StakeTime = time.Now().Add(-24 * time.Hour).Unix()
				deposits[tf.TokenId] = Deposit{
					stakeTimestamp: tf.StakeTime,
					stakeHeight:    baseHeight - 400,
				}

				external := positionExternal[tf.TokenId][tf.IncentiveId]
				external.tokenAmountX96 = milion
				positionExternal[tf.TokenId][tf.IncentiveId] = external

				positionLastExternal[tf.TokenId][tf.IncentiveId] = zero
			},
			tokenId:     1,
			incentiveId: "test-incentive",
			want: struct {
				full    uint64
				give    uint64
				wantErr bool
				errMsg  string
			}{
				full:    2999878,
				give:    1499950,
				wantErr: false,
			},
		},
		{
			name: "success - max reward period",
			setup: func(tf *TestFixture) {
				tf.setup()
				baseHeight := int64(10000)

				// set current state for long duration
				tf.BlockHeight = baseHeight
				positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 1000

				tf.StakeTime = time.Now().Add(-100 * 24 * time.Hour).Unix()
				deposits[tf.TokenId] = Deposit{
					stakeTimestamp: tf.StakeTime,
					stakeHeight:    baseHeight - 1000,
				}

				external := positionExternal[tf.TokenId][tf.IncentiveId]
				external.tokenAmountX96 = milion
				positionExternal[tf.TokenId][tf.IncentiveId] = external

				positionLastExternal[tf.TokenId][tf.IncentiveId] = zero
			},
			tokenId:     1,
			incentiveId: "test-incentive",
			want: struct {
				full    uint64
				give    uint64
				wantErr bool
				errMsg  string
			}{
				full:    3999609,
				give:    2499761,
				wantErr: false,
			},
		},
		{
			name: "success - zero rewards",
			setup: func(tf *TestFixture) {
				tf.setup()
				baseHeight := int64(1000)

				// set current state
				tf.BlockHeight = baseHeight
				positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 100

				external := positionExternal[tf.TokenId][tf.IncentiveId]
				external.tokenAmountX96 = milion
				positionExternal[tf.TokenId][tf.IncentiveId] = external

				// set last external equal to current amount (no new rewards)
				positionLastExternal[tf.TokenId][tf.IncentiveId] = milion
			},
			tokenId:     1,
			incentiveId: "test-incentive",
			want: struct {
				full    uint64
				give    uint64
				wantErr bool
				errMsg  string
			}{
				full:    0,
				give:    0,
				wantErr: false,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tf := newTestFixture(t)
			tt.setup(tf)

			calculator := NewCalculator(tt.tokenId, tt.incentiveId)
			calculator.state.CurrentHeight = tf.BlockHeight
			full, give, err := calculator.ComputeRewards()

			if tt.want.wantErr {
				if err == nil {
					t.Fatalf("ComputeRewards returned no error")
				}
				if tt.want.errMsg != "" {
					uassert.Equal(t, tt.want.errMsg, err.Error())
				}
				return
			}

			if err != nil {
				t.Fatalf("ComputeRewards returned error: %v", err)
			}

			if full != tt.want.full || give != tt.want.give {
				t.Logf("\nTest case: %s", tt.name)
				t.Logf("Current Height: %d", calculator.state.CurrentHeight)
				t.Logf("Last Calc Height: %d", calculator.lastCalcHeight)
				t.Logf("Expected full: %d, got: %d", tt.want.full, full)
				t.Logf("Expected give: %d, got: %d", tt.want.give, give)
			}

			uassert.Equal(t, tt.want.full, full)
			uassert.Equal(t, tt.want.give, give)
		})
	}
}

func TestCalculator_UpdateWarmUpAmounts(t *testing.T) {

	type testCase struct {
		name        string
		setup       func()
		tokenId     uint64
		incentiveId string
		amount      warmUpAmount
		verify      func(*testing.T, uint64, string, warmUpAmount)
	}

	tests := []testCase{
		{
			name: "new token ID - creates map and updates amount",
			setup: func() {
				positionsExternalWarmUpAmount = make(map[uint64]map[string]warmUpAmount)
			},
			tokenId:     1,
			incentiveId: "test-incentive-1",
			amount: warmUpAmount{
				full30:  100,
				give30:  30,
				left30:  70,
				full50:  200,
				give50:  100,
				left50:  100,
				full70:  300,
				give70:  210,
				left70:  90,
				full100: 400,
			},
			verify: func(t *testing.T, tokenId uint64, incentiveId string, expected warmUpAmount) {
				// check map was created
				incentiveMap, exists := positionsExternalWarmUpAmount[tokenId]
				uassert.True(t, exists)
				if incentiveMap == nil {
					t.Fatalf("incentiveMap is nil")
				}

				// check amount was stored
				actual, exists := incentiveMap[incentiveId]
				uassert.True(t, exists)
				verifyWarmUpAmount(t, expected, actual)
			},
		},
		{
			name: "existing token ID - updates existing amount",
			setup: func() {
				positionsExternalWarmUpAmount = make(map[uint64]map[string]warmUpAmount)
				positionsExternalWarmUpAmount[2] = make(map[string]warmUpAmount)
				positionsExternalWarmUpAmount[2]["test-incentive-2"] = warmUpAmount{
					full30: 1,
					give30: 1,
				}
			},
			tokenId:     2,
			incentiveId: "test-incentive-2",
			amount: warmUpAmount{
				full30:  500,
				give30:  150,
				left30:  350,
				full50:  600,
				give50:  300,
				left50:  300,
				full70:  700,
				give70:  490,
				left70:  210,
				full100: 800,
			},
			verify: func(t *testing.T, tokenId uint64, incentiveId string, expected warmUpAmount) {
				actual := positionsExternalWarmUpAmount[tokenId][incentiveId]
				verifyWarmUpAmount(t, expected, actual)
			},
		},
		{
			name: "multiple incentives - maintains other incentives",
			setup: func() {
				positionsExternalWarmUpAmount = make(map[uint64]map[string]warmUpAmount)
				positionsExternalWarmUpAmount[3] = make(map[string]warmUpAmount)
				positionsExternalWarmUpAmount[3]["other-incentive"] = warmUpAmount{
					full30: 999,
					give30: 999,
				}
			},
			tokenId:     3,
			incentiveId: "test-incentive-3",
			amount: warmUpAmount{
				full30: 100,
				give30: 30,
			},
			verify: func(t *testing.T, tokenId uint64, incentiveId string, expected warmUpAmount) {
				// verify new incentive was added
				actual := positionsExternalWarmUpAmount[tokenId][incentiveId]
				verifyWarmUpAmount(t, expected, actual)

				// verify other incentive remained unchanged
				other := positionsExternalWarmUpAmount[tokenId]["other-incentive"]
				uassert.Equal(t, uint64(999), other.full30)
				uassert.Equal(t, uint64(999), other.give30)
			},
		},
		{
			name: "zero amounts - updates with zeros",
			setup: func() {
				positionsExternalWarmUpAmount = make(map[uint64]map[string]warmUpAmount)
			},
			tokenId:     4,
			incentiveId: "test-incentive-4",
			amount:      warmUpAmount{}, // All fields zero
			verify: func(t *testing.T, tokenId uint64, incentiveId string, expected warmUpAmount) {
				actual := positionsExternalWarmUpAmount[tokenId][incentiveId]
				verifyWarmUpAmount(t, expected, actual)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setup()

			calculator := NewCalculator(tt.tokenId, tt.incentiveId)
			calculator.updateWarmUpAmounts(tt.amount)

			tt.verify(t, tt.tokenId, tt.incentiveId, tt.amount)
		})
	}
}

func verifyWarmUpAmount(t *testing.T, expected, actual warmUpAmount) {
	t.Helper()
	uassert.Equal(t, expected.full30, actual.full30)
	uassert.Equal(t, expected.give30, actual.give30)
	uassert.Equal(t, expected.left30, actual.left30)
	uassert.Equal(t, expected.full50, actual.full50)
	uassert.Equal(t, expected.give50, actual.give50)
	uassert.Equal(t, expected.left50, actual.left50)
	uassert.Equal(t, expected.full70, actual.full70)
	uassert.Equal(t, expected.give70, actual.give70)
	uassert.Equal(t, expected.left70, actual.left70)
	uassert.Equal(t, expected.full100, actual.full100)
}

// technically this test is same as `TestCalculator_ComputeRewards` test. 
func TestRewardMathComputeExternalRewardAmount(t *testing.T) {
	const million = new(u256.Uint).SetUint64(1000000)
	const zero = new(u256.Uint).SetUint64(0)

	type wantData struct {
		full uint64
		give uint64
	}

	type testCase struct {
		name        string
		setup       func(*TestFixture)
		want        wantData
		expectPanic bool
	}

	tests := []testCase{
		{
			name: "panics when token not found",
			setup: func(tf *TestFixture) {
				tf.setup()
				delete(positionExternal, tf.TokenId)
			},
			want:        wantData{},
			expectPanic: true,
		},
		{
			name: "panics when incentive not found",
			setup: func(tf *TestFixture) {
				tf.setup()
				delete(positionExternal[tf.TokenId], tf.IncentiveId)
			},
			want:        wantData{},
			expectPanic: true,
		},
		{
			name: "success - single period 30%",
			setup: func(tf *TestFixture) {
				tf.setup()
				baseHeight := int64(1000)

				tf.BlockHeight = baseHeight
				positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 100

				// Configure durations
				tf.StakeTime = time.Now().Add(-10 * time.Minute).Unix()
				deposits[tf.TokenId] = Deposit{
					stakeTimestamp: tf.StakeTime,
					stakeHeight:    baseHeight - 100,
				}

				external := positionExternal[tf.TokenId][tf.IncentiveId]
				external.tokenAmountX96 = million
				positionExternal[tf.TokenId][tf.IncentiveId] = external

				positionLastExternal[tf.TokenId][tf.IncentiveId] = zero
			},
			want: wantData{
				full: 1000000,
				give: 300000, // 30% of full amount
			},
			expectPanic: false,
		},
		{
			name: "success - multiple periods",
			setup: func(tf *TestFixture) {
				tf.setup()
				baseHeight := int64(2000)

				tf.BlockHeight = baseHeight
				positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 400

				tf.StakeTime = time.Now().Add(-24 * time.Hour).Unix()
				deposits[tf.TokenId] = Deposit{
					stakeTimestamp: tf.StakeTime,
					stakeHeight:    baseHeight - 400,
				}

				external := positionExternal[tf.TokenId][tf.IncentiveId]
				external.tokenAmountX96 = million
				positionExternal[tf.TokenId][tf.IncentiveId] = external

				positionLastExternal[tf.TokenId][tf.IncentiveId] = zero
			},
			want: wantData{
				full: 2999878,
				give: 1499950,
			},
			expectPanic: false,
		},
		{
			name: "success - max reward period",
			setup: func(tf *TestFixture) {
				tf.setup()
				baseHeight := int64(10000)

				tf.BlockHeight = baseHeight
				positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 1000

				tf.StakeTime = time.Now().Add(-100 * 24 * time.Hour).Unix()
				deposits[tf.TokenId] = Deposit{
					stakeTimestamp: tf.StakeTime,
					stakeHeight:    baseHeight - 1000,
				}

				external := positionExternal[tf.TokenId][tf.IncentiveId]
				external.tokenAmountX96 = million
				positionExternal[tf.TokenId][tf.IncentiveId] = external

				positionLastExternal[tf.TokenId][tf.IncentiveId] = zero
			},
			want: wantData{
				full: 3999609,
				give: 2499761,
			},
			expectPanic: false,
		},
		{
			name: "success - zero rewards",
			setup: func(tf *TestFixture) {
				tf.setup()
				baseHeight := int64(1000)

				tf.BlockHeight = baseHeight
				positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 100

				external := positionExternal[tf.TokenId][tf.IncentiveId]
				external.tokenAmountX96 = million
				positionExternal[tf.TokenId][tf.IncentiveId] = external

				positionLastExternal[tf.TokenId][tf.IncentiveId] = million
			},
			want: wantData{
				full: 0,
				give: 0,
			},
			expectPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tf := newTestFixture(t)
			tt.setup(tf)

			if tt.expectPanic {
				panicked := testPanic(t, func() {
					rewardMathComputeExternalRewardAmount(tf.TokenId, tf.IncentiveId)
				})
				uassert.True(t, panicked)

				calculator := NewCalculator(tf.TokenId, tf.IncentiveId)
				calculator.state.CurrentHeight = tf.BlockHeight
				_, _, err := calculator.ComputeRewards()
				if err == nil {
					t.Fatalf("ComputeRewards returned no error")
				}
				return
			}

			oldFull, oldGive := rewardMathComputeExternalRewardAmount(tf.TokenId, tf.IncentiveId)

			calculator := NewCalculator(tf.TokenId, tf.IncentiveId)
			calculator.state.CurrentHeight = tf.BlockHeight

			newFull, newGive, err := calculator.ComputeRewards()
			if err != nil {
				t.Fatalf("ComputeRewards returned unexpected error: %v", err)
			}

			uassert.Equal(t, newFull, tt.want.full)
			uassert.Equal(t, newGive, tt.want.give)
		})
	}
}

func testPanic(t *testing.T, f func()) (panicked bool) {
	t.Helper()

	defer func() {
		if r := recover(); r != nil {
			panicked = true
		}
	}()
	f()
	return true
}
