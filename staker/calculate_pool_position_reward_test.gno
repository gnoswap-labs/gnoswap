package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
)

type TestData struct {
	deposits                              map[uint64]Deposit
	positionsLiquidityRatio               map[uint64]*u256.Uint
	poolsPositions                        map[string][]uint64
	externalLastCalculatedTimestamp       map[string]int64
	positionLastExternal                  map[uint64]map[string]*u256.Uint
	positionsExternalLastCalculatedHeight map[uint64]map[string]int64
	positionsExternalWarmUpAmount         map[uint64]map[string]warmUpAmount
	positionExternal                      map[uint64]map[string]externalRewards
}

func setup(t *testing.T) TestData {
	t.Helper()
	return TestData{
		deposits:                              make(map[uint64]Deposit),
		positionsLiquidityRatio:               make(map[uint64]*u256.Uint),
		poolsPositions:                        make(map[string][]uint64),
		externalLastCalculatedTimestamp:       make(map[string]int64),
		positionLastExternal:                  make(map[uint64]map[string]*u256.Uint),
		positionsExternalLastCalculatedHeight: make(map[uint64]map[string]int64),
		positionsExternalWarmUpAmount:         make(map[uint64]map[string]warmUpAmount),
		positionExternal:                      make(map[uint64]map[string]externalRewards),
	}
}

func TestExternalCalculator_Active(t *testing.T) {
	tests := []struct {
		name string
		now  int64
		ictv ExternalIncentive
		want bool
	}{
		{
			name: "must active",
			now:  1000,
			ictv: ExternalIncentive{
				startTimestamp: 900,
				endTimestamp:   1100,
			},
			want: true,
		},
		{
			name: "incetives before start",
			now:  800,
			ictv: ExternalIncentive{
				startTimestamp: 900,
				endTimestamp:   1100,
			},
			want: false,
		},
		{
			name: "finished",
			now:  1200,
			ictv: ExternalIncentive{
				startTimestamp: 900,
				endTimestamp:   1100,
			},
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ec := &ExternalCalculator{now: tt.now}
			got := ec.active(tt.ictv)
			uassert.Equal(t, got, tt.want, ufmt.Sprintf("active() got = %v, want %v", got, tt.want))
		})
	}
}

func TestExternalCalculator_GetBlockPassed(t *testing.T) {
	baseTime := int64(1700000000)
	ec := &ExternalCalculator{
		height: 1000,
		now:    baseTime,
	}

	deposits = map[uint64]Deposit{
		1: {stakeTimestamp: baseTime - 1000}, // past
		2: {stakeTimestamp: baseTime - 500},  // more recent
		3: {stakeTimestamp: baseTime + 100},  // future
	}

	externalLastCalculatedTimestamp = map[string]int64{
		"incentive1": baseTime - 2000, // oldest
		"incentive2": baseTime - 100,  // more recent
		"incentive3": baseTime - 1500, // middle
	}

	tests := []struct {
		name           string
		tokenId        uint64
		incentiveId    string
		incentive      ExternalIncentive
		expectedBlocks int64
	}{
		{
			name:        "incentive start is oldest",
			tokenId:     1,
			incentiveId: "incentive1",
			incentive: ExternalIncentive{
				startTimestamp: baseTime - 800,
			},
			expectedBlocks: 400, // (now - startTimestamp) / 2 = (1700000000 - 1699999200) / 2 = 400
		},
		{
			name:        "staking is more recent",
			tokenId:     2,
			incentiveId: "incentive1",
			incentive: ExternalIncentive{
				startTimestamp: baseTime - 2000,
			},
			expectedBlocks: 250, // (now - stakeTimestamp) / 2 = (1700000000 - 1699999500) / 2 = 250
		},
		{
			name:        "last calculated is more recent",
			tokenId:     1,
			incentiveId: "incentive2",
			incentive: ExternalIncentive{
				startTimestamp: baseTime - 2000,
			},
			expectedBlocks: 50, // (now - lastCalculatedTimestamp) / 2 = (1700000000 - 1699999900) / 2 = 50
		},
		{
			name:        "future staking",
			tokenId:     3,
			incentiveId: "incentive1",
			incentive: ExternalIncentive{
				startTimestamp: baseTime - 2000,
			},
			expectedBlocks: -50, // future
		},
		{
			name:        "all time is future",
			tokenId:     3,
			incentiveId: "incentive1",
			incentive: ExternalIncentive{
				startTimestamp: baseTime + 200,
			},
			expectedBlocks: -100, // future
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ec.getBlockPassed(tt.tokenId, tt.incentiveId, tt.incentive)
			uassert.Equal(t, got, tt.expectedBlocks, ufmt.Sprintf("getBlockPassed() = %d, want %d", got, tt.expectedBlocks))
		})
	}
}

func TestExternalCalculator_Must(t *testing.T) {
	height := int64(100)
	ec := NewExternalCalculator(height)

	tests := []struct {
		name        string
		setup       func(td TestData)
		tokenId     uint64
		incentiveId string
		incentive   ExternalIncentive
		want        bool
	}{
		{
			name: "block not passed, must return false",
			setup: func(td TestData) {
				td.deposits[1] = Deposit{stakeTimestamp: ec.now}
				td.externalLastCalculatedTimestamp["ictv1"] = ec.now
			},
			tokenId:     1,
			incentiveId: "ictv1",
			incentive: ExternalIncentive{
				startTimestamp: ec.now,
				endTimestamp:   ec.now + 1000,
			},
			want: false,
		},
		{
			name: "liquidity ratio not exist, must return false",
			setup: func(td TestData) {
				td.deposits[2] = Deposit{stakeTimestamp: ec.now - 100}
				// positionsLiquidityRatio is empty
			},
			tokenId:     2,
			incentiveId: "ictv2",
			incentive: ExternalIncentive{
				startTimestamp: ec.now - 200,
				endTimestamp:   ec.now + 1000,
			},
			want: false,
		},
		{
			name: "liquidity ratio is zero, must return false",
			setup: func(td TestData) {
				td.deposits[3] = Deposit{stakeTimestamp: ec.now - 100}
				td.positionsLiquidityRatio[3] = u256.Zero()
			},
			tokenId:     3,
			incentiveId: "ictv3",
			incentive: ExternalIncentive{
				startTimestamp: ec.now - 200,
				endTimestamp:   ec.now + 1000,
			},
			want: false,
		},
		{
			name: "all conditions are met, must return true",
			setup: func(td TestData) {
				td.deposits[4] = Deposit{stakeTimestamp: ec.now - 100}
				td.positionsLiquidityRatio[4] = u256.NewUint(1000)
			},
			tokenId:     4,
			incentiveId: "ictv4",
			incentive: ExternalIncentive{
				startTimestamp: ec.now - 200,
				endTimestamp:   ec.now + 1000,
			},
			want: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			td := setup(t)

			tt.setup(td)

			deposits = td.deposits
			positionsLiquidityRatio = td.positionsLiquidityRatio
			externalLastCalculatedTimestamp = td.externalLastCalculatedTimestamp

			got := ec.must(tt.tokenId, tt.incentiveId, tt.incentive)
			uassert.Equal(t, got, tt.want, ufmt.Sprintf("must() = %t, want %t", got, tt.want))
		})
	}
}

func TestExternalCalculatorUpdatePositionRewards(t *testing.T) {
	type (
		externalRewardsMap map[string]externalRewards
		lastExternalMap    map[string]*u256.Uint
	)

	height := int64(100)
	ec := NewExternalCalculator(height)

	tests := []struct {
		name              string
		setup             func(td TestData)
		tokenId           uint64
		incentiveId       string
		incentive         ExternalIncentive
		positionAmountX96 *u256.Uint
		verify            func(t *testing.T, td TestData)
	}{
		{
			name: "create new position reward",
			setup: func(td TestData) {
				td.positionExternal[1] = make(externalRewardsMap)
				td.positionLastExternal[1] = make(lastExternalMap)
			},
			tokenId:     1,
			incentiveId: "ictv1",
			incentive: ExternalIncentive{
				targetPoolPath: "pool1",
				rewardToken:    "token1",
			},
			positionAmountX96: u256.NewUint(1000),
			verify: func(t *testing.T, td TestData) {
				// verify positionExternal
				reward, exist := td.positionExternal[1]["ictv1"]
				if !exist {
					t.Error("positionExternal entry should exist")
					return
				}
				uassert.Equal(t, reward.incentiveId, "ictv1", ufmt.Sprintf("incentiveId = %s, want %s", reward.incentiveId, "ictv1"))
				uassert.Equal(t, reward.poolPath, "pool1", ufmt.Sprintf("poolPath = %s, want %s", reward.poolPath, "pool1"))
				uassert.Equal(t, reward.tokenPath, "token1", ufmt.Sprintf("tokenPath = %s, want %s", reward.tokenPath, "token1"))
				uassert.True(
					t, reward.tokenAmountX96.Eq(u256.NewUint(1000)),
					ufmt.Sprintf(
						"tokenAmountX96 = %s, want %s",
						reward.tokenAmountX96.ToString(),
						u256.NewUint(1000).ToString(),
					),
				)

				// verify positionLastExternal
				lastAmount, exist := td.positionLastExternal[1]["ictv1"]
				if !exist {
					t.Error("positionLastExternal entry should exist")
					return
				}
				if !lastAmount.Eq(u256.NewUint(1000)) {
					t.Errorf("lastAmount = %v, want %v", lastAmount, u256.NewUint(1000))
				}
			},
		},
		{
			name: "update existing position reward",
			setup: func(td TestData) {
				// set existing reward
				td.positionExternal[2] = make(externalRewardsMap)
				td.positionExternal[2]["ictv2"] = externalRewards{
					incentiveId:    "ictv2",
					poolPath:       "pool2",
					tokenPath:      "token2",
					tokenAmountX96: u256.NewUint(1000),
				}
				td.positionLastExternal[2] = make(lastExternalMap)
				td.positionLastExternal[2]["ictv2"] = u256.NewUint(1000)
			},
			tokenId:     2,
			incentiveId: "ictv2",
			incentive: ExternalIncentive{
				targetPoolPath: "pool2",
				rewardToken:    "token2",
			},
			positionAmountX96: u256.NewUint(500),
			verify: func(t *testing.T, td TestData) {
				// verify positionExternal
				reward, exist := td.positionExternal[2]["ictv2"]
				uassert.True(t, exist, "positionExternal entry should exist")

				expectedAmount := u256.NewUint(1500) // 1000 + 500
				uassert.True(
					t, reward.tokenAmountX96.Eq(expectedAmount),
					ufmt.Sprintf(
						"tokenAmountX96 = %s, want %s",
						reward.tokenAmountX96.ToString(),
						expectedAmount.ToString(),
					),
				)

				// verify positionLastExternal
				lastAmount, exist := td.positionLastExternal[2]["ictv2"]
				uassert.True(t, lastAmount.Eq(u256.NewUint(1000)), ufmt.Sprintf("lastAmount = %s, want %s", lastAmount.ToString(), "1000"))
				uassert.True(t, exist, "positionLastExternal entry should exist")
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			td := setup(t)
			tt.setup(td)

			positionExternal = td.positionExternal
			positionLastExternal = td.positionLastExternal

			ec.updatePositionRewards(tt.tokenId, tt.incentiveId, tt.incentive, tt.positionAmountX96)

			tt.verify(t, td)
		})
	}
}
