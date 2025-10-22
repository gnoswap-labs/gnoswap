package v1

import (
	"gno.land/r/gnoswap/gov/staker"
)

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