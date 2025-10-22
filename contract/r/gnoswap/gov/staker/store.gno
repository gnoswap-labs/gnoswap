package staker

import (
	"gno.land/p/nt/ufmt"
	"gno.land/p/gnoswap/store"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyGovStakerState StoreKey = "govStakerState" // Gov staker state
)

type govStakerStore struct {
	kvStore store.KVStore
}

func (s *govStakerStore) HasGovStakerStateKey() bool {
	return s.kvStore.Has(StoreKeyGovStakerState.String())
}

// GetGovStakerState retrieves the gov staker state.
func (s *govStakerStore) GetGovStakerState() GovStakerState {
	result, err := s.kvStore.Get(StoreKeyGovStakerState.String())
	if err != nil {
		panic(err)
	}

	govStakerState, ok := result.(GovStakerState)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to GovStakerState: %T", result))
	}

	return govStakerState
}

// SetGovStakerState stores the gov staker state.
func (s *govStakerStore) SetGovStakerState(govStakerState GovStakerState) error {
	return s.kvStore.Set(StoreKeyGovStakerState.String(), govStakerState)
}

// NewGovStakerStore creates a new gov staker store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewGovStakerStore(kvStore store.KVStore) IGovStakerStore {
	return &govStakerStore{
		kvStore: kvStore,
	}
}
