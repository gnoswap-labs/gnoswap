package gov

import (
	"gno.land/r/gnos"
)

func UpdateVotingPower(address string, oldPower bigint, newPower bigint) {
	proposals, ok := votersMap.Get(address)
	if !ok {
		return
	}

	for iter := proposals.Iterate(); iter != nil; iter = iter.Next() {
		proposalIDKey := iter.Key()
		proposalInterface, ok := proposals.Get(proposalIDKey)
		if !ok {
			panic("Bug: proposal is not retrievable from proposalVotersMap")
		}
		proposal := proposalInterface.(*Proposal)
		if !proposal.isActive() {
			continue
		}
		proposal.updateVotingPower(oldPower, newPower)
		setProposal(proposalID, proposal)
	}
}

func Vote(proposalID uint64, option VoteOption) {
	caller := std.GetOrigCaller()
	amount := gnos.BalanceOf(caller)

	proposal := GetProposal(proposalID)
	proposal.vote(caller, option, amount)
	if proposal.isVotingPassed() {
		proposal.transitFromVotingToPassed()
	}
	if proposal.isVotingRejected() {
		proposal.transitFromVotingToRejected()
	}

	setProposal(proposalID, proposal)

}

func Deposit(proposalID uint64, amount uint64) {
	caller := std.GetOrigCaller()
	gnos.Transfer(caller, gov, amount)

	proposal := GetProposal(proposalID)
	proposal.deposit(caller, amount)

	setProposal(proposalID, proposal)
}

func GetProposal(proposalID uint64) Proposal {
	ps := getProposalState(proposalID)
	return ps.Proposal
}

func GetActiveProposals() []Proposal {
	// TODO
	return nil
}

func SubmitProposalText(
	title string,
	summary string,
	metadata string,
	initialDeposit bigint,
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
	initialDeposit bigint,

	recipient string,
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
	initialDeposit bigint,

	recipient string,
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

func SubmitProposalEmergencyHalt(
	title string,
	summary string,
	metadata string,
	initialDeposit bigint,

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

// Intended to be called by realms
func SubmitProposalParameterChanges(
	title string,
	summary string,
	metadata string,
	initialDeposit bigint,

	changes []ParameterChange,
) uint64 {
	realm := std.GetPrevRealm()

	data := ProposalParameterChange{
		Changes: []ParameterChange{
			ParameterChange{
				Realm: realm,
				Key: key,
				Value: parameter,
			}
		}
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
	initialDeposit bigint,
	data ProposalData,
) uint64 {
	origin := std.GetOrigCaller()

	gnos.Transfer(origin, gov, initialDeposit)

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

	proposalDepositorsMap.Put(proposalID, avl.NewTree())
	proposalVotersMap.Put(proposalID, avl.NewTree())

	// initializes proposals and proposalQueue
	setProposal(proposalID, proposal)

	return proposalID
}