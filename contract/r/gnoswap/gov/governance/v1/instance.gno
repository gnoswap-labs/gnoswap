package v1

import (
	"strconv"

	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/gov/governance"
)

type governanceV1 struct {
	store governance.IGovernanceStore

	// Function to retrieve user voting snapshots (can be overridden for testing)
	getUserVotingInfoSnapshotFn func(snapshotTime int64) (map[string]*VotingInfo, int64, bool)
}

func NewGovernanceV1(governanceStore governance.IGovernanceStore) governance.IGovernance {
	gv := &governanceV1{
		store: governanceStore,
	}

	// Set default voting info snapshot function
	gv.getUserVotingInfoSnapshotFn = func(snapshotTime int64) (map[string]*VotingInfo, int64, bool) {
		return getUserVotingInfotWithDelegationSnapshots(snapshotTime)
	}

	// Initialize the default configuration if this is the first setup
	if !governanceStore.HasConfigsStoreKey() || governanceStore.GetConfigCounter() == 0 {
		// Config initialization is handled in init.gno
	}

	return gv
}

// Config version methods
func (g *governanceV1) getCurrentConfigVersion() int64 {
	return g.store.GetConfigCounter()
}

func (g *governanceV1) nextConfigVersion() int64 {
	newVersion, err := g.store.IncrementConfigCounter()
	if err != nil {
		panic("failed to increment config counter: " + err.Error())
	}
	return newVersion
}

// Proposal ID methods
func (g *governanceV1) getCurrentProposalID() int64 {
	return g.store.GetProposalCounter()
}

func (g *governanceV1) nextProposalID() int64 {
	newID, err := g.store.IncrementProposalCounter()
	if err != nil {
		panic("failed to increment proposal counter: " + err.Error())
	}
	return newID
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
func (g *governanceV1) getProposal(id int64) (*Proposal, bool) {
	proposalRaw, exists := g.store.GetProposal(id)
	if !exists {
		return nil, false
	}

	proposal, ok := proposalRaw.(*Proposal)
	if !ok {
		return nil, false
	}

	return proposal, true
}

func (g *governanceV1) addProposal(proposal *Proposal) bool {
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
		if proposal, ok := proposalRaw.(*Proposal); ok {
			if proposal.IsActive(current) {
				return true
			}
		}
	}

	return false
}

// Proposal voting info methods
func (g *governanceV1) getProposalUserVotingInfos(proposalID int64) (interface{}, bool) {
	return g.store.GetProposalVotingInfos(proposalID)
}

func (g *governanceV1) updateProposalUserVotes(proposal *Proposal, userVotingInfos map[string]*VotingInfo) bool {
	// Convert map to avl.Tree for storage
	tree := avl.NewTree()
	for addr, info := range userVotingInfos {
		tree.Set(addr, info)
	}

	err := g.store.SetProposalVotingInfos(proposal.ID(), tree)
	return err == nil
}

// Helper methods for API
func (g *governanceV1) mustGetProposal(id int64) *Proposal {
	proposal, exists := g.getProposal(id)
	if !exists {
		panic("proposal not found: " + strconv.FormatInt(id, 10))
	}
	return proposal
}

func (g *governanceV1) getProposalUserVotingInfo(proposalID int64, addr address) (*VotingInfo, bool) {
	votingInfosRaw, exists := g.getProposalUserVotingInfos(proposalID)
	if !exists {
		return nil, false
	}

	votingInfos, ok := votingInfosRaw.(*avl.Tree)
	if !ok {
		return nil, false
	}

	infoRaw, exists := votingInfos.Get(addr.String())
	if !exists {
		return nil, false
	}

	info, ok := infoRaw.(*VotingInfo)
	if !ok {
		return nil, false
	}

	return info, true
}
