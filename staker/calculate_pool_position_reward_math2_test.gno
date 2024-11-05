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
			currentHeight := std.GetHeight()
			calculator := NewCalculator(currentHeight, tt.tokenId, tt.incentiveId)

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

func TestAccumulateRewards(t *testing.T) {
	tests := []struct {
		name    string
		periods []RewardPeriod
		want    warmUpAmount
	}{
		{
			name: "single period with 30% ratio",
			periods: []RewardPeriod{
				{
					TimeSpan: TimeSpan{
						Start:    100,
						End:      200,
						Duration: 100,
						Ratio:    RatioThirty,
					},
					Amount: u256.NewUint(1000000).Mul(u256.NewUint(1000000), _q96),
				},
			},
			want: warmUpAmount{
				full30: 100000000,
				give30: 30000000,
				left30: 70000000,
			},
		},
		{
			name: "multiple periods with different ratios",
			periods: []RewardPeriod{
				{
					TimeSpan: TimeSpan{
						Start:    100,
						End:      200,
						Duration: 100,
						Ratio:    RatioThirty,
					},
					Amount: u256.NewUint(1000000).Mul(u256.NewUint(1000000), _q96),
				},
				{
					TimeSpan: TimeSpan{
						Start:    200,
						End:      300,
						Duration: 100,
						Ratio:    RatioFifty,
					},
					Amount: u256.NewUint(1000000).Mul(u256.NewUint(1000000), _q96),
				},
				{
					TimeSpan: TimeSpan{
						Start:    300,
						End:      400,
						Duration: 100,
						Ratio:    RatioSeventy,
					},
					Amount: u256.NewUint(1000000).Mul(u256.NewUint(1000000), _q96),
				},
			},
			want: warmUpAmount{
				full30: 100000000,
				give30: 30000000,
				left30: 70000000,
				full50: 100000000,
				give50: 50000000,
				left50: 50000000,
				full70: 100000000,
				give70: 70000000,
				left70: 30000000,
			},
		},
		{
			name: "single period with 100% ratio",
			periods: []RewardPeriod{
				{
					TimeSpan: TimeSpan{
						Start:    400,
						End:      500,
						Duration: 100,
						Ratio:    RatioHundred,
					},
					Amount: u256.NewUint(1000000).Mul(u256.NewUint(1000000), _q96),
				},
			},
			want: warmUpAmount{
				full100: 100000000,
			},
		},
		{
			name: "empty periods",
			periods: []RewardPeriod{},
			want: warmUpAmount{},
		},
		{
			name: "period with zero amount",
			periods: []RewardPeriod{
				{
					TimeSpan: TimeSpan{
						Start:    100,
						End:      200,
						Duration: 100,
						Ratio:    RatioFifty,
					},
					Amount: u256.NewUint(0),
				},
			},
			want: warmUpAmount{},
		},
		{
			name: "all ratios in sequence",
			periods: []RewardPeriod{
				{
					TimeSpan: TimeSpan{
						Start:    100,
						End:      200,
						Duration: 100,
						Ratio:    RatioThirty,
					},
					Amount: u256.NewUint(1000000).Mul(u256.NewUint(1000000), _q96),
				},
				{
					TimeSpan: TimeSpan{
						Start:    200,
						End:      300,
						Duration: 100,
						Ratio:    RatioFifty,
					},
					Amount: u256.NewUint(1000000).Mul(u256.NewUint(1000000), _q96),
				},
				{
					TimeSpan: TimeSpan{
						Start:    300,
						End:      400,
						Duration: 100,
						Ratio:    RatioSeventy,
					},
					Amount: u256.NewUint(1000000).Mul(u256.NewUint(1000000), _q96),
				},
				{
					TimeSpan: TimeSpan{
						Start:    400,
						End:      500,
						Duration: 100,
						Ratio:    RatioHundred,
					},
					Amount: u256.NewUint(1000000).Mul(u256.NewUint(1000000), _q96),
				},
			},
			want: warmUpAmount{
				full30:  100000000,
				give30:  30000000,
				left30:  70000000,
				full50:  100000000,
				give50:  50000000,
				left50:  50000000,
				full70:  100000000,
				give70:  70000000,
				left70:  30000000,
				full100: 100000000,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := accumulateRewards(tt.periods)
			
			if !got.Equal(tt.want) {
				t.Errorf("accumulateRewards() = %v, want %v", got, tt.want)
			}
		})
	}
}

func (w warmUpAmount) Equal(other warmUpAmount) bool {
	return w.full30 == other.full30 &&
		w.give30 == other.give30 &&
		w.left30 == other.left30 &&
		w.full50 == other.full50 &&
		w.give50 == other.give50 &&
		w.left50 == other.left50 &&
		w.full70 == other.full70 &&
		w.give70 == other.give70 &&
		w.left70 == other.left70 &&
		w.full100 == other.full100
}

func TestCalculator_CalculateTimePeriods(t *testing.T) {
	currentHeight := std.GetHeight()

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
			calculator := NewCalculator(currentHeight, 1, "test")
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

// TODO: fix
func TestCalculator_ComputeRewards(t *testing.T) {
	currentHeight := std.GetHeight()

	milion := new(u256.Uint).Mul(u256.NewUint(1000000), _q96)
	zero := new(u256.Uint).SetUint64(0)

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

                // 30%
                tf.StakeTime = time.Now().Add(-10 * time.Minute).Unix()
                deposits[tf.TokenId] = Deposit{
                    stakeTimestamp: tf.StakeTime,
                    stakeHeight:    baseHeight - 100,
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
                full:    100000000,
                give:    30000000, // 30% ratio
                wantErr: false,
            },
        },
        {
            name: "success - multiple periods (30%, 50%, 70%)",
            setup: func(tf *TestFixture) {
                tf.setup()
                baseHeight := int64(2000)

                tf.BlockHeight = baseHeight
                // start from 400 blocks ago
                positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 400

                // stake 24 hours ago
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
				// acc of 30% + 50% + 70%
                full:    397999998,
                give:    189199998,
                wantErr: false,
            },
        },
        {
            name: "success - max reward period (100%)",
            setup: func(tf *TestFixture) {
                tf.setup()
                baseHeight := int64(10000)

                tf.BlockHeight = baseHeight
                positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 1000

                // stake long enough to reach 100%
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
                full:    996999997,
                give:    638499997, // 100% instant
                wantErr: false,
            },
        },
        {
            name: "success - zero rewards",
            setup: func(tf *TestFixture) {
                tf.setup()
                baseHeight := int64(1000)

                tf.BlockHeight = baseHeight
                positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 100

                external := positionExternal[tf.TokenId][tf.IncentiveId]
                external.tokenAmountX96 = milion
                positionExternal[tf.TokenId][tf.IncentiveId] = external

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

            calculator := NewCalculator(currentHeight, tt.tokenId, tt.incentiveId)
            calculator.state.CurrentHeight = tf.BlockHeight
            full, give, err := calculator.computeRewards()

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
	currentHeight := std.GetHeight()

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

			calculator := NewCalculator(currentHeight, tt.tokenId, tt.incentiveId)
			calculator.updateWarmUpAmounts(tt.amount)

			tt.verify(t, tt.tokenId, tt.incentiveId, tt.amount)
		})
	}
}

func TestRewardMathComputeExternalRewardAmount(t *testing.T) {
	t.Skip("should be fix")
    milion := new(u256.Uint).Mul(u256.NewUint(1000000), _q96)
    zero := new(u256.Uint).SetUint64(0)

    tests := []struct {
        name        string
        setup       func(*TestFixture)
        tokenId     uint64
        incentiveId string
        wantFull    uint64
        wantGive    uint64
        wantPanic   bool
    }{
        {
            name: "panic - token not found",
            setup: func(tf *TestFixture) {
                tf.setup()
                delete(positionExternal, tf.TokenId)
            },
            tokenId:     1,
            incentiveId: "test-incentive",
            wantPanic:   true,
        },
        {
            name: "panic - incentive not found",
            setup: func(tf *TestFixture) {
                tf.setup()
                delete(positionExternal[tf.TokenId], tf.IncentiveId)
            },
            tokenId:     1,
            incentiveId: "test-incentive",
            wantPanic:   true,
        },
        {
            name: "success - 30% reward period",
            setup: func(tf *TestFixture) {
                tf.setup()
                baseHeight := int64(1000)

                tf.BlockHeight = baseHeight
                positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 100

                tf.StakeTime = time.Now().Add(-10 * time.Minute).Unix()
                deposits[tf.TokenId] = Deposit{
                    stakeTimestamp: tf.StakeTime,
                    stakeHeight:    baseHeight - 100,
                }

                external := positionExternal[tf.TokenId][tf.IncentiveId]
                external.tokenAmountX96 = milion
                positionExternal[tf.TokenId][tf.IncentiveId] = external

                positionLastExternal[tf.TokenId][tf.IncentiveId] = zero
            },
            tokenId:     1,
            incentiveId: "test-incentive",
            wantFull:    249999999,
            wantGive:    74999999,
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
                external.tokenAmountX96 = milion
                positionExternal[tf.TokenId][tf.IncentiveId] = external

                positionLastExternal[tf.TokenId][tf.IncentiveId] = zero
            },
            tokenId:     1,
            incentiveId: "test-incentive",
            wantFull:    996999997,
            wantGive:    638499997,
        },
        {
            name: "success - zero rewards",
            setup: func(tf *TestFixture) {
                tf.setup()
                baseHeight := int64(1000)

                tf.BlockHeight = baseHeight
                positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 100

                external := positionExternal[tf.TokenId][tf.IncentiveId]
                external.tokenAmountX96 = milion
                positionExternal[tf.TokenId][tf.IncentiveId] = external

                // no reward
                positionLastExternal[tf.TokenId][tf.IncentiveId] = milion
            },
            tokenId:     1,
            incentiveId: "test-incentive",
            wantFull:    0,
            wantGive:    0,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            tf := newTestFixture(t)
            tt.setup(tf)
            // std.TestSkipHeights(tf.BlockHeight) ???

            defer func() {
                if r := recover(); r != nil {
                    if !tt.wantPanic {
                        t.Errorf("unexpected panic: %v", r)
                    }
                    return
                }
                if tt.wantPanic {
                    t.Error("expected panic did not occur")
                }
            }()

            full, give := rewardMathComputeExternalRewardAmount(tt.tokenId, tt.incentiveId)

            if full != tt.wantFull || give != tt.wantGive {
                t.Logf("\nTest case: %s", tt.name)
                t.Logf("Expected full: %d, got: %d", tt.wantFull, full)
                t.Logf("Expected give: %d, got: %d", tt.wantGive, give)
                t.Fail()
            }

            uassert.Equal(t, tt.wantFull, full)
            uassert.Equal(t, tt.wantGive, give)
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