package main

import (
	"fmt"
	"time"

	"gno.land/r/demo/gov"
)

func main() {
	TestSubmitProposal()

	// CANNOT TEST THE FOLLOWING DUE TO THE LACK OF `process` FUNCTION in the integration filetest
	// TestSubmitProposalFailedDeposit()
	// TestSubmitProposalRejected(nil)
	// TestSubmitProposalCommunityPoolSpend(nil)
	// TestSubmitProposalMint(nil)
	// TestProposalParameterChange(nil)
	// TestProposalTally(nil)
}

func TestSubmitProposal() {
	gov.Init()

	id := gov.SubmitProposalText(
		"title",    // title
		"summary",  // summary
		"metadata", // metadata
		0,          // initial deposit
	)

	now := uint64(time.Now().Unix())

	if id != 1 {
		panic("proposal id should be 1")
	}

	proposal := gov.GetProposalById(id)

	if proposal.Title != "title" {
		panic("proposal title should be title")
	}

	if proposal.Summary != "summary" {
		panic("proposal summary should be summary")
	}

	if proposal.Metadata != "metadata" {
		panic("proposal metadata should be metadata")
	}

	if proposal.ProposalStatus != gov.ProposalStatusDepositPeriod {
		panic("proposal status should be deposit period")
	}

	if proposal.SubmitTime != now {
		panic("proposal submit time should be now")
	}

	// 86400 == getDepositPeriod()
	if proposal.DepositEndTime != now+86400 {
		panic(fmt.Sprintf("proposal deposit end time should be now + deposit period, %d, %d", proposal.DepositEndTime, now+86400))
	}

	if proposal.VotingEndTime != 0 {
		panic("proposal voting end time should be 0")
	}

	if proposal.TotalDeposit != 0 {
		panic("proposal total deposits should be 0")
	}

	// 10_000_000 == getDepositMinimum()
	// force advance to voting period
	proposal.TotalDeposit = 10_000_000 + 1

	/*
		CAN NOT `process` in the integration filetest

		// 86400 == getDepositPeriod()
		if proposal.process(now + 86400 + 1) {
			panic("proposal process should not halt")
		}

		// force advance to voting passed
		proposal.YesVotes = 100
		proposal.NoVotes = 0

		// 259200 == getVotePeriod()
		if proposal.process(now + 86400 + 1 + 259200 + 1) {
			panic("proposal process should not halt")
		}
	*/
}

// OUTPUT:
//
