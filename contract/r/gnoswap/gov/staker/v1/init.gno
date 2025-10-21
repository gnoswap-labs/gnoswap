package v1

import (
	"gno.land/r/gnoswap/gov/staker"
	"gno.land/p/gnoswap/store"
)

const (
	packagePath = "gno.land/r/gnoswap/gov/staker/v1"
)

func init() {
	// Register v1 implementation
	staker.RegisterInitializer(packagePath, func() staker.IGovStaker {
		// Get KVStore from parent package
		kv := store.New()
		return NewGovStakerV1(kv)
	})
}