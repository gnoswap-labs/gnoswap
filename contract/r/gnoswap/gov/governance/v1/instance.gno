package governance

import (
	"gno.land/p/gnoswap/utils"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/gov/governance"
)

type governanceV1 struct {
	store          governance.IGovernanceStore
	stakerAccessor governance.GovStakerAccessor
}

// NewGovernanceV1 creates a governance v1 implementation backed by the supplied
// state store and staker voting-weight accessor.
//
// Parameters:
//   - governanceStore: persistence adapter for configuration, proposals, counters, and voting information
//   - stakerAccessor: accessor that supplies delegation snapshots and total xGNS supply for governance decisions
//
// Returns:
//   - governance.IGovernance: governance manager and getter implementation using the supplied dependencies
func NewGovernanceV1(
	governanceStore governance.IGovernanceStore,
	stakerAccessor governance.GovStakerAccessor,
) governance.IGovernance {
	return &governanceV1{
		store:          governanceStore,
		stakerAccessor: stakerAccessor,
	}
}

// Config version methods
// getCurrentConfigVersion returns the version number held by the configuration
// counter in persistent governance state.
//
// Returns:
//   - int64: current configuration version counter value
func (g *governanceV1) getCurrentConfigVersion() int64 {
	return g.store.GetConfigCounter().Get()
}

// nextConfigVersion increments and persists the config counter. It mutates the
// underlying KV store, so it requires a realm value that resolves to the
// governance proxy realm (the only writer-permitted address).
//
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
//   - rlm: propagated current realm context validated by the store before persisting the counter
//
// Returns:
//   - int64: newly allocated configuration version
func (g *governanceV1) nextConfigVersion(_ int, rlm realm) int64 {
	counter := g.store.GetConfigCounter()
	next := counter.Next()
	if err := g.store.SetConfigCounter(0, rlm, counter); err != nil {
		panic(err)
	}
	return next
}

// Proposal ID methods
// getCurrentProposalID returns the proposal identifier held by the persistent
// proposal counter.
//
// Returns:
//   - int64: current proposal ID counter value
func (g *governanceV1) getCurrentProposalID() int64 {
	return g.store.GetProposalCounter().Get()
}

// nextProposalID increments and persists the proposal counter. Same realm
// rules as nextConfigVersion.
//
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
//   - rlm: propagated current realm context validated by the store before persisting the counter
//
// Returns:
//   - int64: newly allocated proposal ID
func (g *governanceV1) nextProposalID(_ int, rlm realm) int64 {
	counter := g.store.GetProposalCounter()
	next := counter.Next()
	if err := g.store.SetProposalCounter(0, rlm, counter); err != nil {
		panic(err)
	}
	return next
}

// Config methods
// getConfig retrieves one governance configuration by its persisted version.
//
// Parameters:
//   - version: configuration version used as the storage lookup key
//
// Returns:
//   - governance.Config: configuration stored at version, or the zero value when absent
//   - bool: true when a configuration exists at version; false when no entry exists
func (g *governanceV1) getConfig(version int64) (governance.Config, bool) {
	return g.store.GetConfig(version)
}

func (g *governanceV1) setConfig(_ int, rlm realm, version int64, config governance.Config) error {
	return g.store.SetConfig(0, rlm, version, config)
}

func (g *governanceV1) getCurrentConfig() (governance.Config, bool) {
	return g.getConfig(g.getCurrentConfigVersion())
}

// Proposal methods
// getProposal retrieves a proposal by its identifier.
//
// Parameters:
//   - id: proposal identifier used as the storage lookup key
//
// Returns:
//   - *governance.Proposal: stored proposal pointer, or nil when absent or not stored as a proposal
//   - bool: true when a proposal is found and has the expected type; false otherwise
func (g *governanceV1) getProposal(id int64) (*governance.Proposal, bool) {
	proposal, exists := g.store.GetProposal(id)
	if !exists {
		return nil, false
	}

	return proposal, true
}

func activeProposalSnapshotKey(proposal *governance.Proposal) string {
	return utils.EncodeUint64(uint64(proposal.SnapshotTime())) + utils.EncodeUint64(uint64(proposal.ID()))
}

func (g *governanceV1) addProposal(_ int, rlm realm, proposal *governance.Proposal) bool {
	// Set the proposal (ID already set in proposal)
	err := g.store.SetProposal(0, rlm, proposal.ID(), proposal)
	if err != nil {
		return false
	}

	// Add to the active snapshot index.
	snapshotIndex := g.store.GetActiveProposalsBySnapshot()
	snapshotIndex.Set(activeProposalSnapshotKey(proposal), proposal.ID())
	if err := g.store.SetActiveProposalsBySnapshot(0, rlm, snapshotIndex); err != nil {
		return false
	}

	// Add to user proposals
	err = g.store.AddUserProposal(0, rlm, proposal.Proposer().String(), proposal.ID())
	if err != nil {
		return false
	}

	return true
}

// removeActiveProposal removes a proposal from the active snapshot index.
//
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
//   - rlm: propagated current realm context validated before updating the active index
//   - proposal: proposal whose snapshot index entry is removed
//
// Returns:
//   - error: nil when the index entry is removed; otherwise not-found or store-write error
func (g *governanceV1) removeActiveProposal(_ int, rlm realm, proposal *governance.Proposal) error {
	snapshotIndex := g.store.GetActiveProposalsBySnapshot()
	key := activeProposalSnapshotKey(proposal)
	if !snapshotIndex.Has(key) {
		return makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("active proposal index entry not found, proposalID: %d", proposal.ID()))
	}
	snapshotIndex.Remove(key)

	return g.store.SetActiveProposalsBySnapshot(0, rlm, snapshotIndex)
}

// User proposals methods
// getUserProposals retrieves stored proposals associated with a user's address
// string, skipping IDs whose proposal records are no longer present.
//
// Parameters:
//   - user: user address string used to look up proposal IDs
//
// Returns:
//   - []*governance.Proposal: proposals found for the user, or an empty slice when no IDs or records are available
func (g *governanceV1) getUserProposals(user string) []*governance.Proposal {
	proposalIDs, exists := g.store.GetUserProposalIDs(user)
	if !exists {
		return []*governance.Proposal{}
	}

	proposals := make([]*governance.Proposal, 0)

	for _, id := range proposalIDs {
		proposal, exists := g.store.GetProposal(id)
		if !exists {
			continue
		}

		proposals = append(proposals, proposal)
	}

	return proposals
}

// hasActiveProposal assumes removeInactiveUserProposals has already pruned stale proposals.
// hasActiveProposal reports whether a proposer has any proposals in the user's
// list after inactive entries have been pruned.
//
// Parameters:
//   - proposerAddress: address whose stored proposal list is checked
//
// Returns:
//   - bool: true when at least one listed proposal remains; false when the list is empty
func (g *governanceV1) hasActiveProposal(proposerAddress address) bool {
	proposals := g.getUserProposals(proposerAddress.String())

	return len(proposals) > 0
}

// Remove inactive user proposals
// This function is used to remove inactive proposals from the user proposals list.
// It is used to clean up user's active proposal list when creating a new proposal.
// removeInactiveUserProposals removes a proposer's proposals that are no longer
// active according to the supplied current time.
//
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0 for forwarded store writes
//   - rlm: propagated current realm context validated before removing user-proposal entries
//   - proposerAddress: address whose proposal ID list is pruned
//   - current: current Unix timestamp passed to each proposal's activity check
//
// Returns:
//   - error: nil when pruning completes; otherwise the first user-proposal store removal error
func (g *governanceV1) removeInactiveUserProposals(_ int, rlm realm, proposerAddress address, current int64) error {
	proposals := g.getUserProposals(proposerAddress.String())

	for _, proposal := range proposals {
		proposalResolver := NewProposalResolver(proposal)

		if !proposalResolver.IsActive(current) {
			err := g.store.RemoveUserProposal(0, rlm, proposerAddress.String(), proposal.ID())
			if err != nil {
				return err
			}
		}
	}

	return nil
}

// Proposal voting info methods
// getProposalUserVotingInfos retrieves the per-user voting-info tree for a
// proposal.
//
// Parameters:
//   - proposalID: proposal identifier whose voting-info tree is requested
//
// Returns:
//   - *bptree.BPTree: tree of address-keyed voting information, or nil when absent
//   - bool: true when a voting-info tree exists for the proposal; false otherwise
func (g *governanceV1) getProposalUserVotingInfos(proposalID int64) (*bptree.BPTree, bool) {
	return g.store.GetProposalVotingInfos(proposalID)
}

func (g *governanceV1) updateProposalUserVotes(_ int, rlm realm, proposal *governance.Proposal, userVotingInfos *bptree.BPTree) error {
	return g.store.SetProposalVotingInfos(0, rlm, proposal.ID(), userVotingInfos)
}

// Helper methods for API
// mustGetProposal retrieves a proposal and panics when the identifier is not
// present in governance storage.
//
// Parameters:
//   - id: proposal identifier used for the lookup
//
// Returns:
//   - *governance.Proposal: stored proposal pointer; never nil when the function returns
func (g *governanceV1) mustGetProposal(id int64) *governance.Proposal {
	proposal, exists := g.getProposal(id)
	if !exists {
		panic(makeErrorWithDetails(errProposalNotFound, ufmt.Sprintf("proposal(%d) not found", id)))
	}
	return proposal
}

func (g *governanceV1) getProposalUserVotingInfo(proposalID int64, addr address) (governance.VotingInfo, bool) {
	votingInfosTree, exists := g.getProposalUserVotingInfos(proposalID)
	if !exists {
		return governance.DefaultVotingInfo(), false
	}

	votingInfoRaw := votingInfosTree.Get(addr.String())
	if votingInfoRaw == nil {
		return governance.DefaultVotingInfo(), false
	}
	votingInfo, ok := votingInfoRaw.(governance.VotingInfo)
	return votingInfo, ok
}
