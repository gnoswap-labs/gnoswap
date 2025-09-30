package governance

import (
	"std"

	"gno.land/p/nt/avl"
)

// Global state variables for governance system
var (
	configCounter   *Counter // Counter for generating config version numbers
	proposalCounter *Counter // Counter for generating unique proposal IDs

	configs                 *avl.Tree        // Tree storing governance configurations by version
	proposals               *avl.Tree        // Tree storing all proposals by ID
	proposalManager         *ProposalManager // Manager for user-proposal associations
	proposalUserVotingInfos *avl.Tree        // Tree storing voting info for each proposal by user

	// Function to retrieve user voting snapshots (can be overridden for testing)
	getUserVotingInfoSnapshotFn func(snapshotTime int64) (map[string]*VotingInfo, int64, bool)
)

// init initializes the governance system state when the contract is deployed.
// This function sets up all necessary data structures and default configurations.
func init() {
	initConfig()
	initProposal()
	initStakerDelegationSnapshots()
}

// initConfig initializes the governance configuration system.
// Sets up the configuration counter and creates the default initial configuration.
func initConfig() {
	configCounter = NewCounter()
	configs = avl.NewTree()

	// Create the initial governance configuration with default parameters
	nextConfigVersion := nextConfigVersion()
	config := Config{
		VotingStartDelay:              86400,         // 1 day - delay before voting starts
		VotingPeriod:                  604800,        // 7 days - duration for collecting votes
		VotingWeightSmoothingDuration: 86400,         // 1 day - period for averaging voting weight
		Quorum:                        50,            // 50% of total xGNS supply required
		ProposalCreationThreshold:     1_000_000_000, // 1 billion - minimum balance to create proposals
		ExecutionDelay:                86400,         // 1 day - waiting period before execution
		ExecutionWindow:               2592000,       // 30 days - window for executing proposals
	}

	setConfig(nextConfigVersion, config)
}

// initProposal initializes the proposal management system.
// Sets up counters, storage trees, and management structures for proposals.
func initProposal() {
	proposalCounter = NewCounter()
	proposals = avl.NewTree()
	proposalManager = NewProposalManager()
	proposalUserVotingInfos = avl.NewTree()
}

// initStakerDelegationSnapshots initializes the voting snapshot function.
// Sets up the default function to retrieve voting weights from staker contract.
func initStakerDelegationSnapshots() {
	getUserVotingInfoSnapshotFn = func(snapshotTime int64) (map[string]*VotingInfo, int64, bool) {
		return getUserVotingInfotWithDelegationSnapshots(snapshotTime)
	}
}

// getCurrentConfigVersion returns the current governance configuration version.
//
// Returns:
//   - int64: current configuration version number
func getCurrentConfigVersion() int64 {
	return configCounter.Get()
}

// nextConfigVersion increments and returns the next configuration version number.
// This is used when creating new governance configurations.
//
// Returns:
//   - int64: next configuration version number
func nextConfigVersion() int64 {
	return configCounter.next()
}

// getCurrentProposalID returns the current proposal ID (last assigned).
//
// Returns:
//   - int64: current proposal ID
func getCurrentProposalID() int64 {
	return proposalCounter.Get()
}

// nextProposalID increments and returns the next unique proposal ID.
// This is used when creating new proposals.
//
// Returns:
//   - int64: next unique proposal ID
func nextProposalID() int64 {
	return proposalCounter.next()
}

// getConfig retrieves a specific governance configuration by version number.
//
// Parameters:
//   - version: configuration version to retrieve
//
// Returns:
//   - Config: governance configuration for the specified version
//   - bool: true if configuration exists, false otherwise
func getConfig(version int64) (cfg Config, ok bool) {
	if val, exists := configs.Get(formatInt(version)); !exists {
		return
	} else {
		cfg, ok = val.(Config)
	}

	return
}

// setConfig stores a governance configuration with the specified version number.
//
// Parameters:
//   - version: configuration version number
//   - config: governance configuration to store
func setConfig(version int64, config Config) {
	configs.Set(formatInt(version), config)
}

// getCurrentConfig retrieves the current active governance configuration.
//
// Returns:
//   - Config: current governance configuration
//   - bool: true if configuration exists, false otherwise
func getCurrentConfig() (Config, bool) {
	return getConfig(getCurrentConfigVersion())
}

// getProposal retrieves a specific proposal by its ID.
//
// Parameters:
//   - proposalID: unique identifier of the proposal
//
// Returns:
//   - *Proposal: pointer to the proposal if found
//   - bool: true if proposal exists, false otherwise
func getProposal(proposalID int64) (proposal *Proposal, ok bool) {
	if val, exists := proposals.Get(formatInt(proposalID)); !exists {
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
func addProposal(proposal *Proposal) bool {
	id := proposal.ID()
	// Store proposal in main proposals tree
	proposals.Set(formatInt(id), proposal)

	// Register proposal with user in proposal manager
	proposalManager.addProposal(proposal.Proposer(), id)

	return true
}

// getUserProposals retrieves all proposals created by a specific user.
//
// Parameters:
//   - user: address of the user
//
// Returns:
//   - []*Proposal: slice of proposals created by the user
func getUserProposals(user std.Address) (proposals []*Proposal) {
	// Get proposal IDs for this user
	proposalIDs := proposalManager.GetUserProposals(user)

	// Retrieve each proposal by ID
	for _, proposalID := range proposalIDs {
		if proposal, ok := getProposal(proposalID); !ok {
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
func getProposalUserVotingInfos(proposalID int64) (userVotingInfos map[string]*VotingInfo, ok bool) {
	id := formatInt(proposalID)
	if userVotingInfosI, exists := proposalUserVotingInfos.Get(id); !exists {
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
func getProposalUserVotingInfo(proposalID int64, userAddress std.Address) (*VotingInfo, bool) {
	// First get all voting info for the proposal
	userVotingInfos, exists := getProposalUserVotingInfos(proposalID)
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
