package launchpad

import (
	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/ufmt"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyLaunchpadState StoreKey = "launchpadState" // Launchpad state
)

type launchpadStore struct {
	kvStore store.KVStore
}

// GetLaunchpadState retrieves the launchpad state.
func (s *launchpadStore) GetLaunchpadState() LaunchpadState {
	result, err := s.kvStore.Get(StoreKeyLaunchpadState.String())
	if err != nil {
		panic(err)
	}

	launchpadState, ok := result.(LaunchpadState)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to LaunchpadState: %T", result))
	}

	return launchpadState
}

// SetLaunchpadState stores the launchpad state.
func (s *launchpadStore) SetLaunchpadState(launchpadState LaunchpadState) error {
	return s.kvStore.Set(StoreKeyLaunchpadState.String(), launchpadState)
}

// NewLaunchpadStore creates a new launchpad store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewLaunchpadStore(kvStore store.KVStore) ILaunchpadStore {
	return &launchpadStore{
		kvStore: kvStore,
	}
}
