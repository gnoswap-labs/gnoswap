package gov

import (
	"gno.land/r/gnos"
)

func Vote(proposalID uint64, option VoteOption) {
	caller := std.GetOrigCaller()
	gnos.
}

func Deposit(proposalID uint64, amount uint64) {
	// TODO
}

func GetProposal(proposalID uint64) Proposal {
	// TODO
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

	setProposal(proposalID, proposal)

	return proposalID
}