package v1

import (
	"gno.land/r/gnoswap/gov/staker"
	"gno.land/p/gnoswap/store"
)

// govStakerV1 implements IGovStaker interface
type govStakerV1 struct {
	store staker.IGovStakerStore
}

// NewGovStakerV1 creates a new instance of govStakerV1
func NewGovStakerV1(kv store.KVStore) staker.IGovStaker {
	return &govStakerV1{
		store: staker.NewGovStakerStore(kv),
	}
}

// getGovStakerState retrieves the current state
func (gs *govStakerV1) getGovStakerState() *GovStakerState {
	// This will be implemented when we migrate the state management
	return getGlobalState()
}