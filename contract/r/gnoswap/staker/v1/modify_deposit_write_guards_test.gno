package staker

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"

	sr "gno.land/r/gnoswap/staker"
)

// modifyDeposit must append a StakedLiquidity entry only when the value actually changes.
// A zero-net-delta update (e.g. a balanced tick cross) must not grow the append-only tree, while a
// genuine change must be recorded (gas report issue 3, SetStakedLiquidityAt).
func TestModifyDeposit_StakedLiquidityWriteGuard(cur realm, t *testing.T) {
	const createTime = int64(1000)

	type op struct {
		delta int64
		at    int64
		tick  int32
	}
	tests := []struct {
		name               string
		ops                []op
		wantSize           int // includes the single zero entry NewPool seeds at createTime
		wantHasKeys        []int64
		wantFinalLiquidity string
	}{
		{
			name:               "no ops keeps only the initial entry",
			ops:                nil,
			wantSize:           1,
			wantFinalLiquidity: "0",
		},
		{
			name: "zero-delta updates never grow the tree",
			ops: []op{
				{delta: 0, at: createTime + 10, tick: 5},
				{delta: 0, at: createTime + 20, tick: 6},
			},
			wantSize:           1,
			wantFinalLiquidity: "0",
		},
		{
			name:               "single positive delta appends one entry",
			ops:                []op{{delta: 1000, at: createTime + 10, tick: 5}},
			wantSize:           2,
			wantHasKeys:        []int64{createTime + 10},
			wantFinalLiquidity: "1000",
		},
		{
			name: "zero-delta after a change does not grow",
			ops: []op{
				{delta: 1000, at: createTime + 10, tick: 5},
				{delta: 0, at: createTime + 20, tick: 6},
				{delta: 0, at: createTime + 30, tick: 7},
			},
			wantSize:           2,
			wantHasKeys:        []int64{createTime + 10},
			wantFinalLiquidity: "1000",
		},
		{
			name: "successive increases each append",
			ops: []op{
				{delta: 1000, at: createTime + 10, tick: 5},
				{delta: 500, at: createTime + 20, tick: 6},
			},
			wantSize:           3,
			wantHasKeys:        []int64{createTime + 10, createTime + 20},
			wantFinalLiquidity: "1500",
		},
		{
			name: "decrease back to zero appends",
			ops: []op{
				{delta: 1000, at: createTime + 10, tick: 5},
				{delta: -1000, at: createTime + 20, tick: 6},
			},
			wantSize:           3,
			wantHasKeys:        []int64{createTime + 10, createTime + 20},
			wantFinalLiquidity: "0",
		},
		{
			name: "alternating changes append every time",
			ops: []op{
				{delta: 1000, at: createTime + 10, tick: 1},
				{delta: -1000, at: createTime + 20, tick: 1},
				{delta: 1000, at: createTime + 30, tick: 1},
			},
			wantSize:           4,
			wantHasKeys:        []int64{createTime + 10, createTime + 20, createTime + 30},
			wantFinalLiquidity: "1000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			pool := sr.NewPool("test_pool", createTime)
			poolResolver := NewPoolResolver(pool)

			// NewPool seeds a single zero staked-liquidity entry at creation time.
			uassert.Equal(t, 1, pool.StakedLiquidity().Size())

			lastAt := createTime
			for _, o := range tt.ops {
				poolResolver.modifyDeposit(i256.NewInt(o.delta), o.at, o.tick)
				lastAt = o.at
			}

			uassert.Equal(t, tt.wantSize, pool.StakedLiquidity().Size())
			for _, key := range tt.wantHasKeys {
				uassert.True(t, pool.StakedLiquidity().Has(key))
			}
			uassert.Equal(t, tt.wantFinalLiquidity, poolResolver.CurrentStakedLiquidity(lastAt).ToString())
		})
	}
}

// modifyDeposit must reject a delta that would drive staked liquidity below zero.
func TestModifyDeposit_PanicsOnNegativeLiquidity(cur realm, t *testing.T) {
	const createTime = int64(1000)

	tests := []struct {
		name       string
		setupDelta int64 // applied first (0 means no setup)
		badDelta   int64
	}{
		{
			name:       "underflow from zero liquidity",
			setupDelta: 0,
			badDelta:   -1000,
		},
		{
			name:       "underflow below current liquidity",
			setupDelta: 500,
			badDelta:   -1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			pool := sr.NewPool("test_pool", createTime)
			poolResolver := NewPoolResolver(pool)

			if tt.setupDelta != 0 {
				poolResolver.modifyDeposit(i256.NewInt(tt.setupDelta), createTime+10, 0)
			}

			uassert.PanicsContains(t, cur, "underflow", func() {
				poolResolver.modifyDeposit(i256.NewInt(tt.badDelta), createTime+20, 0)
			})
		})
	}
}

// updateGlobalRewardRatioAccumulation must advance the checkpoint timestamp on every write, even when the
// value is unchanged (zero staked liquidity). Each entry doubles as a time checkpoint from which the next
// accumulation derives timeDiff, so a zero-liquidity span must be excluded from later accumulation.
func TestUpdateGlobalRewardRatioAccumulation_Checkpoint(cur realm, t *testing.T) {
	const createTime = int64(1000)

	type upd struct {
		at  int64
		liq int64
	}
	tests := []struct {
		name    string
		updates []upd // applied in order; timestamps strictly increasing
	}{
		{
			name: "zero-liquidity span is excluded from accumulation",
			updates: []upd{
				{at: createTime + 100, liq: 0},
				{at: createTime + 200, liq: 1000},
			},
		},
		{
			name: "constant positive liquidity accumulates linearly",
			updates: []upd{
				{at: createTime + 100, liq: 1000},
				{at: createTime + 200, liq: 1000},
			},
		},
		{
			name: "repeated zero-liquidity keeps advancing the checkpoint",
			updates: []upd{
				{at: createTime + 100, liq: 0},
				{at: createTime + 150, liq: 0},
				{at: createTime + 200, liq: 1000},
			},
		},
		{
			name: "varying liquidity sums per-segment accumulation",
			updates: []upd{
				{at: createTime + 100, liq: 1000},
				{at: createTime + 200, liq: 2000},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			pool := sr.NewPool("test_pool", createTime)
			poolResolver := NewPoolResolver(pool)

			// Independently reproduce the expected accumulation: each write advances the checkpoint, and a
			// segment contributes duration*q128/liquidity only when liquidity is positive.
			expected := u256.Zero()
			lastTime := createTime
			var lastReturned *u256.Uint

			for _, u := range tt.updates {
				lastReturned = poolResolver.updateGlobalRewardRatioAccumulation(u.at, u256.NewUintFromInt64(u.liq))
				if u.liq > 0 && u.at > lastTime {
					seg := u256.MulDiv(u256.NewUintFromInt64(u.at-lastTime), q128, u256.NewUintFromInt64(u.liq))
					expected = u256.Zero().Add(expected, seg)
				}
				lastTime = u.at
			}

			uassert.Equal(t, expected.ToString(), lastReturned.ToString())

			// The stored checkpoint is at the last write time and carries the same value.
			checkpointTime, checkpointAcc := poolResolver.CurrentGlobalRewardRatioAccumulation(lastTime)
			uassert.Equal(t, lastTime, checkpointTime)
			uassert.Equal(t, expected.ToString(), checkpointAcc)
		})
	}
}
