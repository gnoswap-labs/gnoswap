package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/gov/staker"
)

func newCloneTestDelegation() *staker.Delegation {
	return staker.NewDelegation(
		1,
		address("g1delegator"),
		address("g1delegatee"),
		1000,
		100,
		100,
	)
}

func TestCloneDelegationEntry(cur realm, t *testing.T) {
	t.Run("returns nil for a value that is not a delegation", func(cur realm, t *testing.T) {
		uassert.Equal(t, nil, cloneDelegationEntry("not a delegation"))
		uassert.Equal(t, nil, cloneDelegationEntry(nil))
	})

	t.Run("returns a copy the caller cannot write back through", func(cur realm, t *testing.T) {
		stored := newCloneTestDelegation()
		stored.SetCollectedAmount(300)

		cloned, ok := cloneDelegationEntry(stored).(*staker.Delegation)
		uassert.True(t, ok)
		uassert.False(t, cloned == stored)
		uassert.Equal(t, stored.CollectedAmount(), cloned.CollectedAmount())

		cloned.SetCollectedAmount(999)
		uassert.Equal(t, int64(300), stored.CollectedAmount())
	})

	t.Run("returns a distinct copy per read", func(cur realm, t *testing.T) {
		stored := newCloneTestDelegation()

		first, ok := cloneDelegationEntry(stored).(*staker.Delegation)
		uassert.True(t, ok)
		second, ok := cloneDelegationEntry(stored).(*staker.Delegation)
		uassert.True(t, ok)
		uassert.False(t, first == second)
	})
}

func TestCloneDelegationIDsEntry(cur realm, t *testing.T) {
	t.Run("returns nil for a value that is not an ID slice", func(cur realm, t *testing.T) {
		uassert.Equal(t, nil, cloneDelegationIDsEntry("not a slice"))
		uassert.Equal(t, nil, cloneDelegationIDsEntry([]string{"1"}))
		uassert.Equal(t, nil, cloneDelegationIDsEntry(nil))
	})

	t.Run("returns a copy the caller cannot write back through", func(cur realm, t *testing.T) {
		stored := []int64{1, 2, 3}

		cloned, ok := cloneDelegationIDsEntry(stored).([]int64)
		uassert.True(t, ok)
		uassert.Equal(t, len(stored), len(cloned))

		cloned[0] = 999
		uassert.Equal(t, int64(1), stored[0])
	})

	t.Run("preserves an empty slice", func(cur realm, t *testing.T) {
		cloned, ok := cloneDelegationIDsEntry([]int64{}).([]int64)
		uassert.True(t, ok)
		uassert.Equal(t, 0, len(cloned))
	})
}
