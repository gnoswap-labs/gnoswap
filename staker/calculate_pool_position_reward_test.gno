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
	deposits                            map[uint64]Deposit
	positionsLiquidityRatio            map[uint64]*u256.Uint
	poolsPositions                      map[string][]uint64
	externalLastCalculatedTimestamp     map[string]int64
	positionLastExternal               map[uint64]map[string]*u256.Uint
	positionsExternalLastCalculatedHeight map[uint64]map[string]int64
	positionsExternalWarmUpAmount       map[uint64]map[string]warmUpAmount
	positionExternal                    map[uint64]map[string]externalRewards
}

func setup(t *testing.T) TestData {
	t.Helper()
	return TestData{
		deposits:                            make(map[uint64]Deposit),
		positionsLiquidityRatio:            make(map[uint64]*u256.Uint),
		poolsPositions:                      make(map[string][]uint64),
		externalLastCalculatedTimestamp:     make(map[string]int64),
		positionLastExternal:               make(map[uint64]map[string]*u256.Uint),
		positionsExternalLastCalculatedHeight: make(map[uint64]map[string]int64),
		positionsExternalWarmUpAmount:       make(map[uint64]map[string]warmUpAmount),
		positionExternal:                    make(map[uint64]map[string]externalRewards),
	}
}

func TestExternalCalculator_Active(t *testing.T) {
	tests := []struct {
		name string
		now int64
		ictv ExternalIncentive
		want bool
	}{
		{
			name: "must active",
			now: 1000,
			ictv: ExternalIncentive{
				startTimestamp: 900,
				endTimestamp: 1100,
			},
			want: true,
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