package governance

import (
	"errors"
	"strconv"
	"strings"

	"gno.land/p/gnoswap/store"
	avl "gno.land/p/nt/avl/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyConfigCounter   StoreKey = "configCounter"   // Config version counter
	StoreKeyProposalCounter StoreKey = "proposalCounter" // Proposal ID counter

	StoreKeyConfigs StoreKey = "configs" // Configurations AVL tree

	StoreKeyProposals StoreKey = "proposals" // Proposals AVL tree

	StoreKeyProposalUserVotingInfos   StoreKey = "proposalUserVotingInfos" // Proposal voting infos AVL tree
	StoreKeyProposalVotingInfosPrefix StoreKey = "proposalVotingInfos"     // Per-proposal voting infos keys

	StoreKeyUserProposals StoreKey = "userProposals" // User proposals mapping AVL tree
)

type governanceStore struct {
	kvStore store.KVStore
}

// Counter methods
func (s *governanceStore) HasConfigCounterStoreKey() bool {
	return s.kvStore.Has(StoreKeyConfigCounter.String())
}

func (s *governanceStore) GetConfigCounter() *Counter {
	result, err := s.kvStore.Get(StoreKeyConfigCounter.String())
	if err != nil {
		panic(err)
	}

	counter, ok := result.(*Counter)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *Counter: %T", result))
	}

	return counter
}

func (s *governanceStore) SetConfigCounter(counter *Counter) error {
	return s.kvStore.Set(StoreKeyConfigCounter.String(), counter)
}

func (s *governanceStore) HasProposalCounterStoreKey() bool {
	return s.kvStore.Has(StoreKeyProposalCounter.String())
}

func (s *governanceStore) GetProposalCounter() *Counter {
	result, err := s.kvStore.Get(StoreKeyProposalCounter.String())
	if err != nil {
		panic(err)
	}

	counter, ok := result.(*Counter)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return counter
}

func (s *governanceStore) SetProposalCounter(counter *Counter) error {
	return s.kvStore.Set(StoreKeyProposalCounter.String(), counter)
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

func (s *governanceStore) GetConfig(version int64) (Config, bool) {
	configs := s.GetConfigs()
	result, ok := configs.Get(formatInt64Key(version))
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
	configs.Set(formatInt64Key(version), config)

	return s.kvStore.Set(StoreKeyConfigs.String(), configs)
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

func (s *governanceStore) GetProposal(proposalID int64) (*Proposal, bool) {
	proposals := s.GetProposals()
	result, ok := proposals.Get(formatInt64Key(proposalID))
	if !ok {
		return nil, false
	}

	proposal, ok := result.(*Proposal)
	if !ok {
		return nil, false
	}
	return proposal, true
}

func (s *governanceStore) SetProposal(proposalID int64, proposal *Proposal) error {
	if !s.HasProposalsStoreKey() {
		return errors.New("proposals store key not found")
	}

	proposals := s.GetProposals()
	proposals.Set(formatInt64Key(proposalID), proposal)

	return s.kvStore.Set(StoreKeyProposals.String(), proposals)
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

	legacyVotingInfos, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	votingInfos := avl.NewTree()
	legacyVotingInfos.IterateByOffset(0, legacyVotingInfos.Size(), func(key string, value any) bool {
		votingInfos.Set(key, value)
		return false
	})

	proposalVotingInfoKeys, err := s.getProposalVotingInfoKeys()
	if err != nil {
		panic(err)
	}

	for _, proposalKey := range proposalVotingInfoKeys {
		proposalID, ok := parseProposalVotingInfosKey(proposalKey)
		if !ok {
			continue
		}

		proposalVotingInfos, exists := s.GetProposalVotingInfos(proposalID)
		if !exists {
			continue
		}

		votingInfos.Set(formatInt64Key(proposalID), proposalVotingInfos)
	}

	return votingInfos
}

func (s *governanceStore) SetProposalUserVotingInfos(votingInfos *avl.Tree) error {
	if err := s.kvStore.Set(StoreKeyProposalUserVotingInfos.String(), avl.NewTree()); err != nil {
		return err
	}

	proposalVotingInfoKeys, err := s.getProposalVotingInfoKeys()
	if err != nil {
		return err
	}

	for _, proposalKey := range proposalVotingInfoKeys {
		if err := s.kvStore.Delete(proposalKey); err != nil {
			return err
		}
	}

	if votingInfos == nil {
		return nil
	}

	votingInfos.IterateByOffset(0, votingInfos.Size(), func(key string, value any) bool {
		proposalVotingInfos, ok := value.(*avl.Tree)
		if !ok {
			panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", value))
		}

		if err := s.kvStore.Set(formatProposalVotingInfosKey(key), proposalVotingInfos); err != nil {
			panic(err)
		}

		return false
	})

	return nil
}

func (s *governanceStore) GetProposalVotingInfos(proposalID int64) (*avl.Tree, bool) {
	votingInfo, err := s.kvStore.Get(formatProposalVotingInfosKey(formatInt64Key(proposalID)))
	if err == nil {
		votingInfoTree, ok := votingInfo.(*avl.Tree)
		if !ok {
			return nil, false
		}

		return votingInfoTree, true
	}

	if !s.HasProposalUserVotingInfosStoreKey() {
		return nil, false
	}

	legacyVotingInfos, ok := s.mustGetProposalUserVotingInfosRaw().Get(formatInt64Key(proposalID))
	if !ok {
		return nil, false
	}

	votingInfoTree, ok := legacyVotingInfos.(*avl.Tree)
	if !ok {
		return nil, false
	}

	return votingInfoTree, true
}

func (s *governanceStore) SetProposalVotingInfos(proposalID int64, votingInfos *avl.Tree) error {
	if !s.HasProposalUserVotingInfosStoreKey() {
		return errors.New("proposal user voting infos store key not found")
	}

	return s.kvStore.Set(formatProposalVotingInfosKey(formatInt64Key(proposalID)), votingInfos)
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
		proposalIDs, ok = existing.([]int64)
		if !ok {
			panic(ufmt.Sprintf("failed to cast result to []int64: %T", existing))
		}
	}

	// Add new proposal ID
	proposalIDs = append(proposalIDs, proposalID)
	userProposals.Set(user, proposalIDs)

	return s.kvStore.Set(StoreKeyUserProposals.String(), userProposals)
}

func (s *governanceStore) RemoveUserProposal(user string, proposalID int64) error {
	if !s.HasUserProposalsStoreKey() {
		return errors.New("user proposals store key not found")
	}

	userProposals := s.GetUserProposals()
	proposalIDsRaw, ok := userProposals.Get(user)
	// proposal already removed
	if !ok {
		return nil
	}

	proposalIDs, ok := proposalIDsRaw.([]int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to []int64: %T", proposalIDs))
	}

	newProposalIDs := make([]int64, 0)

	for _, id := range proposalIDs {
		if id != proposalID {
			newProposalIDs = append(newProposalIDs, id)
		}
	}

	if len(newProposalIDs) == 0 {
		userProposals.Remove(user)
	} else {
		userProposals.Set(user, newProposalIDs)
	}

	return s.kvStore.Set(StoreKeyUserProposals.String(), userProposals)
}

// NewGovernanceStore creates a new governance store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewGovernanceStore(kvStore store.KVStore) IGovernanceStore {
	return &governanceStore{
		kvStore: kvStore,
	}
}

// formatInt64Key formats int64 identifiers for storage keys.
func formatInt64Key(id int64) string {
	return strconv.FormatInt(id, 10)
}

func formatProposalVotingInfosKey(proposalID string) string {
	return StoreKeyProposalVotingInfosPrefix.String() + ":" + proposalID
}

func (s *governanceStore) mustGetProposalUserVotingInfosRaw() *avl.Tree {
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

func parseProposalVotingInfosKey(key string) (int64, bool) {
	parts := strings.Split(key, ":")
	if len(parts) < 2 {
		return 0, false
	}

	prefixIndex := len(parts) - 2
	if parts[prefixIndex] != StoreKeyProposalVotingInfosPrefix.String() {
		return 0, false
	}

	proposalID, err := strconv.ParseInt(parts[len(parts)-1], 10, 64)
	if err != nil {
		return 0, false
	}

	return proposalID, true
}

func (s *governanceStore) getProposalVotingInfoKeys() ([]string, error) {
	keys, err := s.kvStore.GetAllKeys()
	if err != nil {
		return nil, err
	}

	proposalVotingInfoKeys := make([]string, 0)
	for _, key := range keys {
		if _, ok := parseProposalVotingInfosKey(key); !ok {
			continue
		}

		parts := strings.Split(key, ":")
		proposalVotingInfoKeys = append(proposalVotingInfoKeys, formatProposalVotingInfosKey(parts[len(parts)-1]))
	}

	return proposalVotingInfoKeys, nil
}
