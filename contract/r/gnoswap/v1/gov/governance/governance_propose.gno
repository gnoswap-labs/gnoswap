package governance

import (
	"std"
	"time"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/gov/staker"
)

// ProposeText creates a text proposal for discussion.
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
		"maxVotingWeight", formatInt(proposal.VotingTotalWeight()),
		"configVersion", formatInt(proposal.ConfigVersion()),
		"createdAt", formatInt(proposal.CreatedAt()),
	)

	return proposal.ID()
}

// ProposeCommunityPoolSpend creates a new community pool spend proposal.
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
		"maxVotingWeight", formatInt(proposal.VotingTotalWeight()),
		"configVersion", formatInt(proposal.ConfigVersion()),
		"createdAt", formatInt(proposal.CreatedAt()),
	)

	return proposal.ID()
}

// ProposeParameterChange creates a new parameter change proposal.
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
		"maxVotingWeight", formatInt(proposal.VotingTotalWeight()),
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
