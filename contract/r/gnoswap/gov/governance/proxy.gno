package governance

// ProposeText creates a new text proposal for general governance decisions.
//
// Parameters:
//   - title: proposal title
//   - description: detailed proposal description
//
// Returns:
//   - int64: ID of the created proposal
func ProposeText(
	cur realm,
	title string,
	description string,
) int64 {
	return getImplementation().ProposeText(
		title,
		description,
	)
}

// ProposeCommunityPoolSpend creates a new community pool spending proposal.
//
// Parameters:
//   - title: proposal title
//   - description: detailed proposal description
//   - to: recipient address
//   - tokenPath: token path to transfer
//   - amount: amount to transfer
//
// Returns:
//   - int64: ID of the created proposal
func ProposeCommunityPoolSpend(
	cur realm,
	title string,
	description string,
	to address,
	tokenPath string,
	amount int64,
) int64 {
	return getImplementation().ProposeCommunityPoolSpend(
		title,
		description,
		to,
		tokenPath,
		amount,
	)
}

// ProposeParameterChange creates a new parameter change proposal.
//
// Parameters:
//   - title: proposal title
//   - description: detailed proposal description
//   - numToExecute: number of executions to perform
//   - executions: encoded execution messages
//
// Returns:
//   - int64: ID of the created proposal
func ProposeParameterChange(
	cur realm,
	title string,
	description string,
	numToExecute int64,
	executions string,
) int64 {
	return getImplementation().ProposeParameterChange(
		title,
		description,
		numToExecute,
		executions,
	)
}

// Vote casts a vote on a proposal.
//
// Parameters:
//   - proposalId: ID of the proposal to vote on
//   - yes: true for yes vote, false for no vote
//
// Returns:
//   - string: voting result information
func Vote(
	cur realm,
	proposalId int64,
	yes bool,
) string {
	return getImplementation().Vote(
		proposalId,
		yes,
	)
}

// Execute executes a passed proposal that is in the execution window.
//
// Parameters:
//   - proposalId: ID of the proposal to execute
//
// Returns:
//   - int64: execution result code
func Execute(
	cur realm,
	proposalId int64,
) int64 {
	return getImplementation().Execute(proposalId)
}

// Cancel cancels a proposal before voting begins.
// Only callable by the proposer.
//
// Parameters:
//   - proposalId: ID of the proposal to cancel
//
// Returns:
//   - int64: cancellation result code
func Cancel(
	cur realm,
	proposalId int64,
) int64 {
	return getImplementation().Cancel(proposalId)
}

// Reconfigure updates the governance configuration parameters.
// Only callable by admin or governance.
//
// Parameters:
//   - votingStartDelay: delay before voting starts (seconds)
//   - votingPeriod: voting duration (seconds)
//   - votingWeightSmoothingDuration: weight smoothing duration (seconds)
//   - quorum: minimum voting weight required (percentage)
//   - proposalCreationThreshold: minimum weight to create proposal
//   - executionDelay: delay before execution (seconds)
//   - executionWindow: execution time window (seconds)
//
// Returns:
//   - int64: new configuration version
func Reconfigure(
	cur realm,
	votingStartDelay int64,
	votingPeriod int64,
	votingWeightSmoothingDuration int64,
	quorum int64,
	proposalCreationThreshold int64,
	executionDelay int64,
	executionWindow int64,
) int64 {
	return getImplementation().Reconfigure(
		votingStartDelay,
		votingPeriod,
		votingWeightSmoothingDuration,
		quorum,
		proposalCreationThreshold,
		executionDelay,
		executionWindow,
	)
}
