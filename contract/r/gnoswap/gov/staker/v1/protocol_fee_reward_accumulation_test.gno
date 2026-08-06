package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/gov/staker"
)

// updateAccumulatedProtocolFeeX128PerStake must persist only the tokens whose value actually changed,
// while always advancing the accumulated timestamp (gas report issue 1 / §1.2).
func TestUpdateAccumulatedProtocolFee(cur realm, t *testing.T) {
	type round struct {
		amounts map[string]int64
		at      int64
	}
	tests := []struct {
		name          string
		stake         int64
		rounds        []round
		wantAmounts   map[string]int64
		wantTimestamp int64
	}{
		{
			name:  "single round establishes all tokens",
			stake: 1000,
			rounds: []round{
				{amounts: map[string]int64{"token1": 1000, "token2": 2000}, at: 20},
			},
			wantAmounts:   map[string]int64{"token1": 1000, "token2": 2000},
			wantTimestamp: 20,
		},
		{
			name:  "second round updates only the changed token",
			stake: 1000,
			rounds: []round{
				{amounts: map[string]int64{"token1": 1000, "token2": 2000}, at: 20},
				{amounts: map[string]int64{"token1": 1000, "token2": 5000}, at: 30},
			},
			wantAmounts:   map[string]int64{"token1": 1000, "token2": 5000},
			wantTimestamp: 30,
		},
		{
			name:  "round with no new fees still advances the timestamp",
			stake: 1000,
			rounds: []round{
				{amounts: map[string]int64{"token1": 1000}, at: 20},
				{amounts: map[string]int64{"token1": 1000}, at: 30},
			},
			wantAmounts:   map[string]int64{"token1": 1000},
			wantTimestamp: 30,
		},
		{
			name:  "new token discovered in a later round",
			stake: 1000,
			rounds: []round{
				{amounts: map[string]int64{"token1": 1000}, at: 20},
				{amounts: map[string]int64{"token1": 1000, "token2": 500}, at: 30},
			},
			wantAmounts:   map[string]int64{"token1": 1000, "token2": 500},
			wantTimestamp: 30,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			manager := staker.NewProtocolFeeRewardManager()
			resolver := NewProtocolFeeRewardManagerResolver(manager)
			resolver.addStake("user1", tt.stake, 10)

			for _, r := range tt.rounds {
				err := resolver.updateAccumulatedProtocolFeeX128PerStake(r.amounts, r.at)
				uassert.NoError(t, err)
			}

			storedAmounts := manager.GetProtocolFeeAmounts()
			for token, want := range tt.wantAmounts {
				uassert.Equal(t, want, storedAmounts[token])
			}
			uassert.Equal(t, tt.wantTimestamp, manager.GetAccumulatedTimestamp())
		})
	}
}

// A token that receives no new fees in a round must keep its exact accumulator object (not be re-written),
// while a token with new fees advances. This is the core of the write-reduction optimization.
func TestUpdateAccumulatedProtocolFee_UnchangedTokenNotRewritten(cur realm, t *testing.T) {
	manager := staker.NewProtocolFeeRewardManager()
	resolver := NewProtocolFeeRewardManagerResolver(manager)
	resolver.addStake("user1", 1000, 10)

	err := resolver.updateAccumulatedProtocolFeeX128PerStake(map[string]int64{"token1": 1000, "token2": 2000}, 20)
	uassert.NoError(t, err)

	token1Before := manager.GetAccumulatedProtocolFeeX128PerStake("token1")
	token2Before := manager.GetAccumulatedProtocolFeeX128PerStake("token2")
	uassert.NotEqual(t, "0", token1Before.ToString())
	uassert.NotEqual(t, "0", token2Before.ToString())

	// Only token2 receives new fees.
	err = resolver.updateAccumulatedProtocolFeeX128PerStake(map[string]int64{"token1": 1000, "token2": 5000}, 30)
	uassert.NoError(t, err)

	token1After := manager.GetAccumulatedProtocolFeeX128PerStake("token1")
	token2After := manager.GetAccumulatedProtocolFeeX128PerStake("token2")

	// token1 was not re-written: same object instance and value preserved.
	if token1Before != token1After {
		t.Errorf("token1 accumulator was rewritten despite no new fees")
	}
	uassert.Equal(t, token1Before.ToString(), token1After.ToString())

	// token2 advanced.
	uassert.True(t, token2After.Gt(token2Before))
	uassert.Equal(t, int64(5000), manager.GetProtocolFeeAmounts()["token2"])
}

// updateAccumulatedProtocolFeeX128PerStake must be a no-op when called with a past timestamp.
func TestUpdateAccumulatedProtocolFee_PastTimestampNoOp(cur realm, t *testing.T) {
	manager := staker.NewProtocolFeeRewardManager()
	resolver := NewProtocolFeeRewardManagerResolver(manager)
	resolver.addStake("user1", 1000, 10)

	err := resolver.updateAccumulatedProtocolFeeX128PerStake(map[string]int64{"token1": 1000}, 20)
	uassert.NoError(t, err)
	token1Before := manager.GetAccumulatedProtocolFeeX128PerStake("token1")

	// Past timestamp: nothing changes.
	err = resolver.updateAccumulatedProtocolFeeX128PerStake(map[string]int64{"token1": 9999}, 10)
	uassert.NoError(t, err)

	uassert.Equal(t, token1Before.ToString(), manager.GetAccumulatedProtocolFeeX128PerStake("token1").ToString())
	uassert.Equal(t, int64(1000), manager.GetProtocolFeeAmounts()["token1"])
	uassert.Equal(t, int64(20), manager.GetAccumulatedTimestamp())
}

// addStake / removeStake reject invalid amounts.
func TestProtocolFeeStake_AmountErrors(cur realm, t *testing.T) {
	tests := []struct {
		name      string
		op        string // "add" | "remove"
		amount    int64
		wantError bool
	}{
		{name: "addStake rejects zero", op: "add", amount: 0, wantError: true},
		{name: "addStake rejects negative", op: "add", amount: -1, wantError: true},
		{name: "addStake accepts positive", op: "add", amount: 100, wantError: false},
		{name: "removeStake rejects negative", op: "remove", amount: -1, wantError: true},
		{name: "removeStake accepts zero", op: "remove", amount: 0, wantError: false},
		{name: "removeStake accepts positive", op: "remove", amount: 100, wantError: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			manager := staker.NewProtocolFeeRewardManager()
			resolver := NewProtocolFeeRewardManagerResolver(manager)
			// Seed a stake so removeStake has something to operate on.
			resolver.addStake("user1", 1000, 10)

			var err error
			switch tt.op {
			case "add":
				err = resolver.addStake("user1", tt.amount, 20)
			case "remove":
				err = resolver.removeStake("user1", tt.amount, 20)
			}

			if tt.wantError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// Claiming must skip tokens with no newly distributed fees (zero per-staker delta) without affecting
// correctness: a round with no new fees yields nothing, and only tokens that actually accrued fees are
// claimed (gas report issue 1 / §1.2). Rounds are applied sequentially to a single staker.
func TestProtocolFeeReward_ClaimSkipsZeroDeltaTokens(cur realm, t *testing.T) {
	type round struct {
		name     string
		amounts  map[string]int64 // cumulative distributed protocol-fee amounts by token
		updateAt int64
		claimAt  int64
		want     map[string]int64 // expected claimed amounts (absent key == 0)
	}
	rounds := []round{
		{
			name:     "first round: both tokens accrue and are claimed",
			amounts:  map[string]int64{"token1": 1000, "token2": 2000},
			updateAt: 20,
			claimAt:  30,
			want:     map[string]int64{"token1": 1000, "token2": 2000},
		},
		{
			name:     "no new fees: nothing to claim for any token",
			amounts:  map[string]int64{"token1": 1000, "token2": 2000},
			updateAt: 40,
			claimAt:  50,
			want:     map[string]int64{"token1": 0, "token2": 0},
		},
		{
			name:     "only token1 accrues: token2 (zero delta) is skipped",
			amounts:  map[string]int64{"token1": 3000, "token2": 2000},
			updateAt: 60,
			claimAt:  70,
			want:     map[string]int64{"token1": 2000, "token2": 0},
		},
	}

	manager := staker.NewProtocolFeeRewardManager()
	resolver := NewProtocolFeeRewardManagerResolver(manager)
	resolver.addStake("user1", 1000, 10)

	for _, r := range rounds {
		t.Run(r.name, func(cur realm, t *testing.T) {
			err := resolver.updateAccumulatedProtocolFeeX128PerStake(r.amounts, r.updateAt)
			uassert.NoError(t, err)

			claimed, err := resolver.claimRewards("user1", r.claimAt)
			uassert.NoError(t, err)

			// claimed[token] returns 0 for absent keys, so zero-delta tokens compare equal.
			for token, want := range r.want {
				uassert.Equal(t, want, claimed[token])
			}
		})
	}
}
