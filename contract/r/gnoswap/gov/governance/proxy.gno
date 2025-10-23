package governance

// ProposeText creates a new text proposal
func ProposeText(
	cur realm,
	title string,
	description string,
) (uint64, error) {
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
	tokenPath string,
	toAddress address,
	amount uint64,
) (uint64, error) {
	return getImplementation().ProposeCommunityPoolSpend(
		title,
		description,
		tokenPath,
		toAddress,
		amount,
	)
}

// ProposeParameterChange creates a new parameter change proposal
func ProposeParameterChange(
	cur realm,
	title string,
	description string,
	changes string,
) (uint64, error) {
	return getImplementation().ProposeParameterChange(
		title,
		description,
		changes,
	)
}

// Vote casts a vote on a proposal
func Vote(
	cur realm,
	proposalId uint64,
	voteType uint8,
) error {
	return getImplementation().Vote(
		proposalId,
		voteType,
	)
}

// Execute executes a passed proposal
func Execute(
	cur realm,
	proposalId uint64,
) error {
	return getImplementation().Execute(
		proposalId,
	)
}

// Cancel cancels a proposal before voting begins
func Cancel(
	cur realm,
	proposalId uint64,
) error {
	return getImplementation().Cancel(
		proposalId,
	)
}

// Reconfigure updates the governance configuration
func Reconfigure(
	cur realm,
	votingStartDelay uint64,
	votingPeriod uint64,
	votingWeightSmoothingDuration uint64,
	quorum uint64,
	proposalCreationThreshold uint64,
	executionDelay uint64,
	executionWindow uint64,
) error {
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
