package staker

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"

	sr "gno.land/r/gnoswap/staker"
)

// cacheInternalReward must NOT append global reward ratio accumulation checkpoints. That tree is
// maintained by modifyDeposit on liquidity changes; over a constant-liquidity span the accumulation for
// any timestamp is derived on demand. Repeated caching (per position reward calc / per emission
// distribution) therefore must not grow the tree, while emission caching (CurrentReward) still works
// and the on-demand accumulation stays correct (gas report issue 3).
func TestCacheInternalReward_DoesNotCheckpointGlobalAccumulation(cur realm, t *testing.T) {
	const createTime = int64(1000)

	type call struct {
		at       int64
		emission int64
	}
	tests := []struct {
		name             string
		stakeDelta       int64 // staked liquidity established via modifyDeposit at createTime (0 = none)
		calls            []call
		wantCurrentAt    int64
		wantCurrentValue int64  // expected CurrentReward at wantCurrentAt
		accQueryLiq      int64  // liquidity used to verify on-demand accumulation (0 = skip acc check)
		accQueryAt       int64  // timestamp for the accumulation check
		wantAccString    string // expected accumulation value at accQueryAt
	}{
		{
			name:       "constant positive liquidity: many caches, no accumulation growth",
			stakeDelta: 1000,
			calls: []call{
				{at: createTime + 100, emission: 500},
				{at: createTime + 200, emission: 500},
				{at: createTime + 300, emission: 700},
			},
			wantCurrentAt:    createTime + 300,
			wantCurrentValue: 700,
			accQueryLiq:      1000,
			accQueryAt:       createTime + 300,
			wantAccString:    u256.MulDiv(u256.NewUintFromInt64(300), q128, u256.NewUintFromInt64(1000)).ToString(),
		},
		{
			name:       "zero liquidity: caches never touch the accumulation tree",
			stakeDelta: 0,
			calls: []call{
				{at: createTime + 100, emission: 500},
				{at: createTime + 200, emission: 900},
			},
			wantCurrentAt:    createTime + 200,
			wantCurrentValue: 900,
			accQueryLiq:      0, // skip acc check (no liquidity established)
		},
		{
			name:       "repeated identical emission is cached once",
			stakeDelta: 1000,
			calls: []call{
				{at: createTime + 100, emission: 500},
				{at: createTime + 200, emission: 500},
			},
			wantCurrentAt:    createTime + 200,
			wantCurrentValue: 500,
			accQueryLiq:      1000,
			accQueryAt:       createTime + 200,
			wantAccString:    u256.MulDiv(u256.NewUintFromInt64(200), q128, u256.NewUintFromInt64(1000)).ToString(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			pool := sr.NewPool("test_pool", createTime)
			poolResolver := NewPoolResolver(pool)

			if tt.stakeDelta != 0 {
				poolResolver.modifyDeposit(i256.NewInt(tt.stakeDelta), createTime, 0)
			}

			sizeAfterStake := pool.GlobalRewardRatioAccumulation().Size()

			for _, c := range tt.calls {
				poolResolver.cacheReward(c.at, c.emission)
			}

			// cacheInternalReward wrote no global accumulation checkpoint.
			uassert.Equal(t, sizeAfterStake, pool.GlobalRewardRatioAccumulation().Size())

			// Emission caching itself still records the latest reward.
			uassert.Equal(t, tt.wantCurrentValue, poolResolver.CurrentReward(tt.wantCurrentAt))

			// The accumulation is still derived correctly on demand from the constant liquidity.
			if tt.accQueryLiq != 0 {
				acc := poolResolver.calculateGlobalRewardRatioAccumulation(tt.accQueryAt, u256.NewUintFromInt64(tt.accQueryLiq))
				uassert.Equal(t, tt.wantAccString, acc.ToString())
			}
		})
	}
}
