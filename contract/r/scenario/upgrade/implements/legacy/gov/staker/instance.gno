package staker

import (
	"gno.land/r/gnoswap/gov/staker"
)

type govStakerV1 struct {
	store staker.IGovStakerStore
}

// NewGovStakerV1 creates the governance staker v1 implementation backed by store.
//
// Parameters:
//   - store: governance-staker storage interface used by the implementation.
//
// Returns:
//   - staker.IGovStaker: governance staker API backed by store.
func NewGovStakerV1(store staker.IGovStakerStore) staker.IGovStaker {
	return &govStakerV1{store}
}
