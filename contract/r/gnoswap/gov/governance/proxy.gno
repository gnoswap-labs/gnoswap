package governance

// ProposeText creates a new text proposal with the provided data.
//
// Parameters:
//   - title: The title of the proposal.
//   - description: The description of the proposal.
//
// Returns:
//   - proposalId: The ID of the proposal.
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

// ProposeCommunityPoolSpend creates a CommunityPoolSpend proposal with the provided data.
//
// Parameters:
//   - title: The title of the proposal.
//   - description: The description of the proposal.
//   - to: The address to receive the spent token.
//   - tokenPath: The path of the token to be sent.
//   - amount: The amount of the token to be sent.
//
// Returns:
//   - proposalId: The ID of the proposal.
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

// ProposeParameterChange creates a ParameterChange proposal with the provided data.
//
// Parameters:
//   - title: The title of the proposal.
//   - description: The description of the proposal.
//   - numToExecute: The number of changes to execute.
//   - executions: The list of changes to execute.
//
// Returns:
//   - proposalId: The ID of the proposal.
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

// Vote allows a user to vote on a given proposal.
//
// Parameters:
//   - proposalId: The ID of the proposal to vote.
//   - yes: The flag to vote as yes or not.
//
// Returns:
//   - voteKey: The key of the vote.
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

// Execute executes the given proposal.
//
// Parameters:
//   - proposalId: The ID of the proposal to execute.
//
// Returns:
//   - proposalId: The ID of the proposal.
func Execute(
	cur realm,
	proposalId int64,
) int64 {
	return getImplementation().Execute(proposalId)
}

// Cancel cancels the proposal with the given ID.
//
// Parameters:
//   - proposalId: The ID of the proposal to cancel.
//
// Returns:
//   - proposalId: The ID of the proposal.
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
