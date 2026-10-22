package dca_order

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256/v1"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestNextExecutionAfter(t *testing.T) {
	tests := []struct {
		name        string
		scheduledAt int64
		now         int64
		interval    int64
		want        int64
	}{
		{"on time", 1000, 1000, 60, 1060},
		{"slightly late keeps cadence", 1000, 1030, 60, 1060},
		{"exactly one slot late", 1000, 1060, 60, 1120},
		{"several slots late skips missed slots", 1000, 1210, 60, 1240},
		{"early call is defensive", 1000, 990, 60, 1060},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			uassert.Equal(t, tc.want, nextExecutionAfter(tc.scheduledAt, tc.now, tc.interval))
		})
	}
}

func TestOwedOutputRoundsDown(t *testing.T) {
	acc := u256.MulDiv(u256.NewUint(997), q128, u256.NewUint(1000))

	// A single participant loses at most one unit to rounding.
	uassert.Equal(t, int64(996), owedOutput(1000, acc, u256.Zero()))
	uassert.Equal(t, int64(0), owedOutput(1000, acc, acc))
	uassert.Equal(t, int64(0), owedOutput(0, acc, u256.Zero()))

	// Pro-rata shares never exceed the round output.
	shareA := owedOutput(400, acc, u256.Zero())
	shareB := owedOutput(600, acc, u256.Zero())
	uassert.True(t, shareA+shareB <= 997)
	uassert.True(t, 997-(shareA+shareB) <= 2)
}

func TestOwedOutputRejectsBackwardsAccumulator(cur realm, t *testing.T) {
	uassert.PanicsContains(t, cur, errInvalidState, func() {
		owedOutput(1, u256.Zero(), u256.One())
	})
}

func TestOwedOutputLargeValues(t *testing.T) {
	// Max int64 output per unit input across many rounds stays exact.
	acc := u256.Zero()
	for i := 0; i < 4; i++ {
		acc = u256.Zero().Add(acc, u256.MulDiv(u256.NewUint(1_000_000_000_000), q128, u256.NewUint(1)))
	}

	uassert.Equal(t, int64(4_000_000_000_000_000), owedOutput(1000, acc, u256.Zero()))
}

func TestMakeGroupIDAndIntervals(t *testing.T) {
	uassert.Equal(t, "a:b:500:1:60", makeGroupID("a:b:500", true, 60))
	uassert.Equal(t, "a:b:500:0:86400", makeGroupID("a:b:500", false, IntervalDay))

	for _, interval := range []int64{60, 3600, 86400, 604800, 2592000} {
		uassert.True(t, isAllowedInterval(interval))
	}

	for _, interval := range []int64{0, -60, 1, 120, 2678400} {
		uassert.False(t, isAllowedInterval(interval))
	}
}

func TestSettleableSplitsOversizedOutput(t *testing.T) {
	// 4 rounds of 2^62 output per unit input with rate 4 -> owed = 2^66.
	perUnit := u256.Zero().Lsh(u256.One(), 62)
	acc := u256.Zero().Mul(perUnit, q128)
	acc = u256.Zero().Mul(acc, u256.NewUint(4))

	payout, debt, done := settleable(4, acc, u256.Zero())
	uassert.Equal(t, int64(9223372036854775807), payout)
	uassert.False(t, done)
	uassert.True(t, debt.Lt(acc))

	total := u256.NewUint(uint64(payout))
	for i := 0; i < 10 && !done; i++ {
		payout, debt, done = settleable(4, acc, debt)
		total = u256.Zero().Add(total, u256.NewUint(uint64(payout)))
	}

	uassert.True(t, done)
	owed := owedOutputU256(4, acc, u256.Zero())
	uassert.True(t, total.Lte(owed), "paid more than accrued")
	diff := u256.Zero().Sub(owed, total)
	uassert.True(t, diff.Lt(u256.NewUint(16)), "split settlement lost more than rounding dust")
}

func TestSettleableSmallOutputIsExact(t *testing.T) {
	acc := u256.MulDiv(u256.NewUint(997), q128, u256.NewUint(1000))
	payout, debt, done := settleable(1000, acc, u256.Zero())
	uassert.Equal(t, int64(996), payout)
	uassert.True(t, done)
	uassert.True(t, debt.Eq(acc))
}
