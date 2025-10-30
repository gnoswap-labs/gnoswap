package v1

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"

	"gno.land/r/gnoswap/gov/governance"
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
func (gv *governanceV1) ProposeText(
	title string,
	description string,
) (newProposalId int64) {
	halt.AssertIsNotHaltedGovernance()

	callerAddress := runtime.PreviousRealm().Address()

	createdAt := time.Now().Unix()
	createdHeight := runtime.ChainHeight()
	gnsBalance := gns.BalanceOf(callerAddress)

	config, ok := gv.getCurrentConfig()
	if !ok {
		panic(errDataNotFound)
	}

	// Check if caller already has an active proposal (one proposal per address)
	if gv.hasActiveProposal(callerAddress, createdAt) {
		panic(errAlreadyActiveProposal)
	}

	// Get snapshot of voting weights for proposal creation
	userVotes, maxVotingWeight, err := gv.getUserVotingInfoSnapshot(
		createdAt,
		config.VotingWeightSmoothingDuration,
	)
	if err != nil {
		panic(err)
	}

	// Create the text proposal with metadata
	proposal, err := gv.createProposal(
		governance.Text,
		config,
		maxVotingWeight,
		governance.NewProposalMetadata(title, description),
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
	success := gv.updateProposalUserVotes(proposal, userVotes)
	if !success {
		panic(errDataNotFound)
	}

	// Emit proposal creation event for indexing and tracking
	previousRealm := runtime.PreviousRealm()
	chain.Emit(
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
func (gv *governanceV1) ProposeCommunityPoolSpend(
	title string,
	description string,
	to address,
	tokenPath string,
	amount int64,
) (newProposalId int64) {
	halt.AssertIsNotHaltedGovernance()
	halt.AssertIsNotHaltedWithdraw()

	callerAddress := runtime.PreviousRealm().Address()

	createdAt := time.Now().Unix()
	createdHeight := runtime.ChainHeight()
	gnsBalance := gns.BalanceOf(callerAddress)

	config, ok := gv.getCurrentConfig()
	if !ok {
		panic(errDataNotFound)
	}

	// Check if caller already has an active proposal (one proposal per address)
	if gv.hasActiveProposal(callerAddress, createdAt) {
		panic(errAlreadyActiveProposal)
	}

	// Get snapshot of voting weights for proposal creation
	userVotes, maxVotingWeight, err := gv.getUserVotingInfoSnapshot(
		createdAt,
		config.VotingWeightSmoothingDuration,
	)
	if err != nil {
		panic(err)
	}

	// Create the community pool spend proposal with execution data
	proposal, err := gv.createProposal(
		governance.CommunityPoolSpend,
		config,
		maxVotingWeight,
		governance.NewProposalMetadata(title, description),
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
	success := gv.updateProposalUserVotes(proposal, userVotes)
	if !success {
		panic(errDataNotFound)
	}

	// Emit proposal creation event for indexing and tracking
	previousRealm := runtime.PreviousRealm()
	chain.Emit(
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
func (gv *governanceV1) ProposeParameterChange(
	title string,
	description string,
	numToExecute int64,
	executions string,
) (newProposalId int64) {
	halt.AssertIsNotHaltedGovernance()

	callerAddress := runtime.PreviousRealm().Address()

	createdAt := time.Now().Unix()
	createdHeight := runtime.ChainHeight()
	gnsBalance := gns.BalanceOf(callerAddress)

	config, ok := gv.getCurrentConfig()
	if !ok {
		panic(errDataNotFound)
	}

	// Check if caller already has an active proposal (one proposal per address)
	if gv.hasActiveProposal(callerAddress, createdAt) {
		panic(errAlreadyActiveProposal)
	}

	// Get snapshot of voting weights for proposal creation
	userVotes, maxVotingWeight, err := gv.getUserVotingInfoSnapshot(
		createdAt,
		config.VotingWeightSmoothingDuration,
	)
	if err != nil {
		panic(err)
	}

	// Create the parameter change proposal with execution data
	proposal, err := gv.createProposal(
		governance.ParameterChange,
		config,
		maxVotingWeight,
		governance.NewProposalMetadata(title, description),
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
	success := gv.updateProposalUserVotes(proposal, userVotes)
	if !success {
		panic(errDataNotFound)
	}

	// Emit proposal creation event for indexing and tracking
	previousRealm := runtime.PreviousRealm()
	chain.Emit(
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
func (gv *governanceV1) createProposal(
	proposalType governance.ProposalType,
	config governance.Config,
	maxVotingWeight int64,
	proposalMetadata *governance.ProposalMetadata,
	proposalData *governance.ProposalData,
	proposerAddress address,
	proposerGnsBalance int64,
	createdAt int64,
	createdHeight int64,
) (*governance.Proposal, error) {
	// Validate proposal metadata (title and description)
	metadataResolver := NewProposalMetadataResolver(proposalMetadata)
	err := metadataResolver.Validate()
	if err != nil {
		return nil, err
	}

	// Validate proposal data (type-specific validation)
	dataResolver := NewProposalDataResolver(proposalData)
	err = dataResolver.Validate()
	if err != nil {
		return nil, err
	}

	// Check if proposer has enough GNS balance to create proposal
	if proposerGnsBalance < config.ProposalCreationThreshold {
		return nil, errNotEnoughBalance
	}

	// Generate unique proposal ID
	proposalID := gv.nextProposalID()

	// Create proposal status with voting schedule and requirements
	proposalStatus := NewProposalStatus(
		config,
		maxVotingWeight,
		proposalType.IsExecutable(),
		createdAt,
	)

	// Get current configuration version for tracking
	configVersion := gv.getCurrentConfigVersion()

	// Create the proposal object
	proposal := governance.NewProposal(
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
	success := gv.addProposal(proposal)
	if !success {
		return nil, errDataNotFound
	}

	return proposal, nil
}

// getUserVotingInfoSnapshot retrieves voting information snapshot for proposal creation.
// Calculates voting weights at specific time point for fair voting.
func (gv *governanceV1) getUserVotingInfoSnapshot(
	current,
	smoothingPeriod int64,
) (map[string]*governance.VotingInfo, int64, error) {
	// Calculate snapshot time by going back by smoothing period
	snapshotTime := current - smoothingPeriod

	var votingInfos map[string]*governance.VotingInfo
	var maxVotingWeight int64
	var ok bool

	// Use custom snapshot function if available
	if gv.getUserVotingInfoSnapshotFn != nil {
		votingInfos, maxVotingWeight, ok = gv.getUserVotingInfoSnapshotFn(snapshotTime)
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
) (map[string]*governance.VotingInfo, int64, bool) {
	// Get delegation snapshots from staker contract
	delegationSnapshots, ok := staker.GetDelegationSnapshots(snapshotTime)
	if !ok {
		return nil, 0, false
	}

	maxVotingWeight := int64(0)
	userVotes := make(map[string]*governance.VotingInfo)

	// Process each delegation snapshot
	for _, snapshot := range delegationSnapshots {
		delegatorAddress := snapshot.DelegatorAddress()
		delegationAmount := snapshot.DelegationAmount()

		// Create voting info for each delegator
		userVotes[delegatorAddress.String()] = governance.NewVotingInfo(delegationAmount, delegatorAddress)
		maxVotingWeight += delegationAmount
	}

	return userVotes, maxVotingWeight, true
}
