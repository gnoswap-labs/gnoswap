package governance

import (
	"std"
	"time"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/staker"
)

// ProposeText creates a new text proposal with the given data.
// Text proposals are informational only and cannot be executed.
// They are used for community discussions and non-binding votes.
//
// Parameters:
//   - cur: realm context for cross-realm calls
//   - title: proposal title (max 255 characters)
//   - description: detailed proposal description (max 10,000 characters)
//
// Returns:
//   - int64: unique ID of the created proposal
//
// Panics:
//   - if proposer doesn't have enough voting weight
//   - if proposer has an active proposal
//   - if input validation fails
//
// ref: https://docs.gnoswap.io/contracts/governance/proposal.gno#proposetext
func ProposeText(
	cur realm,
	title string,
	description string,
) (newProposalId int64) {
	// Get caller information for proposal creation
	previousPkgPath := std.PreviousRealm().PkgPath()
	previousAddress := std.PreviousRealm().Address()
	callerAddress := std.PreviousRealm().Address()

	// Get current blockchain state
	createdAt := time.Now().Unix()
	createdHeight := std.ChainHeight()
	gnsBalance := gns.BalanceOf(callerAddress)

	// Retrieve current governance configuration
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
	std.Emit(
		"ProposeText",
		"prevAddr", previousAddress.String(),
		"prevRealm", previousPkgPath,
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
// This type of proposal allows transferring tokens from the community pool to specified recipients.
// Upon execution, tokens are transferred from the community pool to the designated address.
//
// Parameters:
//   - cur: realm context for cross-realm calls
//   - title: proposal title (max 255 characters)
//   - description: detailed proposal description (max 10,000 characters)
//   - to: recipient address for token transfer
//   - tokenPath: path of the token to transfer
//   - amount: amount of tokens to transfer
//
// Returns:
//   - int64: unique ID of the created proposal
//
// Panics:
//   - if proposer doesn't have enough voting weight
//   - if proposer has an active proposal
//   - if input validation fails
//   - if token is not registered
//
// ref: https://docs.gnoswap.io/contracts/governance/proposal.gno#proposecommunitypoolspend
func ProposeCommunityPoolSpend(
	cur realm,
	title string,
	description string,
	to std.Address,
	tokenPath string,
	amount int64,
) (newProposalId int64) {
	// Get caller information for proposal creation
	previousPkgPath := std.PreviousRealm().PkgPath()
	previousAddress := std.PreviousRealm().Address()
	callerAddress := std.PreviousRealm().Address()

	// Get current blockchain state
	createdAt := time.Now().Unix()
	createdHeight := std.ChainHeight()
	gnsBalance := gns.BalanceOf(callerAddress)

	// Retrieve current governance configuration
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

	// Get community pool package path for execution
	communityPoolPackagePath := consts.COMMUNITY_POOL_PATH

	// Create the community pool spend proposal with execution data
	proposal, err := createProposal(
		CommunityPoolSpend,
		config,
		maxVotingWeight,
		NewProposalMetadata(title, description),
		NewProposalCommunityPoolSpendData(tokenPath, to, amount, communityPoolPackagePath),
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
	std.Emit(
		"ProposeCommunityPoolSpend",
		"prevAddr", previousAddress.String(),
		"prevRealm", previousPkgPath,
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
// This type of proposal allows modifying governance and system parameters.
// The execution string format: <pkgPath>*EXE*<function>*EXE*<params>*GOV*<pkgPath>*EXE*<function>*EXE*<params>
// Multiple parameter changes can be batched using *GOV* separator.
//
// Parameters:
//   - cur: realm context for cross-realm calls
//   - title: proposal title (max 255 characters)
//   - description: detailed proposal description (max 10,000 characters)
//   - numToExecute: number of parameter changes to execute
//   - executions: encoded string containing execution instructions
//
// Returns:
//   - int64: unique ID of the created proposal
//
// Panics:
//   - if proposer doesn't have enough voting weight
//   - if proposer has an active proposal
//   - if input validation fails
//   - if execution string format is invalid
//
// ref: https://docs.gnoswap.io/contracts/governance/proposal.gno#proposeparameterchange
func ProposeParameterChange(
	cur realm,
	title string,
	description string,
	numToExecute int64,
	executions string,
) (newProposalId int64) {
	// Get caller information for proposal creation
	previousPkgPath := std.PreviousRealm().PkgPath()
	previousAddress := std.PreviousRealm().Address()
	callerAddress := std.PreviousRealm().Address()

	// Get current blockchain state
	createdAt := time.Now().Unix()
	createdHeight := std.ChainHeight()
	gnsBalance := gns.BalanceOf(callerAddress)

	// Retrieve current governance configuration
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
	std.Emit(
		"ProposeParameterChange",
		"prevAddr", previousAddress.String(),
		"prevRealm", previousPkgPath,
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

// createProposal is the internal function that handles proposal creation logic.
// This function validates input data, checks proposer eligibility, and creates the proposal object.
//
// Parameters:
//   - proposalType: type of proposal (Text, CommunityPoolSpend, ParameterChange)
//   - config: current governance configuration
//   - maxVotingWeight: total voting weight available at creation time
//   - proposalMetadata: title and description
//   - proposalData: type-specific proposal data
//   - proposerAddress: address of the proposer
//   - proposerGnsBalance: GNS balance of proposer
//   - createdAt: creation timestamp
//   - createdHeight: creation block height
//
// Returns:
//   - *Proposal: pointer to the created proposal
//   - error: creation error if any
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
// This function calculates voting weights at a specific time point for fair voting.
//
// Parameters:
//   - current: current timestamp
//   - smoothingPeriod: period to look back for weight calculation
//
// Returns:
//   - map[string]*VotingInfo: mapping of voter addresses to their voting info
//   - int64: total maximum voting weight
//   - bool: success flag
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
// This function integrates with the staker contract to get actual delegation amounts.
//
// Parameters:
//   - snapshotTime: time point for snapshot calculation
//
// Returns:
//   - map[string]*VotingInfo: mapping of voter addresses to their voting info
//   - int64: total maximum voting weight
//   - bool: success flag
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

// updateProposalUserVotes stores voting information for a specific proposal.
// This function links voting eligibility data to the proposal for later use during voting.
//
// Parameters:
//   - proposal: the proposal to associate voting info with
//   - userVotingInfos: mapping of user addresses to their voting information
//
// Returns:
//   - bool: success flag
func updateProposalUserVotes(
	proposal *Proposal,
	userVotingInfos map[string]*VotingInfo,
) bool {
	// Store the voting information mapping for this proposal
	proposalUserVotingInfos.Set(formatInt(proposal.ID()), userVotingInfos)

	return true
}

// hasActiveProposal checks if an address already has an active proposal.
// This enforces the one-proposal-per-address rule to prevent spam.
//
// Parameters:
//   - proposerAddress: address to check for active proposals
//   - current: current timestamp for activity check
//
// Returns:
//   - bool: true if address has an active proposal
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
