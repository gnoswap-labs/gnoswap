package governance

import (
	"strconv"

	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/ufmt"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	// Governance state
	StoreKeyGovernanceState StoreKey = "governanceState" // Governance state
	StoreKeyProposalNextID StoreKey = "proposalNextID" // Counter for next proposal ID
)

type governanceStore struct {
	kvStore store.KVStore
}

// Governance state
func (s *governanceStore) HasGovernanceStateStoreKey() bool {
	return s.kvStore.Has(StoreKeyGovernanceState.String())
}

func (s *governanceStore) GetGovernanceState() GovernanceState {
	result, err := s.kvStore.Get(StoreKeyGovernanceState.String())
	if err != nil {
		panic(err)
	}

	governanceState, ok := result.(GovernanceState)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to GovernanceState: %T", result))
	}

	return governanceState
}

func (s *governanceStore) SetGovernanceState(governanceState GovernanceState) error {
	return s.kvStore.Set(StoreKeyGovernanceState.String(), governanceState)
}

func (s *governanceStore) HasProposalNextIDStoreKey() bool {
	return s.kvStore.Has(StoreKeyProposalNextID.String())
}

func (s *governanceStore) GetProposalNextID() uint64 {
	result, err := s.kvStore.Get(StoreKeyProposalNextID.String())
	if err != nil {
		panic(err)
	}

	nextID, ok := result.(uint64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to uint64: %T", result))
	}

	return nextID
}

func (s *governanceStore) SetProposalNextID(nextID uint64) error {
	return s.kvStore.Set(StoreKeyProposalNextID.String(), nextID)
}

// NewGovernanceStore creates a new governance store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewGovernanceStore(kvStore store.KVStore) IGovernanceStore {
	return &governanceStore{
		kvStore: kvStore,
	}
}

func uint64ToString(id uint64) string {
	return strconv.FormatUint(id, 10)
}
