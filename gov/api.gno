package gov

import (
	"std"

	"gno.land/r/gnos"

	"gno.land/p/demo/avl"

	"fmt"
)

func UpdateVotingPower(address string, newPower uint64) {
	votesInterface, ok := votersMap.Get(address)
	if !ok {
		return
	}

	votes := votesInterface.(*avl.Tree)
	
	votes.Iterate("", "", func(key string, value interface{}) bool {	
		proposalInterface, ok := proposals.Get(key)
		if !ok {
			panic("Bug: proposal is not retrievable from proposalVotersMap")
		}
		proposal := proposalInterface.(*Proposal)
		if !proposal.isActive() {
			return false
		}
		vote := value.(Vote)
		proposal.updateVotingPower(vote.VoteOption, vote.Power, newPower)
		proposals.Set(key, proposal)

		return false
	})
}

func MakeVote(proposalID uint64, option VoteOption) {
	caller := std.GetOrigCaller()
	amount := balanceOf(caller) 

	proposal := GetProposal(proposalID)
	proposal.vote(caller, option, amount)

	setProposal(proposal)
}

func MakeDeposit(proposalID uint64, amount uint64) {
	caller := std.GetOrigCaller()
	///////////// XX
	// commented out, replace `gov` with the address of the gov contract
	// gnos.Transfer(users.AddressOrName(caller), gov, amount)

	proposal := GetProposal(proposalID)
	proposal.deposit(caller, amount)

	setProposal(proposal)
}

func GetActiveProposals() []Proposal {
	// TODO
	return nil
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
	data := ProposalCommunityPoolSpend {
		Recipient: recipient,
		Amount: amount,
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
		Amount: amount,
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
		Realm: realm,
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

	// XXXXXXXX
	// commented out, replace `gov` with the address of the gov contract
	// gnos.Transfer(origin, gov, initialDeposit)

	proposalID := getNextProposalID()

	proposal := newProposal(
		proposalID,
		origin,

		initialDeposit,

		title,
		summary,
		metadata,

		data,
	)
	key := proposalKey(proposalID)

	proposalDepositsMap.Set(key, []Deposit{})
	proposalVotesMap.Set(key, avl.NewTree())

	// initializes proposals and proposalQueue
	setProposal(proposal)
	return proposalID
}