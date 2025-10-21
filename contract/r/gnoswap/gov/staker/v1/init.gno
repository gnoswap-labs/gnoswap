package v1

import (
	"gno.land/r/gnoswap/gov/staker"
)

func init() {
	staker.RegisterInitializer(cross, InitializeV1)
}

func InitializeV1(store staker.IGovStakerStore) staker.IGovStaker {
	return NewGovStakerV1(store)
}