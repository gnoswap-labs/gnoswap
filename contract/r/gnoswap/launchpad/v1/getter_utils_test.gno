package launchpad

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/launchpad"
)

func TestCloneProjectEntry(cur realm, t *testing.T) {
	t.Run("returns nil for a value that is not a project", func(cur realm, t *testing.T) {
		uassert.Equal(t, nil, cloneProjectEntry("not a project"))
		uassert.Equal(t, nil, cloneProjectEntry(nil))
	})

	t.Run("returns a value copy the caller cannot write back through", func(cur realm, t *testing.T) {
		stored := launchpad.NewProject(
			"Test Project",
			"gno.land/r/onbloc/obl",
			1_000_000,
			address("g1recipient"),
			100,
			100,
		)
		stored.SetTier(30, launchpad.NewProjectTier("project", 30, 1, 100, 200))

		cloned, ok := cloneProjectEntry(*stored).(launchpad.Project)
		uassert.True(t, ok)
		uassert.Equal(t, stored.Name(), cloned.Name())

		cloned.SetName("Mutated")
		uassert.Equal(t, "Test Project", stored.Name())
		cloned.SetTier(30, launchpad.NewProjectTier("project", 30, 2, 100, 200))
		storedTier, err := stored.GetTier(30)
		uassert.NoError(t, err)
		uassert.Equal(t, int64(1), storedTier.TotalDistributeAmount())
	})

	t.Run("returns an independent value per read", func(cur realm, t *testing.T) {
		stored := launchpad.NewProject(
			"Test Project",
			"gno.land/r/onbloc/obl",
			1_000_000,
			address("g1recipient"),
			100,
			100,
		)

		first, ok := cloneProjectEntry(*stored).(launchpad.Project)
		uassert.True(t, ok)
		second, ok := cloneProjectEntry(*stored).(launchpad.Project)
		uassert.True(t, ok)

		first.SetName("Mutated")
		uassert.Equal(t, "Test Project", second.Name())
	})
}

func TestCloneRewardStateEntry(cur realm, t *testing.T) {
	t.Run("returns nil for a value that is not a reward state", func(cur realm, t *testing.T) {
		uassert.Equal(t, nil, cloneRewardStateEntry("not a reward state"))
		uassert.Equal(t, nil, cloneRewardStateEntry(nil))
	})

	t.Run("returns a copy the caller cannot write back through", func(cur realm, t *testing.T) {
		stored := launchpad.NewRewardState(u256.Zero(), 1_000_000, 100, 200, 300)

		cloned, ok := cloneRewardStateEntry(stored).(*launchpad.RewardState)
		uassert.True(t, ok)
		uassert.False(t, cloned == stored)
		uassert.Equal(t, stored.DepositAmount(), cloned.DepositAmount())

		cloned.SetDepositAmount(999)
		uassert.Equal(t, int64(1_000_000), stored.DepositAmount())
	})
}
