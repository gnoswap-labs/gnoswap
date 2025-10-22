package v1

import (
	"gno.land/r/gnoswap/gov/staker"
)

// func init() {
// 	staker.RegisterInitializer(cross, InitializeV1)
// }

// func InitializeV1(store staker.IGovStakerStore) staker.IGovStaker {
// 	// Initialize state if not exists
// 	state := store.GetGovStakerState()
// 	if state == nil {
// 		// Create and set initial state
// 		initialState := NewGovStakerStateV1()
// 		store.SetGovStakerState(initialState)
// 	}
	
// 	return NewGovStakerV1(store)
// }

func init() {
	registerGovStakerV1()
}

func registerGovStakerV1() {
	staker.RegisterInitializer(cross, func(store staker.IGovStakerStore) staker.IGovStaker {
		err := initStoreData(store)
		if err != nil {
			panic(err)
		}

		return NewGovStakerV1(store)
	})
}

func initStoreData(store staker.IGovStakerStore) error {
	if !store.HasGovStakerStateKey() {
		return store.SetGovStakerState(NewGovStakerStateV1())
	}

	return nil
}