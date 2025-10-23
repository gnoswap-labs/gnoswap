package v1

import (
	"gno.land/p/nt/avl"

	"gno.land/r/gnoswap/gov/governance"
)

type governanceState struct {
	configCounter   *Counter // Counter for generating config version numbers
	proposalCounter *Counter // Counter for generating unique proposal IDs

	configs                 *avl.Tree        // Tree storing governance configurations by version
	proposals               *avl.Tree        // Tree storing all proposals by ID
	proposalManager         *ProposalManager // Manager for user-proposal associations
	proposalUserVotingInfos *avl.Tree        // Tree storing voting info for each proposal by user

	// Function to retrieve user voting snapshots (can be overridden for testing)
	getUserVotingInfoSnapshotFn func(snapshotTime int64) (map[string]*VotingInfo, int64, bool)
}

func NewGovernanceState() *governanceState {
	gs := &governanceState{
		configCounter:   NewCounter(),
		proposalCounter: NewCounter(),
		configs:         avl.NewTree(),
		proposals:       avl.NewTree(),
		proposalManager: NewProposalManager(),
		proposalUserVotingInfos: avl.NewTree(),
	}

	gs.initConfig()
	gs.getUserVotingInfoSnapshotFn = func(snapshotTime int64) (map[string]*VotingInfo, int64, bool) {
		return getUserVotingInfotWithDelegationSnapshots(snapshotTime)
	}

	return gs
}

// initConfig initializes the governance configuration system.
// Sets up the configuration counter and creates the default initial configuration.
func (gs *governanceState) initConfig() {
	// Create the initial governance configuration with default parameters
	nextConfigVersion := gs.nextConfigVersion()
	config := governance.Config{
		VotingStartDelay:              86400,         // 1 day - delay before voting starts
		VotingPeriod:                  604800,        // 7 days - duration for collecting votes
		VotingWeightSmoothingDuration: 86400,         // 1 day - period for averaging voting weight
		Quorum:                        50,            // 50% of total xGNS supply required
		ProposalCreationThreshold:     1_000_000_000, // 1 billion - minimum balance to create proposals
		ExecutionDelay:                86400,         // 1 day - waiting period before execution
		ExecutionWindow:               2592000,       // 30 days - window for executing proposals
	}

	gs.setConfig(nextConfigVersion, config)
}

func (gs *governanceState) CurrentConfigVersion() int64 {
	return gs.getCurrentConfigVersion()
}

// getCurrentConfigVersion returns the current governance configuration version.
//
// Returns:
//   - int64: current configuration version number
func (gs *governanceState) getCurrentConfigVersion() int64 {
	return gs.configCounter.Get()
}

// nextConfigVersion increments and returns the next configuration version number.
// This is used when creating new governance configurations.
//
// Returns:
//   - int64: next configuration version number
func (gs *governanceState) nextConfigVersion() int64 {
	return gs.configCounter.next()
}

// getCurrentProposalID returns the current proposal ID (last assigned).
//
// Returns:
//   - int64: current proposal ID
func (gs *governanceState) getCurrentProposalID() int64 {
	return gs.proposalCounter.Get()
}

// nextProposalID increments and returns the next unique proposal ID.
// This is used when creating new proposals.
//
// Returns:
//   - int64: next unique proposal ID
func (gs *governanceState) nextProposalID() int64 {
	return gs.proposalCounter.next()
}

// getConfig retrieves a specific governance configuration by version number.
//
// Parameters:
//   - version: configuration version to retrieve
//
// Returns:
//   - Config: governance configuration for the specified version
//   - bool: true if configuration exists, false otherwise
func (gs *governanceState) getConfig(version int64) (cfg governance.Config, ok bool) {
	if val, exists := gs.configs.Get(formatInt(version)); !exists {
		return
	} else {
		cfg, ok = val.(governance.Config)
	}

	return
}

// setConfig stores a governance configuration with the specified version number.
//
// Parameters:
//   - version: configuration version number
//   - config: governance configuration to store
func (gs *governanceState) setConfig(version int64, config governance.Config) {
	gs.configs.Set(formatInt(version), config)
}

// getCurrentConfig retrieves the current active governance configuration.
//
// Returns:
//   - Config: current governance configuration
//   - bool: true if configuration exists, false otherwise
func (gs *governanceState) getCurrentConfig() (governance.Config, bool) {
	return gs.getConfig(gs.getCurrentConfigVersion())
}

// getProposal retrieves a specific proposal by its ID.
//
// Parameters:
//   - proposalID: unique identifier of the proposal
//
// Returns:
//   - *Proposal: pointer to the proposal if found
//   - bool: true if proposal exists, false otherwise
func (gs *governanceState) getProposal(proposalID int64) (proposal *Proposal, ok bool) {
	if val, exists := gs.proposals.Get(formatInt(proposalID)); !exists {
		return
	} else {
		proposal, ok = val.(*Proposal)
	}
	return
}

// addProposal stores a new proposal in the system.
// Also registers the proposal with the proposal manager for user tracking.
//
// Parameters:
//   - proposal: proposal to store
//
// Returns:
//   - bool: true if proposal was successfully added
func (gs *governanceState) addProposal(proposal *Proposal) bool {
	id := proposal.ID()
	// Store proposal in main proposals tree
	gs.proposals.Set(formatInt(id), proposal)

	// Register proposal with user in proposal manager
	gs.proposalManager.addProposal(proposal.Proposer(), id)

	return true
}

// getUserProposals retrieves all proposals created by a specific user.
//
// Parameters:
//   - user: address of the user
//
// Returns:
//   - []*Proposal: slice of proposals created by the user
func (gs *governanceState) getUserProposals(user address) (proposals []*Proposal) {
	// Get proposal IDs for this user
	proposalIDs := gs.proposalManager.GetUserProposals(user)

	// Retrieve each proposal by ID
	for _, proposalID := range proposalIDs {
		if proposal, ok := gs.getProposal(proposalID); !ok {
			continue // Skip if proposal not found (shouldn't happen)
		} else {
			proposals = append(proposals, proposal)
		}
	}
	return
}

// getProposalUserVotingInfos retrieves all voting information for a specific proposal.
// Returns a mapping of user addresses to their voting information.
//
// Parameters:
//   - proposalID: unique identifier of the proposal
//
// Returns:
//   - map[string]*VotingInfo: mapping of user addresses to voting information
//   - bool: true if voting information exists for the proposal
func (gs *governanceState) getProposalUserVotingInfos(proposalID int64) (userVotingInfos map[string]*VotingInfo, ok bool) {
	id := formatInt(proposalID)
	if userVotingInfosI, exists := gs.proposalUserVotingInfos.Get(id); !exists {
		return
	} else {
		userVotingInfos, ok = userVotingInfosI.(map[string]*VotingInfo)
	}
	return
}

// getProposalUserVotingInfo retrieves voting information for a specific user on a specific proposal.
//
// Parameters:
//   - proposalID: unique identifier of the proposal
//   - userAddress: address of the user
//
// Returns:
//   - *VotingInfo: voting information for the user
//   - bool: true if voting information exists for the user
func (gs *governanceState) getProposalUserVotingInfo(proposalID int64, userAddress address) (*VotingInfo, bool) {
	// First get all voting info for the proposal
	userVotingInfos, exists := gs.getProposalUserVotingInfos(proposalID)
	if !exists {
		return nil, false
	}

	// Then lookup the specific user's voting info
	val, exists := userVotingInfos[userAddress.String()]
	if !exists {
		return nil, false
	}

	return val, true
}

// hasActiveProposal checks if address already has active proposal.
// Enforces one-proposal-per-address rule to prevent spam.
func (gs *governanceState) hasActiveProposal(proposerAddress address, current int64) bool {
	// Get all proposals for this address
	proposals := gs.getUserProposals(proposerAddress)

	// Check if any proposal is still active
	for _, proposal := range proposals {
		if proposal.IsActive(current) {
			return true
		}
	}

	return false
}

// updateProposalUserVotes stores voting information for specific proposal.
// Links voting eligibility data to proposal for later use during voting.
func (gs *governanceState) updateProposalUserVotes(
	proposal *Proposal,
	userVotingInfos map[string]*VotingInfo,
) bool {
	// Store the voting information mapping for this proposal
	gs.proposalUserVotingInfos.Set(formatInt(proposal.ID()), userVotingInfos)

	return true
}
