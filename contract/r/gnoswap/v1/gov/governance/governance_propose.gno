package governance

import (
	"std"
	"time"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/gov/staker"
)

// ProposeText creates a text proposal for community discussion.
//
// Signal proposals for non-binding community sentiment.
// Used for policy discussions, roadmap planning, and community feedback.
// No on-chain execution, serves as formal governance record.
//
// Parameters:
//   - title: Short, descriptive proposal title (max 100 chars recommended)
//   - description: Full proposal content with rationale and context
//
// Requirements:
//   - Caller must hold minimum 1,000 GNS tokens
//   - No other active proposal from same address
//   - Title and description must be non-empty
//
// Process:
//   - 1 day delay before voting starts
//   - 7 days voting period
//   - Simple majority decides outcome
//   - No execution phase (signal only)
//
// Returns new proposal ID.
func ProposeText(
	cur realm,
	title string,
	description string,
) (newProposalId int64) {
	halt.AssertIsNotHaltedGovernance()

	callerAddress := std.PreviousRealm().Address()

	createdAt := time.Now().Unix()
	createdHeight := std.ChainHeight()
	gnsBalance := gns.BalanceOf(callerAddress)

	config, ok := getCurrentConfig()
	if !ok {
		panic(errDataNotFound)
	}

	// Check if caller already has an active proposal (one proposal per address)
	if hasActiveProposal(callerAddress, createdAt) {
		panic(errAlreadyActiveProposal)
	}

	// Get snapshot of voting weights for proposal creation
	userVotes, maxVotingWeight, err := getUserVotingInfoSnapshot(
		createdAt,
		config.VotingWeightSmoothingDuration,
	)
	if err != nil {
		panic(err)
	}

	// Create the text proposal with metadata
	proposal, err := createProposal(
		Text,
		config,
		maxVotingWeight,
		NewProposalMetadata(title, description),
		NewProposalTextData(),
		callerAddress,
		gnsBalance,
		createdAt,
		createdHeight,
	)
	if err != nil {
		panic(err)
	}

	// Store voting information for the proposal
	success := updateProposalUserVotes(proposal, userVotes)
	if !success {
		panic(errDataNotFound)
	}

	// Emit proposal creation event for indexing and tracking
	previousRealm := std.PreviousRealm()
	std.Emit(
		"ProposeText",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"title", title,
		"description", description,
		"proposalId", formatInt(proposal.ID()),
		"quorumAmount", formatInt(proposal.VotingQuorumAmount()),
		"maxVotingWeight", formatInt(proposal.VotingMaxWeight()),
		"configVersion", formatInt(proposal.ConfigVersion()),
		"createdAt", formatInt(proposal.CreatedAt()),
	)

	return proposal.ID()
}

// ProposeCommunityPoolSpend creates a treasury disbursement proposal.
//
// Allocates community pool funds for approved purposes.
// Supports grants, development funding, and protocol incentives.
// Automatic transfer on execution if approved.
//
// Parameters:
//   - title: Proposal title describing purpose
//   - description: Detailed justification and budget breakdown
//   - to: Recipient address for funds
//   - tokenPath: Token contract path (e.g., "gno.land/r/gnoswap/gns")
//   - amount: Amount to transfer (in smallest unit)
//
// Requirements:
//   - Caller must hold minimum 1,000 GNS tokens
//   - Sufficient balance in community pool
//   - Valid recipient address
//   - Supported token type
//
// Security:
//   - Enforces timelock after approval
//   - Single transfer per proposal
//   - Tracks all disbursements on-chain
//
// Returns new proposal ID.
func ProposeCommunityPoolSpend(
	cur realm,
	title string,
	description string,
	to std.Address,
	tokenPath string,
	amount int64,
) (newProposalId int64) {
	halt.AssertIsNotHaltedGovernance()
	halt.AssertIsNotHaltedWithdraw()

	callerAddress := std.PreviousRealm().Address()

	createdAt := time.Now().Unix()
	createdHeight := std.ChainHeight()
	gnsBalance := gns.BalanceOf(callerAddress)

	config, ok := getCurrentConfig()
	if !ok {
		panic(errDataNotFound)
	}

	// Check if caller already has an active proposal (one proposal per address)
	if hasActiveProposal(callerAddress, createdAt) {
		panic(errAlreadyActiveProposal)
	}

	// Get snapshot of voting weights for proposal creation
	userVotes, maxVotingWeight, err := getUserVotingInfoSnapshot(
		createdAt,
		config.VotingWeightSmoothingDuration,
	)
	if err != nil {
		panic(err)
	}

	// Create the community pool spend proposal with execution data
	proposal, err := createProposal(
		CommunityPoolSpend,
		config,
		maxVotingWeight,
		NewProposalMetadata(title, description),
		NewProposalCommunityPoolSpendData(tokenPath, to, amount, COMMUNITY_POOL_PATH),
		callerAddress,
		gnsBalance,
		createdAt,
		createdHeight,
	)
	if err != nil {
		panic(err)
	}

	// Store voting information for the proposal
	success := updateProposalUserVotes(proposal, userVotes)
	if !success {
		panic(errDataNotFound)
	}

	// Emit proposal creation event for indexing and tracking
	previousRealm := std.PreviousRealm()
	std.Emit(
		"ProposeCommunityPoolSpend",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"title", title,
		"description", description,
		"to", to.String(),
		"tokenPath", tokenPath,
		"amount", formatInt(amount),
		"proposalId", formatInt(proposal.ID()),
		"quorumAmount", formatInt(proposal.VotingQuorumAmount()),
		"maxVotingWeight", formatInt(proposal.VotingMaxWeight()),
		"configVersion", formatInt(proposal.ConfigVersion()),
		"createdAt", formatInt(proposal.CreatedAt()),
	)

	return proposal.ID()
}

// ProposeParameterChange creates a protocol parameter update proposal.
//
// Modifies system parameters through governance.
// Supports multiple parameter changes in single proposal.
// Changes apply atomically on execution.
//
// Parameters:
//   - title: Clear description of changes
//   - description: Rationale and impact analysis
//   - numToExecute: Number of parameter changes
//   - executions: JSON array of changes, each containing:
//   - target: Contract address to modify
//   - function: Function name to call
//   - params: Parameters for the function
//
// Example executions format:
//
//	[{
//	  "target": "gno.land/r/gnoswap/v1/gov",
//	  "function": "SetVotingPeriod",
//	  "params": ["604800"]
//	}]
//
// Requirements:
//   - Valid JSON format for executions
//   - Target contracts must exist
//   - Functions must be governance-callable
//   - Parameters must match function signatures
//
// Returns new proposal ID.
func ProposeParameterChange(
	cur realm,
	title string,
	description string,
	numToExecute int64,
	executions string,
) (newProposalId int64) {
	halt.AssertIsNotHaltedGovernance()

	callerAddress := std.PreviousRealm().Address()

	createdAt := time.Now().Unix()
	createdHeight := std.ChainHeight()
	gnsBalance := gns.BalanceOf(callerAddress)

	config, ok := getCurrentConfig()
	if !ok {
		panic(errDataNotFound)
	}

	// Check if caller already has an active proposal (one proposal per address)
	if hasActiveProposal(callerAddress, createdAt) {
		panic(errAlreadyActiveProposal)
	}

	// Get snapshot of voting weights for proposal creation
	userVotes, maxVotingWeight, err := getUserVotingInfoSnapshot(
		createdAt,
		config.VotingWeightSmoothingDuration,
	)
	if err != nil {
		panic(err)
	}

	// Create the parameter change proposal with execution data
	proposal, err := createProposal(
		ParameterChange,
		config,
		maxVotingWeight,
		NewProposalMetadata(title, description),
		NewProposalExecutionData(numToExecute, executions),
		callerAddress,
		gnsBalance,
		createdAt,
		createdHeight,
	)
	if err != nil {
		panic(err)
	}

	// Store voting information for the proposal
	success := updateProposalUserVotes(proposal, userVotes)
	if !success {
		panic(errDataNotFound)
	}

	// Emit proposal creation event for indexing and tracking
	previousRealm := std.PreviousRealm()
	std.Emit(
		"ProposeParameterChange",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"title", title,
		"description", description,
		"numToExecute", formatInt(numToExecute),
		"executions", executions,
		"proposalId", formatInt(proposal.ID()),
		"quorumAmount", formatInt(proposal.VotingQuorumAmount()),
		"maxVotingWeight", formatInt(proposal.VotingMaxWeight()),
		"configVersion", formatInt(proposal.ConfigVersion()),
		"createdAt", formatInt(proposal.CreatedAt()),
	)

	return proposal.ID()
}

// createProposal handles proposal creation logic.
// Validates input data, checks proposer eligibility, and creates proposal object.
func createProposal(
	proposalType ProposalType,
	config Config,
	maxVotingWeight int64,
	proposalMetadata *ProposalMetadata,
	proposalData *ProposalData,
	proposerAddress std.Address,
	proposerGnsBalance int64,
	createdAt int64,
	createdHeight int64,
) (*Proposal, error) {
	// Validate proposal metadata (title and description)
	err := proposalMetadata.Validate()
	if err != nil {
		return nil, err
	}

	// Validate proposal data (type-specific validation)
	err = proposalData.Validate()
	if err != nil {
		return nil, err
	}

	// Check if proposer has enough GNS balance to create proposal
	if proposerGnsBalance < config.ProposalCreationThreshold {
		return nil, errNotEnoughBalance
	}

	// Generate unique proposal ID
	proposalID := nextProposalID()

	// Create proposal status with voting schedule and requirements
	proposalStatus := NewProposalStatus(
		config,
		maxVotingWeight,
		proposalType.IsExecutable(),
		createdAt,
	)

	// Get current configuration version for tracking
	configVersion := getCurrentConfigVersion()

	// Create the proposal object
	proposal := NewProposal(
		proposalID,
		proposalStatus,
		proposalMetadata,
		proposalData,
		proposerAddress,
		configVersion,
		createdAt,
		createdHeight,
	)

	// Store the proposal in state
	success := addProposal(proposal)
	if !success {
		return nil, errDataNotFound
	}

	return proposal, nil
}

// getUserVotingInfoSnapshot retrieves voting information snapshot for proposal creation.
// Calculates voting weights at specific time point for fair voting.
func getUserVotingInfoSnapshot(
	current,
	smoothingPeriod int64,
) (map[string]*VotingInfo, int64, error) {
	// Calculate snapshot time by going back by smoothing period
	snapshotTime := current - smoothingPeriod

	var votingInfos map[string]*VotingInfo
	var maxVotingWeight int64
	var ok bool

	// Use custom snapshot function if available
	if getUserVotingInfoSnapshotFn != nil {
		votingInfos, maxVotingWeight, ok = getUserVotingInfoSnapshotFn(snapshotTime)
	} else {
		votingInfos, maxVotingWeight, ok = getUserVotingInfotWithDelegationSnapshots(snapshotTime)
	}

	if !ok || maxVotingWeight <= 0 {
		return votingInfos, maxVotingWeight, errNotEnoughVotingWeight
	}

	return votingInfos, maxVotingWeight, nil
}

// getUserVotingInfotWithDelegationSnapshots retrieves voting info from staker delegation snapshots.
// Integrates with staker contract to get actual delegation amounts.
func getUserVotingInfotWithDelegationSnapshots(
	snapshotTime int64,
) (map[string]*VotingInfo, int64, bool) {
	// Get delegation snapshots from staker contract
	delegationSnapshots, ok := staker.GetDelegationSnapshots(snapshotTime)
	if !ok {
		return nil, 0, false
	}

	maxVotingWeight := int64(0)
	userVotes := make(map[string]*VotingInfo)

	// Process each delegation snapshot
	for _, snapshot := range delegationSnapshots {
		delegatorAddress := snapshot.DelegatorAddress()
		delegationAmount := snapshot.DelegationAmount()

		// Create voting info for each delegator
		userVotes[delegatorAddress.String()] = NewVotingInfo(delegationAmount, delegatorAddress)
		maxVotingWeight += delegationAmount
	}

	return userVotes, maxVotingWeight, true
}

// updateProposalUserVotes stores voting information for specific proposal.
// Links voting eligibility data to proposal for later use during voting.
func updateProposalUserVotes(
	proposal *Proposal,
	userVotingInfos map[string]*VotingInfo,
) bool {
	// Store the voting information mapping for this proposal
	proposalUserVotingInfos.Set(formatInt(proposal.ID()), userVotingInfos)

	return true
}

// hasActiveProposal checks if address already has active proposal.
// Enforces one-proposal-per-address rule to prevent spam.
func hasActiveProposal(proposerAddress std.Address, current int64) bool {
	// Get all proposals for this address
	proposals := getUserProposals(proposerAddress)

	// Check if any proposal is still active
	for _, proposal := range proposals {
		if proposal.IsActive(current) {
			return true
		}
	}

	return false
}
