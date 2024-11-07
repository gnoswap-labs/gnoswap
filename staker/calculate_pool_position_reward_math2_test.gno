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

func TestRewardMathComputeExternalRewardAmount(t *testing.T) {
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
			wantFull:    999999,
			wantGive:    699999,
		},
		{
			name: "success - 50% reward period", 
			setup: func(tf *TestFixture) {
				tf.setup()
				baseHeight := int64(1000)

				tf.BlockHeight = baseHeight
				positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 200

				tf.StakeTime = time.Now().Add(-24 * time.Hour).Unix()
				deposits[tf.TokenId] = Deposit{
					stakeTimestamp: tf.StakeTime,
					stakeHeight:    baseHeight - 200,
				}

				external := positionExternal[tf.TokenId][tf.IncentiveId]
				external.tokenAmountX96 = milion
				positionExternal[tf.TokenId][tf.IncentiveId] = external

				positionLastExternal[tf.TokenId][tf.IncentiveId] = zero
			},
			tokenId:     1,
			incentiveId: "test-incentive",
			wantFull:    999999,
			wantGive:    299999,
		},
		{
			name: "success - 70% reward period",
			setup: func(tf *TestFixture) {
				tf.setup()
				baseHeight := int64(1000)

				tf.BlockHeight = baseHeight
				positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 400

				tf.StakeTime = time.Now().Add(-48 * time.Hour).Unix()
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
			wantFull:    999999,
			wantGive:    299999,
		},
		{
			name: "success - transition from 30% to 50%",
			setup: func(tf *TestFixture) {
				tf.setup()
				baseHeight := int64(1000)

				tf.BlockHeight = baseHeight
				positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 160 // crosses threshold

				tf.StakeTime = time.Now().Add(-30 * time.Hour).Unix()
				deposits[tf.TokenId] = Deposit{
					stakeTimestamp: tf.StakeTime,
					stakeHeight:    baseHeight - 160,
				}

				external := positionExternal[tf.TokenId][tf.IncentiveId]
				external.tokenAmountX96 = milion
				positionExternal[tf.TokenId][tf.IncentiveId] = external

				positionLastExternal[tf.TokenId][tf.IncentiveId] = zero
			},
			tokenId:     1,
			incentiveId: "test-incentive",
			wantFull:    999999,
			wantGive:    299999,
		},
		{
			name: "success - transition from 50% to 70%",
			setup: func(tf *TestFixture) {
				tf.setup()
				baseHeight := int64(1000)

				tf.BlockHeight = baseHeight
				positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 310 // crosses threshold

				tf.StakeTime = time.Now().Add(-72 * time.Hour).Unix()
				deposits[tf.TokenId] = Deposit{
					stakeTimestamp: tf.StakeTime,
					stakeHeight:    baseHeight - 310,
				}

				external := positionExternal[tf.TokenId][tf.IncentiveId]
				external.tokenAmountX96 = milion
				positionExternal[tf.TokenId][tf.IncentiveId] = external

				positionLastExternal[tf.TokenId][tf.IncentiveId] = zero
			},
			tokenId:     1,
			incentiveId: "test-incentive",
			wantFull:    999999,
			wantGive:    299999,
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
			wantFull:    999999,
			wantGive:    299999,
		},
		{
			name: "success - immediately after staking",
			setup: func(tf *TestFixture) {
				tf.setup()
				baseHeight := int64(1000)

				tf.BlockHeight = baseHeight
				positionsExternalLastCalculatedHeight[tf.TokenId][tf.IncentiveId] = baseHeight - 1

				tf.StakeTime = time.Now().Add(-1 * time.Minute).Unix()
				deposits[tf.TokenId] = Deposit{
					stakeTimestamp: tf.StakeTime,
					stakeHeight:    baseHeight - 1,
				}

				external := positionExternal[tf.TokenId][tf.IncentiveId]
				external.tokenAmountX96 = milion
				positionExternal[tf.TokenId][tf.IncentiveId] = external

				positionLastExternal[tf.TokenId][tf.IncentiveId] = zero
			},
			tokenId:     1,
			incentiveId: "test-incentive",
			wantFull:    999999,
			wantGive:    299999,
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

            full, give := rewardMathComputeExternalRewardAmount2(tt.tokenId, tt.incentiveId)

            uassert.Equal(t, tt.wantFull, full)
            uassert.Equal(t, tt.wantGive, give)
        })
    }
}
