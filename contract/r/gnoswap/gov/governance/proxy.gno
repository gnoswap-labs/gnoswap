package governance

// ProposeText creates a new text proposal
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

// ProposeCommunityPoolSpend creates a new community pool spending proposal
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

// ProposeParameterChange creates a new parameter change proposal
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

// Vote casts a vote on a proposal
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

// Execute executes a passed proposal
func Execute(
	cur realm,
	proposalId int64,
) int64 {
	return getImplementation().Execute(proposalId)
}

// Cancel cancels a proposal before voting begins
func Cancel(
	cur realm,
	proposalId int64,
) int64 {
	return getImplementation().Cancel(proposalId)
}

// Reconfigure updates the governance configuration
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
