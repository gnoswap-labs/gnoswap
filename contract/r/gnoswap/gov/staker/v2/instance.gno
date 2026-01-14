package v2

import (
	"gno.land/r/gnoswap/gov/staker"
)

type govStakerV1 struct {
	store staker.IGovStakerStore
}

func NewGovStakerV1(store staker.IGovStakerStore) staker.IGovStaker {
	return &govStakerV1{ store }
}
