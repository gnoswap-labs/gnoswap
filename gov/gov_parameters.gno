package gov

import (
	"std"
)

type VoteQuorum struct {
	Numerator   uint64
	Denominator uint64
}

func Init() {
	parameters = make(map[string]interface{})

	// 1/3 quorum initially
	setVoteQuorum(VoteQuorum{1000, 3000})
	// 3 day initially
	setVotePeriod(259200)
	// 1 day initially
	setDepositPeriod(86400)
	// 10_000_000 GNS initially
	setDepositMinimum(uint64(10_000_000))
}

func getVoteQuorum() VoteQuorum {
	param, ok := getGovParameter("vote_quorum")
	if !ok {
		panic("[GOV] gov_parameters.gno__getVoteQuorum() || vote_quorum parameter not set")
	}

	return param.(VoteQuorum)
}

func setVoteQuorum(quorum VoteQuorum) {
	SetGovParameter("vote_quorum", quorum)
}

func getVotePeriod() uint64 {
	param, ok := getGovParameter("vote_period")
	if !ok {
		panic("[GOV] gov_parameters.gno__getVotePeriod() || vote_period parameter not set")
	}

	return param.(uint64)
}

func setVotePeriod(period uint64) {
	SetGovParameter("vote_period", period)
}

func getDepositPeriod() uint64 {
	param, ok := getGovParameter("deposit_period")
	if !ok {
		panic("[GOV] gov_parameters.gno__getDepositPeriod() || deposit_period parameter not set")
	}

	return param.(uint64)
}

func setDepositPeriod(period uint64) {
	SetGovParameter("deposit_period", period)
}

func getDepositMinimum() uint64 {
	param, ok := getGovParameter("deposit_minimum")
	if !ok {
		panic("[GOV] gov_parameters.gno__getDepositMinimum() || deposit_minimum parameter not set")
	}

	return param.(uint64)
}

func setDepositMinimum(minimum uint64) {
	SetGovParameter("deposit_minimum", minimum)
}

// SubmitProposalParameterChanges uses std.PrevRealm() to know which realm to submit the proposal to.
// For gov, two realms are the same, so the PrevRealm() is referring to the one before gov.
// So we make a specialization for gov here, internally using std.CurrentRealm() instead.
func submitProposalGovParameterChanges(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,

	changes []ParameterChange,
) uint64 {
	govRealm := std.CurrentRealm()

	data := ProposalParameterChange{
		Realm:   govRealm,
		Changes: changes,
	}

	return submitProposal(
		title,
		summary,
		metadata,
		initialDeposit,
		data,
	)
}
func SubmitProposalGovParameterDepositMinimum(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,

	newDepositMinimum uint64,
) uint64 {
	return submitProposalGovParameterChanges(
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
	return submitProposalGovParameterChanges(
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
	return submitProposalGovParameterChanges(
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
	return submitProposalGovParameterChanges(
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
