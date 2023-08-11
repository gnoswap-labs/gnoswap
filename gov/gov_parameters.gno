package gov

type VoteQuorum struct {
	Numerator   uint64
	Denominator uint64
}

func getVoteQuorum() VoteQuorum {
	param, ok := getGovParameter("vote_quorum")
	if !ok {
		panic("vote_quorum parameter not set")	
	}
	
	return param.(VoteQuorum)
}

func setVoteQuorum(quorum VoteQuorum) {
	setGovParameter("vote_quorum", quorum)
}

func getVotePeriod() uint64 {
	param, ok := getGovParameter("vote_period")
	if !ok {
		panic("vote_period parameter not set")	
	}

	return param.(uint64)
}

func setVotePeriod(period uint64) {
	setGovParameter("vote_period", period)
}

func getDepositPeriod() uint64 {
	param, ok := getGovParameter("deposit_period")
	if !ok {
		panic("deposit_period parameter not set")	
	}

	return param.(uint64)
}

func setDepositPeriod(period uint64) {
	setGovParameter("deposit_period", period)
}

func getDepositMinimum() uint64 {
	param, ok := getGovParameter("deposit_minimum")
	if !ok {
		panic("deposit_minimum parameter not set")	
	}

	return param.(uint64)
}

func setDepositMinimum(minimum uint64) {
	setGovParameter("deposit_minimum", minimum)
}

func init() {
	// 1/3 quorum initially
	setVoteQuorum(VoteQuorum{1000, 3000})
	// 3 day initially
	setVotePeriod(259200)
	// 1 day initially
	setDepositPeriod(86400)
	// 10000000 GNOS initially
	setDepositMinimum(uint64(10000000))
}

func SubmitProposalGovParameterDepositMinimum(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,

	newDepositMinimum uint64,
) uint64 {
	return SubmitProposalParameterChanges(
		title,
		summary,
		metadata,
		initialDeposit,
		[]ParameterChange{
			ParameterChange{
				"deposit_minimum",
				newDepositMinimum,
			},
		},
	)
}

func SubmitProposalGovParameterDepositPeriod(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,

	newDepositPeriod uint64,
) uint64 {
	return SubmitProposalParameterChanges(
		title,
		summary,
		metadata,
		initialDeposit,

		[]ParameterChange{
			ParameterChange{
				"deposit_period",
				newDepositPeriod,
			},
		},
	)
}

func SubmitProposalGovParameterVotingPeriod(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64, 

	newVotingPeriod uint64,
) uint64 {
	return SubmitProposalParameterChanges(
		title,
		summary,
		metadata,
		initialDeposit,

		[]ParameterChange{
			ParameterChange{
				"voting_period",
				newVotingPeriod,
			},
		},
	)
}

func SubmitProposalGovParameterVoteQuorum(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,

	newVoteQuorumNumerator uint64,
	newVoteQuorumDenominator uint64,
) uint64 {
	return SubmitProposalParameterChanges(
		title,
		summary,
		metadata,
		initialDeposit,

		[]ParameterChange{
			ParameterChange{
				"vote_quorum",
				VoteQuorum{
					newVoteQuorumNumerator,
					newVoteQuorumDenominator,
				},
			},
		},
	)
}