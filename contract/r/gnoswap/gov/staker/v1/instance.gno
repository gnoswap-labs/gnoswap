package v1

import (
	"gno.land/r/gnoswap/gov/staker"
)

type govStakerV1 struct {
	store staker.IGovStakerStore
}

func NewGovStakerV1(store staker.IGovStakerStore) staker.IGovStaker {
	return &govStakerV1{
		store: store,
	}
}

// getState retrieves the current state from the store
func (g *govStakerV1) getState() *govStakerStateV1 {
	state := g.store.GetGovStakerState()
	if state == nil {
		// Initialize new state if it doesn't exist
		newState := NewGovStakerStateV1()
		g.store.SetGovStakerState(newState)
		return newState.(*govStakerStateV1)
	}
	return state.(*govStakerStateV1)
}

// setState updates the state in the store
func (g *govStakerV1) setState(state *govStakerStateV1) {
	g.store.SetGovStakerState(state)
}