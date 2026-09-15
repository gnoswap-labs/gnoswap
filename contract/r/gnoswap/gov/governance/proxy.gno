package governance

// ProposeText creates a new text proposal with the provided data.
//
// Parameters:
//   - cur: Live realm token; external realm callers pass cross(cur).
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
		0, cur,
		title,
		description,
	)
}

// ProposeCommunityPoolSpend creates a CommunityPoolSpend proposal with the provided data.
// The transfer is attempted when an approved proposal executes.
//
// Parameters:
//   - cur: Live realm token; external realm callers pass cross(cur).
//   - title: The title of the proposal.
//   - description: The description of the proposal.
//   - to: A valid address to receive the spent token.
//   - tokenPath: A registered token path.
//   - amount: A strictly positive amount in the token's smallest unit.
//
// The community-pool balance is checked at execution, not proposal creation.

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
		0, cur,
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
//   - cur: Live realm token; external realm callers pass cross(cur).
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
		0, cur,
		title,
		description,
		numToExecute,
		executions,
	)
}

// Vote allows a user to vote on a given proposal.
//
// The proposal's timestamp-based smoothing calculation determines the applied
// weight. A vote cannot be changed after it is recorded.
//
// Parameters:
//   - cur: Live realm token; external realm callers pass cross(cur).
//   - proposalId: The ID of the proposal to vote.
//   - yes: The flag to vote as yes or not.
//
// Returns:
//   - voteWeight: The caller's calculated vote weight, formatted as a decimal string.
func Vote(
	cur realm,
	proposalId int64,
	yes bool,
) string {
	return getImplementation().Vote(
		0, cur,
		proposalId,
		yes,
	)
}

// Execute executes the given proposal.
//
// Parameters:
//   - cur: Live realm token; external realm callers pass cross(cur).
//   - proposalId: The ID of the proposal to execute.
//
// Returns:
//   - proposalId: The ID of the proposal.
func Execute(
	cur realm,
	proposalId int64,
) int64 {
	return getImplementation().Execute(0, cur, proposalId)
}

// Cancel cancels the proposal with the given ID.
//
// Parameters:
//   - cur: Live realm token; external realm callers pass cross(cur).
//   - proposalId: The ID of the proposal to cancel.
//
// Returns:
//   - proposalId: The ID of the proposal.
func Cancel(
	cur realm,
	proposalId int64,
) int64 {
	return getImplementation().Cancel(0, cur, proposalId)
}

// RemoveInactiveProposalFromIndex removes an inactive proposal from the
// timestamp-ordered index without deleting its proposal or voting history.
func RemoveInactiveProposalFromIndex(cur realm, proposalID int64) {
	getImplementation().RemoveInactiveProposalFromIndex(0, cur, proposalID)
}

// Reconfigure updates the governance configuration parameters.
// Only callable by admin or governance.
//
// Parameters:
//   - cur: Live realm token; external realm callers pass cross(cur).
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
		0, cur,
		votingStartDelay,
		votingPeriod,
		votingWeightSmoothingDuration,
		quorum,
		proposalCreationThreshold,
		executionDelay,
		executionWindow,
	)
}
