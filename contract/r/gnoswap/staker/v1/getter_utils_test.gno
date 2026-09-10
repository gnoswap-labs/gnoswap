package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	sr "gno.land/r/gnoswap/staker"
)

func newValueTestExternalIncentive() *sr.ExternalIncentive {
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

func TestExternalIncentiveValueEntry(cur realm, t *testing.T) {
	t.Run("returns nil for a value that is not an incentive", func(cur realm, t *testing.T) {
		uassert.Equal(t, nil, externalIncentiveValueEntry("not an incentive"))
		uassert.Equal(t, nil, externalIncentiveValueEntry(nil))
	})

	t.Run("returns a value copy the caller cannot write back through", func(cur realm, t *testing.T) {
		stored := newValueTestExternalIncentive()

		value, ok := externalIncentiveValueEntry(stored).(sr.ExternalIncentive)
		uassert.True(t, ok)
		uassert.Equal(t, stored.RewardToken(), value.RewardToken())

		value.SetRewardToken("gno.land/r/onbloc/mutated")
		uassert.Equal(t, "gno.land/r/onbloc/baz", stored.RewardToken())
	})
}
