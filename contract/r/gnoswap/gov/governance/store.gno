package governance

import (
	"errors"
	"strconv"

	"gno.land/p/gnoswap/store/v1"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

type StoreKey string

// String returns the storage-key text represented by s.
//
// Returns:
//   - string: underlying string used as the KV-store key
func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyConfigCounter   StoreKey = "configCounter"   // Config version counter
	StoreKeyProposalCounter StoreKey = "proposalCounter" // Proposal ID counter

	StoreKeyConfigs StoreKey = "configs" // Configurations BPTree

	StoreKeyProposals StoreKey = "proposals" // Proposals BPTree

	StoreKeyActiveProposalsBySnapshot StoreKey = "activeProposalsBySnapshot"

	StoreKeyProposalUserVotingInfos StoreKey = "proposalUserVotingInfos" // Proposal voting infos BPTree

	StoreKeyUserProposals StoreKey = "userProposals" // User proposals mapping BPTree
)

type governanceStore struct {
	kvStore store.KVStore
}

// Counter methods
// HasConfigCounterStoreKey reports whether the configuration-version counter
// is present in the KV store.
//
// Returns:
//   - bool: true when the configuration counter storage key exists
func (s *governanceStore) HasConfigCounterStoreKey() bool {
	return s.kvStore.Has(StoreKeyConfigCounter.String())
}

// GetConfigCounter retrieves the persisted configuration-version counter.
// Storage or type-cast failures panic.
//
// Returns:
//   - *Counter: counter stored under the configuration counter key
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

// SetConfigCounter persists the configuration-version counter after checking
// the supplied realm context.
//
// Parameters:
//   - _: leading integer discriminator for the authorized store call; callers pass 0
//   - rlm: propagated realm context; it must satisfy rlm.IsCurrent() or ErrSpoofedRealm is returned
//   - counter: counter value to persist under the configuration counter key
//
// Returns:
//   - error: nil when the counter is persisted; ErrSpoofedRealm or the KV-store write error otherwise
func (s *governanceStore) SetConfigCounter(_ int, rlm realm, counter *Counter) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyConfigCounter.String(), counter)
}

// HasProposalCounterStoreKey reports whether the proposal-ID counter is
// present in the KV store.
//
// Returns:
//   - bool: true when the proposal counter storage key exists
func (s *governanceStore) HasProposalCounterStoreKey() bool {
	return s.kvStore.Has(StoreKeyProposalCounter.String())
}

// GetProposalCounter retrieves the persisted proposal-ID counter.
// Storage or type-cast failures panic.
//
// Returns:
//   - *Counter: counter stored under the proposal counter key
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

// SetProposalCounter persists the proposal-ID counter after checking the
// supplied realm context.
//
// Parameters:
//   - _: leading integer discriminator for the authorized store call; callers pass 0
//   - rlm: propagated realm context; it must satisfy rlm.IsCurrent() or ErrSpoofedRealm is returned
//   - counter: counter value to persist under the proposal counter key
//
// Returns:
//   - error: nil when the counter is persisted; ErrSpoofedRealm or the KV-store write error otherwise
func (s *governanceStore) SetProposalCounter(_ int, rlm realm, counter *Counter) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyProposalCounter.String(), counter)
}

// Configs methods
// HasConfigsStoreKey reports whether the configurations tree is present in the
// KV store.
//
// Returns:
//   - bool: true when the configurations storage key exists
func (s *governanceStore) HasConfigsStoreKey() bool {
	return s.kvStore.Has(StoreKeyConfigs.String())
}

// GetConfigs retrieves the persisted configurations tree.
// Storage or type-cast failures panic.
//
// Returns:
//   - *bptree.BPTree: tree containing governance configurations keyed by version
func (s *governanceStore) GetConfigs() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyConfigs.String())
	if err != nil {
		panic(err)
	}

	configs, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return configs
}

// SetConfigs persists the configurations tree after checking the supplied
// realm context.
//
// Parameters:
//   - _: leading integer discriminator for the authorized store call; callers pass 0
//   - rlm: propagated realm context; it must satisfy rlm.IsCurrent() or ErrSpoofedRealm is returned
//   - configs: configurations tree to persist
//
// Returns:
//   - error: nil when the tree is persisted; ErrSpoofedRealm or the KV-store write error otherwise
func (s *governanceStore) SetConfigs(_ int, rlm realm, configs *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyConfigs.String(), configs)
}

// GetConfig retrieves one governance configuration by version.
// A missing version returns the zero Config and false.
//
// Parameters:
//   - version: configuration version used to form the tree key
//
// Returns:
//   - Config: configuration stored for version, or zero Config when absent
//   - bool: true when version was found; false when no configuration is stored
func (s *governanceStore) GetConfig(version int64) (Config, bool) {
	configs := s.GetConfigs()
	result := configs.Get(formatInt64Key(version))
	if result == nil {
		return Config{}, false
	}

	config, ok := result.(Config)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to Config: %T", result))
	}

	return config, true
}

// SetConfig stores config under version after checking the supplied realm
// context and the configurations storage key.
//
// Parameters:
//   - _: leading integer discriminator for the authorized store call; callers pass 0
//   - rlm: propagated realm context; it must satisfy rlm.IsCurrent() or ErrSpoofedRealm is returned
//   - version: configuration version used as the tree key
//   - config: configuration value to store for version
//
// Returns:
//   - error: nil when config is stored; an authorization, missing-key, or KV-store error otherwise
func (s *governanceStore) SetConfig(_ int, rlm realm, version int64, config Config) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if !s.HasConfigsStoreKey() {
		return errors.New("configs store key not found")
	}

	configs := s.GetConfigs()
	configs.Set(formatInt64Key(version), config)

	return s.kvStore.Set(0, rlm, StoreKeyConfigs.String(), configs)
}

// Proposals methods
// HasProposalsStoreKey reports whether the proposals tree is present in the KV
// store.
//
// Returns:
//   - bool: true when the proposals storage key exists
func (s *governanceStore) HasProposalsStoreKey() bool {
	return s.kvStore.Has(StoreKeyProposals.String())
}

// GetProposals retrieves the persisted proposals tree.
// Storage or type-cast failures panic.
//
// Returns:
//   - *bptree.BPTree: tree containing proposals keyed by formatted proposal ID
func (s *governanceStore) GetProposals() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyProposals.String())
	if err != nil {
		panic(err)
	}

	proposals, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return proposals
}

// SetProposals persists the proposals tree after checking the supplied realm
// context.
//
// Parameters:
//   - _: leading integer discriminator for the authorized store call; callers pass 0
//   - rlm: propagated realm context; it must satisfy rlm.IsCurrent() or ErrSpoofedRealm is returned
//   - proposals: proposals tree to persist
//
// Returns:
//   - error: nil when the tree is persisted; ErrSpoofedRealm or the KV-store write error otherwise
func (s *governanceStore) SetProposals(_ int, rlm realm, proposals *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyProposals.String(), proposals)
}

// GetProposal retrieves a proposal by its identifier.
// A missing entry or a value of the wrong type returns nil and false.
//
// Parameters:
//   - proposalID: proposal identifier used to form the tree key
//
// Returns:
//   - *Proposal: stored proposal, or nil when absent or not a Proposal
//   - bool: true when a Proposal was found at proposalID
func (s *governanceStore) GetProposal(proposalID int64) (*Proposal, bool) {
	proposals := s.GetProposals()
	result := proposals.Get(formatInt64Key(proposalID))
	if result == nil {
		return nil, false
	}

	proposal, ok := result.(*Proposal)
	if !ok {
		return nil, false
	}
	return proposal, true
}

// SetProposal stores proposal under proposalID after checking realm
// authorization, storage initialization, and ID consistency.
//
// Parameters:
//   - _: leading integer discriminator for the authorized store call; callers pass 0
//   - rlm: propagated realm context; it must satisfy rlm.IsCurrent() or ErrSpoofedRealm is returned
//   - proposalID: storage identifier that must equal proposal.ID()
//   - proposal: proposal value to persist; nil or an ID mismatch returns an error
//
// Returns:
//   - error: nil when stored; an authorization, missing-key, ID-mismatch, or KV-store error otherwise
func (s *governanceStore) SetProposal(_ int, rlm realm, proposalID int64, proposal *Proposal) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if !s.HasProposalsStoreKey() {
		return errors.New("proposals store key not found")
	}

	if proposal == nil || proposal.ID() != proposalID {
		return errors.New("proposal ID does not match the storage key")
	}

	proposals := s.GetProposals()
	proposals.Set(formatInt64Key(proposalID), proposal)

	return s.kvStore.Set(0, rlm, StoreKeyProposals.String(), proposals)
}

// HasActiveProposalsBySnapshotStoreKey reports whether the active-proposal
// snapshot index is present in the KV store.
//
// Returns:
//   - bool: true when the active snapshot index storage key exists
func (s *governanceStore) HasActiveProposalsBySnapshotStoreKey() bool {
	return s.kvStore.Has(StoreKeyActiveProposalsBySnapshot.String())
}

// GetActiveProposalsBySnapshot retrieves the active-proposal snapshot index.
// Storage or type-cast failures panic.
//
// Returns:
//   - *bptree.BPTree: tree indexing active proposals by snapshot key
func (s *governanceStore) GetActiveProposalsBySnapshot() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyActiveProposalsBySnapshot.String())
	if err != nil {
		panic(err)
	}
	tree, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast active proposal snapshot index: %T", result))
	}
	return tree
}

// SetActiveProposalsBySnapshot persists the active-proposal snapshot index
// after checking the supplied realm context.
//
// Parameters:
//   - _: leading integer discriminator for the authorized store call; callers pass 0
//   - rlm: propagated realm context; it must satisfy rlm.IsCurrent() or ErrSpoofedRealm is returned
//   - tree: active-proposal snapshot index tree to persist
//
// Returns:
//   - error: nil when the index is persisted; ErrSpoofedRealm or the KV-store write error otherwise
func (s *governanceStore) SetActiveProposalsBySnapshot(_ int, rlm realm, tree *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}
	return s.kvStore.Set(0, rlm, StoreKeyActiveProposalsBySnapshot.String(), tree)
}

// Proposal User Voting Infos methods
// HasProposalUserVotingInfosStoreKey reports whether the proposal voting-info
// index is present in the KV store.
//
// Returns:
//   - bool: true when the proposal voting-info storage key exists
func (s *governanceStore) HasProposalUserVotingInfosStoreKey() bool {
	return s.kvStore.Has(StoreKeyProposalUserVotingInfos.String())
}

// GetProposalUserVotingInfos retrieves the persisted proposal voting-info
// index tree. Storage or type-cast failures panic.
//
// Returns:
//   - *bptree.BPTree: tree mapping proposal IDs to per-user voting-info trees
func (s *governanceStore) GetProposalUserVotingInfos() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyProposalUserVotingInfos.String())
	if err != nil {
		panic(err)
	}

	votingInfos, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return votingInfos
}

// SetProposalUserVotingInfos persists the proposal voting-info index after
// checking the supplied realm context.
//
// Parameters:
//   - _: leading integer discriminator for the authorized store call; callers pass 0
//   - rlm: propagated realm context; it must satisfy rlm.IsCurrent() or ErrSpoofedRealm is returned
//   - votingInfos: proposal voting-info index tree to persist
//
// Returns:
//   - error: nil when the index is persisted; ErrSpoofedRealm or the KV-store write error otherwise
func (s *governanceStore) SetProposalUserVotingInfos(_ int, rlm realm, votingInfos *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyProposalUserVotingInfos.String(), votingInfos)
}

// GetProposalVotingInfos retrieves the per-user voting-info tree for a
// proposal. A missing entry or wrong type returns nil and false.
//
// Parameters:
//   - proposalID: proposal identifier used to select its voting-info tree
//
// Returns:
//   - *bptree.BPTree: per-user voting-info tree for proposalID, or nil when absent or invalid
//   - bool: true when a correctly typed voting-info tree was found
func (s *governanceStore) GetProposalVotingInfos(proposalID int64) (*bptree.BPTree, bool) {
	votingInfos := s.GetProposalUserVotingInfos()
	votingInfo := votingInfos.Get(formatInt64Key(proposalID))
	if votingInfo == nil {
		return nil, false
	}

	votingInfoTree, ok := votingInfo.(*bptree.BPTree)
	if !ok {
		return nil, false
	}

	return votingInfoTree, true
}

// SetProposalVotingInfos stores votingInfos under proposalID after checking
// realm authorization and index initialization.
//
// Parameters:
//   - _: leading integer discriminator for the authorized store call; callers pass 0
//   - rlm: propagated realm context; it must satisfy rlm.IsCurrent() or ErrSpoofedRealm is returned
//   - proposalID: proposal identifier used as the nested tree key
//   - votingInfos: per-user voting-info tree to store for proposalID
//
// Returns:
//   - error: nil when stored; an authorization, missing-key, or KV-store error otherwise
func (s *governanceStore) SetProposalVotingInfos(_ int, rlm realm, proposalID int64, votingInfos *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if !s.HasProposalUserVotingInfosStoreKey() {
		return errors.New("proposal user voting infos store key not found")
	}

	allVotingInfos := s.GetProposalUserVotingInfos()
	allVotingInfos.Set(formatInt64Key(proposalID), votingInfos)

	return s.kvStore.Set(0, rlm, StoreKeyProposalUserVotingInfos.String(), allVotingInfos)
}

// User Proposals methods
// HasUserProposalsStoreKey reports whether the user-to-proposals index is
// present in the KV store.
//
// Returns:
//   - bool: true when the user proposals storage key exists
func (s *governanceStore) HasUserProposalsStoreKey() bool {
	return s.kvStore.Has(StoreKeyUserProposals.String())
}

// GetUserProposals retrieves the persisted user-to-proposals index.
// Storage or type-cast failures panic.
//
// Returns:
//   - *bptree.BPTree: tree mapping user strings to proposal ID slices
func (s *governanceStore) GetUserProposals() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyUserProposals.String())
	if err != nil {
		panic(err)
	}

	userProposals, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return userProposals
}

// SetUserProposals persists the user-to-proposals index after checking the
// supplied realm context.
//
// Parameters:
//   - _: leading integer discriminator for the authorized store call; callers pass 0
//   - rlm: propagated realm context; it must satisfy rlm.IsCurrent() or ErrSpoofedRealm is returned
//   - userProposals: user-to-proposals index tree to persist
//
// Returns:
//   - error: nil when the index is persisted; ErrSpoofedRealm or the KV-store write error otherwise
func (s *governanceStore) SetUserProposals(_ int, rlm realm, userProposals *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyUserProposals.String(), userProposals)
}

// GetUserProposalIDs retrieves the proposal IDs indexed for user.
// A missing user returns nil and false; a wrong stored type panics.
//
// Parameters:
//   - user: user-string key in the user-to-proposals index
//
// Returns:
//   - []int64: proposal IDs currently indexed for user
//   - bool: true when user has an index entry; false when user is absent
func (s *governanceStore) GetUserProposalIDs(user string) ([]int64, bool) {
	userProposals := s.GetUserProposals()
	result := userProposals.Get(user)
	if result == nil {
		return nil, false
	}

	proposalIDs, ok := result.([]int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to []int64: %T", result))
	}

	return proposalIDs, true
}

// AddUserProposal appends proposalID to the IDs indexed for user and persists
// the updated user-to-proposals tree.
//
// Parameters:
//   - _: leading integer discriminator for the authorized store call; callers pass 0
//   - rlm: propagated realm context; it must satisfy rlm.IsCurrent() or ErrSpoofedRealm is returned
//   - user: user-string key whose proposal list is updated
//   - proposalID: proposal identifier to append to user's list
//
// Returns:
//   - error: nil when the list is persisted; an authorization, missing-key, or KV-store error otherwise
func (s *governanceStore) AddUserProposal(_ int, rlm realm, user string, proposalID int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if !s.HasUserProposalsStoreKey() {
		return errors.New("user proposals store key not found")
	}

	userProposals := s.GetUserProposals()

	// Get existing proposals for user
	var proposalIDs []int64
	if existing := userProposals.Get(user); existing != nil {
		var ok bool
		proposalIDs, ok = existing.([]int64)
		if !ok {
			panic(ufmt.Sprintf("failed to cast result to []int64: %T", existing))
		}
	}

	// Add new proposal ID
	proposalIDs = append(proposalIDs, proposalID)
	userProposals.Set(user, proposalIDs)

	return s.kvStore.Set(0, rlm, StoreKeyUserProposals.String(), userProposals)
}

// RemoveUserProposal removes every occurrence of proposalID from user's
// indexed proposal IDs and persists the resulting tree. Missing users are a
// no-op.
//
// Parameters:
//   - _: leading integer discriminator for the authorized store call; callers pass 0
//   - rlm: propagated realm context; it must satisfy rlm.IsCurrent() or ErrSpoofedRealm is returned
//   - user: user-string key whose proposal list is updated
//   - proposalID: proposal identifier to remove from the user's list
//
// Returns:
//   - error: nil when removed or already absent; an authorization, missing-key, or KV-store error otherwise
func (s *governanceStore) RemoveUserProposal(_ int, rlm realm, user string, proposalID int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if !s.HasUserProposalsStoreKey() {
		return errors.New("user proposals store key not found")
	}

	userProposals := s.GetUserProposals()
	proposalIDsRaw := userProposals.Get(user)
	// proposal already removed
	if proposalIDsRaw == nil {
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

	return s.kvStore.Set(0, rlm, StoreKeyUserProposals.String(), userProposals)
}

// NewGovernanceStore creates a governance store backed by the provided KV store.
// The returned interface is used by governance implementations and upgrades.
//
// Parameters:
//   - kvStore: KV store used for governance counters, trees, and records
//
// Returns:
//   - IGovernanceStore: governance store implementation backed by kvStore
func NewGovernanceStore(kvStore store.KVStore) IGovernanceStore {
	return &governanceStore{
		kvStore: kvStore,
	}
}

// formatInt64Key formats int64 identifiers for storage keys.
func formatInt64Key(id int64) string {
	return strconv.FormatInt(id, 10)
}
