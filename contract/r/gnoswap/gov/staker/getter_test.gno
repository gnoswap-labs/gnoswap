package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	bptree "gno.land/p/nt/bptree/v0"
	rotree "gno.land/p/nt/bptree/v0/rotree"
	uassert "gno.land/p/nt/uassert/v0"
)

func newDelegationWithdraw() DelegationWithdraw {
	return NewDelegationWithdraw(1, 100, 10, 20, 30)
}

func newDelegation() *Delegation {
	delegation := NewDelegation(1, adminAddr, adminAddr, 1000, 10, 20)
	delegation.SetUnDelegateAmount(200)
	delegation.SetCollectedAmount(300)
	delegation.SetWithdraws([]DelegationWithdraw{newDelegationWithdraw()})
	return delegation
}

func TestMutableGovStakerGetterIsolation(cur realm, t *testing.T) {
	tests := []struct {
		name      string
		setup     func(m *MockGovStaker)
		getter    func(cur realm, t *testing.T) any
		mutate    func(result any)
		assertRaw func(t *testing.T, m *MockGovStaker)
	}{
		{
			name: "GetUserDelegationIDs",
			setup: func(m *MockGovStaker) { m.Response.Set("GetUserDelegationIDs", []int64{3, 4}) },
			getter: func(cur realm, t *testing.T) any { return GetUserDelegationIDs(adminAddr, adminAddr) },
			mutate: func(result any) {
				values := result.([]int64)
				values[0] = 88
				_ = append(values, 89)
			},
			assertRaw: func(t *testing.T, m *MockGovStaker) {
				values := m.Response.data["GetUserDelegationIDs"][0].([]int64)
				uassert.Equal(t, int64(3), values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name: "GetClaimableRewardByAddress",
			setup: func(m *MockGovStaker) { m.Response.Set("GetClaimableRewardByAddress", int64(10), map[string]int64{"foo": 1}) },
			getter: func(cur realm, t *testing.T) any {
				_, rewards, err := GetClaimableRewardByAddress(adminAddr)
				uassert.NoError(t, err)
				return rewards
			},
			mutate: func(result any) {
				rewards := result.(map[string]int64)
				rewards["foo"] = 99
				rewards["bar"] = 100
			},
			assertRaw: func(t *testing.T, m *MockGovStaker) {
				rewards := m.Response.data["GetClaimableRewardByAddress"][1].(map[string]int64)
				uassert.Equal(t, int64(1), rewards["foo"])
				_, ok := rewards["bar"]
				uassert.Equal(t, false, ok)
			},
		},
		{
			name: "GetClaimableRewardByLaunchpad",
			setup: func(m *MockGovStaker) { m.Response.Set("GetClaimableRewardByLaunchpad", int64(10), map[string]int64{"foo": 1}) },
			getter: func(cur realm, t *testing.T) any {
				_, rewards, err := GetClaimableRewardByLaunchpad(adminAddr)
				uassert.NoError(t, err)
				return rewards
			},
			mutate: func(result any) {
				rewards := result.(map[string]int64)
				rewards["foo"] = 99
				rewards["bar"] = 100
			},
			assertRaw: func(t *testing.T, m *MockGovStaker) {
				rewards := m.Response.data["GetClaimableRewardByLaunchpad"][1].(map[string]int64)
				uassert.Equal(t, int64(1), rewards["foo"])
				_, ok := rewards["bar"]
				uassert.Equal(t, false, ok)
			},
		},
		{
			name: "GetClaimableRewardByRewardID",
			setup: func(m *MockGovStaker) { m.Response.Set("GetClaimableRewardByRewardID", int64(10), map[string]int64{"foo": 1}) },
			getter: func(cur realm, t *testing.T) any {
				_, rewards, err := GetClaimableRewardByRewardID("reward-1")
				uassert.NoError(t, err)
				return rewards
			},
			mutate: func(result any) {
				rewards := result.(map[string]int64)
				rewards["foo"] = 99
				rewards["bar"] = 100
			},
			assertRaw: func(t *testing.T, m *MockGovStaker) {
				rewards := m.Response.data["GetClaimableRewardByRewardID"][1].(map[string]int64)
				uassert.Equal(t, int64(1), rewards["foo"])
				_, ok := rewards["bar"]
				uassert.Equal(t, false, ok)
			},
		},
		{
			name: "GetProtocolFeeAccumulatedX128PerStake",
			setup: func(m *MockGovStaker) { m.Response.Set("GetProtocolFeeAccumulatedX128PerStake", u256.MustFromDecimal("1000")) },
			getter: func(cur realm, t *testing.T) any { return GetProtocolFeeAccumulatedX128PerStake("token") },
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("2000")) },
			assertRaw: func(t *testing.T, m *MockGovStaker) {
				value := m.Response.data["GetProtocolFeeAccumulatedX128PerStake"][0].(*u256.Uint)
				uassert.Equal(t, "1000", value.ToString())
			},
		},
		{
			name: "GetEmissionAccumulatedX128PerStake",
			setup: func(m *MockGovStaker) { m.Response.Set("GetEmissionAccumulatedX128PerStake", u256.MustFromDecimal("3000")) },
			getter: func(cur realm, t *testing.T) any { return GetEmissionAccumulatedX128PerStake() },
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("4000")) },
			assertRaw: func(t *testing.T, m *MockGovStaker) {
				value := m.Response.data["GetEmissionAccumulatedX128PerStake"][0].(*u256.Uint)
				uassert.Equal(t, "3000", value.ToString())
			},
		},
		{
			name: "GetDelegationWithdraws",
			setup: func(m *MockGovStaker) { m.Response.Set("GetDelegationWithdraws", []DelegationWithdraw{newDelegationWithdraw()}, nil) },
			getter: func(cur realm, t *testing.T) any {
				withdraws, err := GetDelegationWithdraws(1, 0, 10)
				uassert.NoError(t, err)
				return withdraws
			},
			mutate: func(result any) {
				withdraws := result.([]DelegationWithdraw)
				withdraws[0].SetCollected(true)
				withdraws[0].SetCollectedAt(999)
				withdraws[0].SetCollectedAmount(888)
			},
			assertRaw: func(t *testing.T, m *MockGovStaker) {
				withdraws := m.Response.data["GetDelegationWithdraws"][0].([]DelegationWithdraw)
				uassert.Equal(t, false, withdraws[0].IsCollected())
				uassert.Equal(t, int64(0), withdraws[0].CollectedAt())
				uassert.Equal(t, int64(0), withdraws[0].CollectedAmount())
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			mockGovStaker := newMockGovStaker("v1")
			implementation = mockGovStaker
			tt.setup(mockGovStaker)
			result := tt.getter(cur, t)
			tt.mutate(result)
			tt.assertRaw(t, mockGovStaker)
		})
	}
}

func TestReadOnlyTreeGetters(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		method   string
		getter   func() *rotree.ReadOnlyTree
		wantKeys []string
	}{
		{
			name:     "GetDelegations",
			method:   "GetDelegations",
			getter:   func() *rotree.ReadOnlyTree { return GetDelegations() },
			wantKeys: []string{"1", "2"},
		},
		{
			name:     "GetDelegatorDelegations",
			method:   "GetDelegatorDelegations",
			getter:   func() *rotree.ReadOnlyTree { return GetDelegatorDelegations(adminAddr) },
			wantKeys: []string{adminAddr.String()},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			mockGovStaker := newMockGovStaker("v1")
			implementation = mockGovStaker

			stored := bptree.NewBPTree32()
			for i, key := range tt.wantKeys {
				stored.Set(key, i)
			}
			mockGovStaker.Response.Set(tt.method, rotree.Wrap(stored, nil))

			got := tt.getter()
			uassert.Equal(t, len(tt.wantKeys), got.Size())

			keys := make([]string, 0, got.Size())
			got.IterateByOffset(0, got.Size(), func(key string, _ any) bool {
				keys = append(keys, key)
				return false
			})
			for i, want := range tt.wantKeys {
				uassert.Equal(t, want, keys[i])
			}

			// The view refuses writes, so the stored tree stays untouched.
			uassert.PanicsWithMessage(t, cur, "Set operation not supported on ReadOnlyTree", func() {
				got.Set("mutated", 0)
			})
			uassert.PanicsWithMessage(t, cur, "Remove operation not supported on ReadOnlyTree", func() {
				got.Remove(tt.wantKeys[0])
			})
			uassert.Equal(t, len(tt.wantKeys), stored.Size())
		})
	}
}

func TestReadOnlyTreeGetters_NoImplementationResponse(cur realm, t *testing.T) {
	resetTestState(t)
	mockGovStaker := newMockGovStaker("v1")
	implementation = mockGovStaker

	uassert.True(t, GetDelegations() == nil)
	uassert.True(t, GetDelegatorDelegations(adminAddr) == nil)
}
