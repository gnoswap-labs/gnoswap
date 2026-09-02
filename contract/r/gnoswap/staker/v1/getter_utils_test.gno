package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	sr "gno.land/r/gnoswap/staker"
)

func newCloneTestExternalIncentive() *sr.ExternalIncentive {
	return sr.NewExternalIncentive(
		"incentive-1",
		"token0:token1:3000",
		"gno.land/r/onbloc/baz",
		1_000_000,
		100,
		3700,
		address("g1creator"),
		500_000_000,
		100,
		100,
	)
}

func TestCloneExternalIncentiveEntry(cur realm, t *testing.T) {
	t.Run("returns nil for a value that is not an incentive", func(cur realm, t *testing.T) {
		uassert.Equal(t, nil, cloneExternalIncentiveEntry("not an incentive"))
		uassert.Equal(t, nil, cloneExternalIncentiveEntry(nil))
	})

	t.Run("returns a copy the caller cannot write back through", func(cur realm, t *testing.T) {
		stored := newCloneTestExternalIncentive()

		cloned, ok := cloneExternalIncentiveEntry(stored).(*sr.ExternalIncentive)
		uassert.True(t, ok)
		uassert.False(t, cloned == stored)
		uassert.Equal(t, stored.RewardToken(), cloned.RewardToken())

		cloned.SetRewardToken("gno.land/r/onbloc/mutated")
		uassert.Equal(t, "gno.land/r/onbloc/baz", stored.RewardToken())
	})

	t.Run("returns a distinct copy per read", func(cur realm, t *testing.T) {
		stored := newCloneTestExternalIncentive()

		first, ok := cloneExternalIncentiveEntry(stored).(*sr.ExternalIncentive)
		uassert.True(t, ok)
		second, ok := cloneExternalIncentiveEntry(stored).(*sr.ExternalIncentive)
		uassert.True(t, ok)
		uassert.False(t, first == second)
	})
}
