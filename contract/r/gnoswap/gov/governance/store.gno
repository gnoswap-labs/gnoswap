package governance

import (
	"strconv"

	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	// Core Proposal Management
	StoreKeyProposals      StoreKey = "proposals"      // AVL tree of all proposals by ID
	StoreKeyProposalNextID StoreKey = "proposalNextID" // Counter for next proposal ID

	// Configuration Management
	// StoreKeyConfigs           StoreKey = "configs"           // AVL tree of configs by version
	// StoreKeyConfigNextVersion StoreKey = "configNextVersion" // Counter for next config version

	// // User Association
	// StoreKeyProposalManager StoreKey = "proposalManager" // User-to-proposals mapping
)

type governanceStore struct {
	kvStore store.KVStore
}

// Proposal storage methods
func (s *governanceStore) HasProposalsStoreKey() bool {
	return s.kvStore.Has(StoreKeyProposals.String())
}

func (s *governanceStore) GetProposals() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyProposals.String())
	if err != nil {
		panic(err)
	}

	proposals, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return proposals
}

func (s *governanceStore) SetProposals(proposals *avl.Tree) error {
	return s.kvStore.Set(StoreKeyProposals.String(), proposals)
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

// func (s *governanceStore) HasProposal(proposalId uint64) bool {
// 	proposals := s.GetProposals()
// 	return proposals.Has(uint64ToString(proposalId))
// }

// func (s *governanceStore) GetProposal(proposalId uint64) (*Proposal, bool) {
// 	proposals := s.GetProposals()

// 	result, ok := proposals.Get(uint64ToString(proposalId))
// 	if !ok {
// 		return nil, false
// 	}

// 	proposal, ok := result.(*Proposal)
// 	if !ok {
// 		panic(ufmt.Sprintf("failed to cast result to *Proposal: %T", result))
// 	}

// 	return proposal, true
// }

// func (s *governanceStore) SetProposal(proposalId uint64, proposal *Proposal) error {
// 	if !s.HasProposalsStoreKey() {
// 		return errors.New("proposals store key not found")
// 	}

// 	proposals := s.GetProposals()
// 	proposals.Set(uint64ToString(proposalId), proposal)

// 	return nil
// }

// // Config storage methods
// func (s *governanceStore) HasConfigsStoreKey() bool {
// 	return s.kvStore.Has(StoreKeyConfigs.String())
// }

// func (s *governanceStore) GetConfigs() *avl.Tree {
// 	result, err := s.kvStore.Get(StoreKeyConfigs.String())
// 	if err != nil {
// 		panic(err)
// 	}

// 	configs, ok := result.(*avl.Tree)
// 	if !ok {
// 		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
// 	}

// 	return configs
// }

// func (s *governanceStore) SetConfigs(configs *avl.Tree) error {
// 	return s.kvStore.Set(StoreKeyConfigs.String(), configs)
// }

// func (s *governanceStore) HasConfigNextVersionStoreKey() bool {
// 	return s.kvStore.Has(StoreKeyConfigNextVersion.String())
// }

// func (s *governanceStore) GetConfigNextVersion() uint64 {
// 	result, err := s.kvStore.Get(StoreKeyConfigNextVersion.String())
// 	if err != nil {
// 		panic(err)
// 	}

// 	version, ok := result.(uint64)
// 	if !ok {
// 		panic(ufmt.Sprintf("failed to cast result to uint64: %T", result))
// 	}

// 	return version
// }

// func (s *governanceStore) SetConfigNextVersion(version uint64) error {
// 	return s.kvStore.Set(StoreKeyConfigNextVersion.String(), version)
// }

// func (s *governanceStore) HasConfig(version uint64) bool {
// 	configs := s.GetConfigs()
// 	return configs.Has(uint64ToString(version))
// }

// func (s *governanceStore) GetConfig(version uint64) (*Config, bool) {
// 	configs := s.GetConfigs()

// 	result, ok := configs.Get(uint64ToString(version))
// 	if !ok {
// 		return nil, false
// 	}

// 	config, ok := result.(*Config)
// 	if !ok {
// 		panic(ufmt.Sprintf("failed to cast result to *Config: %T", result))
// 	}

// 	return config, true
// }

// func (s *governanceStore) SetConfig(version uint64, config *Config) error {
// 	if !s.HasConfigsStoreKey() {
// 		return errors.New("configs store key not found")
// 	}

// 	configs := s.GetConfigs()
// 	configs.Set(uint64ToString(version), config)

// 	return nil
// }

// // Proposal manager storage methods
// func (s *governanceStore) HasProposalManagerStoreKey() bool {
// 	return s.kvStore.Has(StoreKeyProposalManager.String())
// }

// func (s *governanceStore) GetProposalManager() *ProposalManager {
// 	result, err := s.kvStore.Get(StoreKeyProposalManager.String())
// 	if err != nil {
// 		panic(err)
// 	}

// 	manager, ok := result.(*ProposalManager)
// 	if !ok {
// 		panic(ufmt.Sprintf("failed to cast result to *ProposalManager: %T", result))
// 	}

// 	return manager
// }

// func (s *governanceStore) SetProposalManager(manager *ProposalManager) error {
// 	return s.kvStore.Set(StoreKeyProposalManager.String(), manager)
// }

// // Voting info storage methods
// func (s *governanceStore) HasProposalVotesStoreKey() bool {
// 	return s.kvStore.Has(StoreKeyProposalVotes.String())
// }

// func (s *governanceStore) GetProposalVotes() *avl.Tree {
// 	result, err := s.kvStore.Get(StoreKeyProposalVotes.String())
// 	if err != nil {
// 		panic(err)
// 	}

// 	votes, ok := result.(*avl.Tree)
// 	if !ok {
// 		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
// 	}

// 	return votes
// }

// func (s *governanceStore) SetProposalVotes(votes *avl.Tree) error {
// 	return s.kvStore.Set(StoreKeyProposalVotes.String(), votes)
// }

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
