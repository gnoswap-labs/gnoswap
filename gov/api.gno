package gov

import (
	"std"
)

func UpdateVotingPower(address string, newPower uint64) {
	votes := votersMap[address]

	for proposalID, vote := range votes {
		proposal := &proposalsMap[proposalID]

		proposal.updateVotingPower(vote.VoteOption, vote.Power, newPower)
		proposalsMap[proposal.ProposalID] = *proposal
	}

}

func MakeVote(proposalID uint64, option VoteOption) {
	caller := std.GetOrigCaller()
	amount := balanceOf(caller)

	proposal := &proposalsMap[proposalID]
	proposal.vote(caller, option, amount)

	proposalsMap[proposal.ProposalID] = *proposal
}

func MakeDeposit(proposalID uint64, amount uint64) {
	caller := std.GetOrigCaller()
	///////////// XX
	// commented out, replace `gov` with the address of the gov contract
	// gns.Transfer(users.AddressOrName(caller), gov, amount)

	proposal := &proposalsMap[proposalID]
	proposal.deposit(caller, amount)

	proposalsMap[proposal.ProposalID] = *proposal
}

func GetActiveProposals() []Proposal {
	// TODO
	return nil
}

func GetProposalById(proposalID uint64) *Proposal {
	return &proposalsMap[proposalID]
}

func SubmitProposalText(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,
) uint64 {
	data := ProposalText{}

	return submitProposal(
		title,
		summary,
		metadata,
		initialDeposit,
		data,
	)
}

func SubmitProposalCommunityPoolSpend(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,

	recipient std.Address,
	amount uint64,
) uint64 {
	data := ProposalCommunityPoolSpend{
		Recipient: recipient,
		Amount:    amount,
	}

	return submitProposal(
		title,
		summary,
		metadata,
		initialDeposit,
		data,
	)
}

func SubmitProposalMint(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,

	recipient std.Address,
	amount uint64,
) uint64 {
	data := ProposalMint{
		Recipient: recipient,
		Amount:    amount,
	}

	return submitProposal(
		title,
		summary,
		metadata,
		initialDeposit,
		data,
	)
}

/*
func SubmitProposalEmergencyHalt(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,

	haltPool bool,
	haltStaker bool,
	haltPosition bool,
) uint64 {
	data := ProposalEmergencyHalt{
		HaltPool: haltPool,
		HaltStaker: haltStaker,
		HaltPosition: haltPosition,
	}

	return submitProposal(
		title,
		summary,
		metadata,
		initialDeposit,
		data,
	)
}
*/

// Intended to be called by realms
func SubmitProposalParameterChanges(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,

	changes []ParameterChange,
) uint64 {
	realm := std.PrevRealm()

	data := ProposalParameterChange{
		Realm:   realm,
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

func submitProposal(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,
	data ProposalData,
) uint64 {
	origin := std.GetOrigCaller()

	proposalID := getNextProposalID()

	// XXXXXXXX
	// commented out, replace `gov` with the address of the gov contract
	// gns.Transfer(origin, gov, initialDeposit)
	proposal := newProposal(
		proposalID,
		origin,

		initialDeposit,

		title,
		summary,
		metadata,

		data,
	)

	proposalDepositsMap[proposalID] = []Deposit{}
	proposalVotesMap[proposalID] = map[string]Vote{}

	// initializes proposals and proposalQueue
	proposalsMap[proposal.ProposalID] = *proposal
	return proposalID
}
