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
	StoreKeyDelegationSnapshots StoreKey = "delegationSnapshots" // Delegation snapshots
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

func (s *govStakerStore) HasDelegationSnapshotsKey() bool {
	return s.kvStore.Has(StoreKeyDelegationSnapshots.String())
}

func (s *govStakerStore) GetDelegationSnapshots() DelegationSnapshot {
	result, err := s.kvStore.Get(StoreKeyDelegationSnapshots.String())
	if err != nil {
		panic(err)
	}

	delegationSnapshot, ok := result.(DelegationSnapshot)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to DelegationSnapshot: %T", result))
	}

	return delegationSnapshot
}

func (s *govStakerStore) SetDelegationSnapshots(snapshot DelegationSnapshot) error {
	return s.kvStore.Set(StoreKeyDelegationSnapshots.String(), snapshot)
}

// NewGovStakerStore creates a new gov staker store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewGovStakerStore(kvStore store.KVStore) IGovStakerStore {
	return &govStakerStore{
		kvStore: kvStore,
	}
}
