package staker

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"

	sr "gno.land/r/gnoswap/staker"
)

// Events must carry the global reward ratio accumulation *at* the event timestamp, not the latest
// stored checkpoint. Checkpoints are written exclusively by modifyDeposit, so on paths that do not
// change staked liquidity (CollectReward, out-of-range stake/unstake) the stored value lags behind by
// (eventTime - lastCheckpointTime) * q128 / stakedLiquidity. Off-chain indexers treat the emitted
// accumulator as authoritative at the event timestamp, so emitting the stored value silently drops the
// accumulation over that interval.
func TestGlobalRewardRatioAccumulationAt(cur realm, t *testing.T) {
	const createTime = int64(1000)

	ratio := func(seconds, liquidity int64) *u256.Uint {
		return u256.MulDiv(u256.NewUintFromInt64(seconds), q128, u256.NewUintFromInt64(liquidity))
	}

	accAfter300 := ratio(300, 1000)
	accAfter300Then200 := u256.Zero().Add(accAfter300, ratio(200, 2000))

	// deposit changes applied through modifyDeposit before the query, in order.
	type deposit struct {
		at    int64
		delta int64
	}

	tests := []struct {
		name string
		// deposits establish the staked liquidity timeline (and therefore the checkpoints).
		deposits []deposit
		queryAt  int64
		// wantStored is what the raw checkpoint lookup returns; wantDerived is the true accumulation.
		wantStored  string
		wantDerived string
	}{
		{
			name:        "constant liquidity: derived advances past a stale checkpoint",
			deposits:    []deposit{{at: createTime, delta: 1000}},
			queryAt:     createTime + 300,
			wantStored:  "0",
			wantDerived: accAfter300.ToString(),
		},
		{
			name:        "on the checkpoint timestamp: derived equals stored",
			deposits:    []deposit{{at: createTime, delta: 1000}},
			queryAt:     createTime,
			wantStored:  "0",
			wantDerived: "0",
		},
		{
			name:        "liquidity change resets the base: derived continues at the new liquidity",
			deposits:    []deposit{{at: createTime, delta: 1000}, {at: createTime + 300, delta: 1000}},
			queryAt:     createTime + 500,
			wantStored:  accAfter300.ToString(),
			wantDerived: accAfter300Then200.ToString(),
		},
		{
			name:        "zero staked liquidity never accumulates",
			deposits:    nil,
			queryAt:     createTime + 300,
			wantStored:  "0",
			wantDerived: "0",
		},
		{
			name:        "liquidity fully withdrawn: derived freezes at the last checkpoint",
			deposits:    []deposit{{at: createTime, delta: 1000}, {at: createTime + 300, delta: -1000}},
			queryAt:     createTime + 500,
			wantStored:  accAfter300.ToString(),
			wantDerived: accAfter300.ToString(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			pool := sr.NewPool("test_pool", createTime)
			poolResolver := NewPoolResolver(pool)

			for _, d := range tt.deposits {
				poolResolver.modifyDeposit(i256.NewInt(d.delta), d.at, 0)
			}

			_, stored := poolResolver.CurrentGlobalRewardRatioAccumulation(tt.queryAt)
			uassert.Equal(t, tt.wantStored, stored)

			derived, _ := poolResolver.globalRewardRatioAccumulationAt(tt.queryAt)
			uassert.Equal(t, tt.wantDerived, derived.ToString())
		})
	}
}

// The derived accumulation must agree with what reward calculation actually uses
// (CalculateRawRewardForPosition builds the position accumulator from the same derivation), so an
// emitted accumulator reproduces the on-chain reward math for off-chain consumers.
func TestGlobalRewardRatioAccumulationAt_MatchesRewardCalculationBase(cur realm, t *testing.T) {
	const createTime = int64(1000)

	pool := sr.NewPool("test_pool", createTime)
	poolResolver := NewPoolResolver(pool)
	poolResolver.modifyDeposit(i256.NewInt(1000), createTime, 0)

	for _, elapsed := range []int64{0, 1, 60, 3600, 86400} {
		at := createTime + elapsed

		want := poolResolver.calculateGlobalRewardRatioAccumulation(at, poolResolver.CurrentStakedLiquidity(at))
		got, _ := poolResolver.globalRewardRatioAccumulationAt(at)

		uassert.Equal(t, want.ToString(), got.ToString())
	}
}
