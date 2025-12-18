package v1

import (
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/gov/governance"
)

type governanceV1 struct {
	store governance.IGovernanceStore

	// Function to retrieve user voting snapshots (can be overridden for testing)
	getUserVotingInfoSnapshotFn func(snapshotTime int64) (map[string]*governance.VotingInfo, int64, bool)
}

func NewGovernanceV1(governanceStore governance.IGovernanceStore) governance.IGovernance {
	gv := &governanceV1{store: governanceStore}

	// Set default voting info snapshot function
	gv.getUserVotingInfoSnapshotFn = func(snapshotTime int64) (map[string]*governance.VotingInfo, int64, bool) {
		return getUserVotingInfoWithDelegationSnapshots(snapshotTime)
	}

	return gv
}

// Config version methods
func (g *governanceV1) getCurrentConfigVersion() int64 {
	return g.store.GetConfigCounter().Get()
}

func (g *governanceV1) nextConfigVersion() int64 {
	return g.store.GetConfigCounter().Next()
}

// Proposal ID methods
func (g *governanceV1) getCurrentProposalID() int64 {
	return g.store.GetProposalCounter().Get()
}

func (g *governanceV1) nextProposalID() int64 {
	return g.store.GetProposalCounter().Next()
}

// Config methods
func (g *governanceV1) getConfig(version int64) (governance.Config, bool) {
	return g.store.GetConfig(version)
}

func (g *governanceV1) setConfig(version int64, config governance.Config) error {
	return g.store.SetConfig(version, config)
}

func (g *governanceV1) getCurrentConfig() (governance.Config, bool) {
	return g.getConfig(g.getCurrentConfigVersion())
}

// Proposal methods
func (g *governanceV1) getProposal(id int64) (*governance.Proposal, bool) {
	proposal, exists := g.store.GetProposal(id)
	if !exists {
		return nil, false
	}

	return proposal, true
}

func (g *governanceV1) addProposal(proposal *governance.Proposal) bool {
	// Set the proposal (ID already set in proposal)
	err := g.store.SetProposal(proposal.ID(), proposal)
	if err != nil {
		return false
	}

	// Add to user proposals
	err = g.store.AddUserProposal(proposal.Proposer().String(), proposal.ID())
	if err != nil {
		return false
	}

	return true
}

// User proposals methods
func (g *governanceV1) getUserProposals(user string) []interface{} {
	proposalIDs, exists := g.store.GetUserProposalIDs(user)
	if !exists {
		return []interface{}{}
	}

	var proposals []interface{}
	for _, id := range proposalIDs {
		if proposal, exists := g.store.GetProposal(id); exists {
			proposals = append(proposals, proposal)
		}
	}

	return proposals
}

func (g *governanceV1) hasActiveProposal(proposerAddress address, current int64) bool {
	proposals := g.getUserProposals(proposerAddress.String())

	// Check if any proposal is still active
	for _, proposalRaw := range proposals {
		if proposal, ok := proposalRaw.(*governance.Proposal); ok {
			proposalResolver := NewProposalResolver(proposal)
			if proposalResolver.IsActive(current) {
				return true
			}
		}
	}

	return false
}

// Proposal voting info methods
func (g *governanceV1) getProposalUserVotingInfos(proposalID int64) (map[string]*governance.VotingInfo, bool) {
	return g.store.GetProposalVotingInfos(proposalID)
}

func (g *governanceV1) updateProposalUserVotes(proposal *governance.Proposal, userVotingInfos map[string]*governance.VotingInfo) bool {
	err := g.store.SetProposalVotingInfos(proposal.ID(), userVotingInfos)
	return err == nil
}

// Helper methods for API
func (g *governanceV1) mustGetProposal(id int64) *governance.Proposal {
	proposal, exists := g.getProposal(id)
	if !exists {
		detail := ufmt.Sprintf("proposal(%d) not found", id)
		msg := makeErrorWithDetails(errProposalNotFound, detail)
		panic(msg)
	}
	return proposal
}

func (g *governanceV1) getProposalUserVotingInfo(proposalID int64, addr address) (*governance.VotingInfo, bool) {
	votingInfosRaw, exists := g.getProposalUserVotingInfos(proposalID)
	if !exists {
		return nil, false
	}

	votingInfo, exists := votingInfosRaw[addr.String()]
	return votingInfo, exists
}
