package protocol_fee

import (
	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/ufmt"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyProtocolFeeState StoreKey = "protocolFeeState" // Protocol fee state
)

type protocolFeeStore struct {
	kvStore store.KVStore
}

// GetProtocolFeeState retrieves the protocol fee state.
func (s *protocolFeeStore) GetProtocolFeeState() ProtocolFeeState {
	result, err := s.kvStore.Get(StoreKeyProtocolFeeState.String())
	if err != nil {
		panic(err)
	}

	protocolFeeState, ok := result.(ProtocolFeeState)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to ProtocolFeeState: %T", result))
	}

	return protocolFeeState
}

// SetProtocolFeeState stores the protocol fee state.
func (s *protocolFeeStore) SetProtocolFeeState(protocolFeeState ProtocolFeeState) error {
	return s.kvStore.Set(StoreKeyProtocolFeeState.String(), protocolFeeState)
}

// NewprotocolFeeStore creates a new protocol fee store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewprotocolFeeStore(kvStore store.KVStore) IProtocolFeeStore {
	return &protocolFeeStore{
		kvStore: kvStore,
	}
}
