package governance

import (
	"errors"
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
	StoreKeyConfigCounter           StoreKey = "configCounter"           // Config version counter
	StoreKeyProposalCounter         StoreKey = "proposalCounter"         // Proposal ID counter
	StoreKeyConfigs                 StoreKey = "configs"                 // Configurations AVL tree
	StoreKeyProposals               StoreKey = "proposals"               // Proposals AVL tree
	StoreKeyProposalUserVotingInfos StoreKey = "proposalUserVotingInfos" // Proposal voting infos AVL tree
	StoreKeyUserProposals           StoreKey = "userProposals"           // User proposals mapping AVL tree
)

type governanceStore struct {
	kvStore store.KVStore
}

// Counter methods
func (s *governanceStore) HasConfigCounterStoreKey() bool {
	return s.kvStore.Has(StoreKeyConfigCounter.String())
}

func (s *governanceStore) GetConfigCounter() int64 {
	result, err := s.kvStore.Get(StoreKeyConfigCounter.String())
	if err != nil {
		panic(err)
	}

	counter, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return counter
}

func (s *governanceStore) SetConfigCounter(counter int64) error {
	return s.kvStore.Set(StoreKeyConfigCounter.String(), counter)
}

func (s *governanceStore) IncrementConfigCounter() (int64, error) {
	current := s.GetConfigCounter()
	next := current + 1
	err := s.SetConfigCounter(next)
	return next, err
}

func (s *governanceStore) HasProposalCounterStoreKey() bool {
	return s.kvStore.Has(StoreKeyProposalCounter.String())
}

func (s *governanceStore) GetProposalCounter() int64 {
	result, err := s.kvStore.Get(StoreKeyProposalCounter.String())
	if err != nil {
		panic(err)
	}

	counter, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return counter
}

func (s *governanceStore) SetProposalCounter(counter int64) error {
	return s.kvStore.Set(StoreKeyProposalCounter.String(), counter)
}

func (s *governanceStore) IncrementProposalCounter() (int64, error) {
	current := s.GetProposalCounter()
	next := current + 1
	err := s.SetProposalCounter(next)
	return next, err
}

// Configs methods
func (s *governanceStore) HasConfigsStoreKey() bool {
	return s.kvStore.Has(StoreKeyConfigs.String())
}

func (s *governanceStore) GetConfigs() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyConfigs.String())
	if err != nil {
		panic(err)
	}

	configs, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return configs
}

func (s *governanceStore) SetConfigs(configs *avl.Tree) error {
	return s.kvStore.Set(StoreKeyConfigs.String(), configs)
}

func (s *governanceStore) GetCurrentConfig() (Config, bool) {
	currentVersion := s.GetConfigCounter()
	return s.GetConfig(currentVersion)
}

func (s *governanceStore) GetConfig(version int64) (Config, bool) {
	configs := s.GetConfigs()
	result, ok := configs.Get(int64ToString(version))
	if !ok {
		return Config{}, false
	}

	config, ok := result.(Config)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to Config: %T", result))
	}

	return config, true
}

func (s *governanceStore) SetConfig(version int64, config Config) error {
	if !s.HasConfigsStoreKey() {
		return errors.New("configs store key not found")
	}

	configs := s.GetConfigs()
	configs.Set(int64ToString(version), config)

	return nil
}

// Proposals methods
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

func (s *governanceStore) GetProposal(proposalID int64) (interface{}, bool) {
	proposals := s.GetProposals()
	result, ok := proposals.Get(int64ToString(proposalID))
	if !ok {
		return nil, false
	}

	return result, true
}

func (s *governanceStore) SetProposal(proposalID int64, proposal interface{}) error {
	if !s.HasProposalsStoreKey() {
		return errors.New("proposals store key not found")
	}

	proposals := s.GetProposals()
	proposals.Set(int64ToString(proposalID), proposal)

	return nil
}

// Proposal User Voting Infos methods
func (s *governanceStore) HasProposalUserVotingInfosStoreKey() bool {
	return s.kvStore.Has(StoreKeyProposalUserVotingInfos.String())
}

func (s *governanceStore) GetProposalUserVotingInfos() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyProposalUserVotingInfos.String())
	if err != nil {
		panic(err)
	}

	votingInfos, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return votingInfos
}

func (s *governanceStore) SetProposalUserVotingInfos(votingInfos *avl.Tree) error {
	return s.kvStore.Set(StoreKeyProposalUserVotingInfos.String(), votingInfos)
}

func (s *governanceStore) GetProposalUserVotingInfosTree() *avl.Tree {
	return s.GetProposalUserVotingInfos()
}

func (s *governanceStore) GetProposalVotingInfos(proposalID int64) (interface{}, bool) {
	votingInfos := s.GetProposalUserVotingInfos()
	result, ok := votingInfos.Get(int64ToString(proposalID))
	if !ok {
		return nil, false
	}

	return result, true
}

func (s *governanceStore) SetProposalVotingInfos(proposalID int64, votingInfos interface{}) error {
	if !s.HasProposalUserVotingInfosStoreKey() {
		return errors.New("proposal user voting infos store key not found")
	}

	allVotingInfos := s.GetProposalUserVotingInfos()
	allVotingInfos.Set(int64ToString(proposalID), votingInfos)

	return nil
}

// User Proposals methods
func (s *governanceStore) HasUserProposalsStoreKey() bool {
	return s.kvStore.Has(StoreKeyUserProposals.String())
}

func (s *governanceStore) GetUserProposals() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyUserProposals.String())
	if err != nil {
		panic(err)
	}

	userProposals, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return userProposals
}

func (s *governanceStore) SetUserProposals(userProposals *avl.Tree) error {
	return s.kvStore.Set(StoreKeyUserProposals.String(), userProposals)
}

func (s *governanceStore) GetUserProposalsTree() *avl.Tree {
	return s.GetUserProposals()
}

func (s *governanceStore) GetUserProposalIDs(user string) ([]int64, bool) {
	userProposals := s.GetUserProposals()
	result, ok := userProposals.Get(user)
	if !ok {
		return nil, false
	}

	proposalIDs, ok := result.([]int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to []int64: %T", result))
	}

	return proposalIDs, true
}

func (s *governanceStore) AddUserProposal(user string, proposalID int64) error {
	if !s.HasUserProposalsStoreKey() {
		return errors.New("user proposals store key not found")
	}

	userProposals := s.GetUserProposals()

	// Get existing proposals for user
	var proposalIDs []int64
	if existing, ok := userProposals.Get(user); ok {
		proposalIDs = existing.([]int64)
	}

	// Add new proposal ID
	proposalIDs = append(proposalIDs, proposalID)
	userProposals.Set(user, proposalIDs)

	return nil
}

// NewGovernanceStore creates a new governance store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewGovernanceStore(kvStore store.KVStore) IGovernanceStore {
	return &governanceStore{
		kvStore: kvStore,
	}
}

func int64ToString(id int64) string {
	return strconv.FormatInt(id, 10)
}
