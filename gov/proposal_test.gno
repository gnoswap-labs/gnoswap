package gov

import (
	"testing"
	"time"
	"fmt"
)

func TestSubmitProposal(t *testing.T) {
	id := SubmitProposalText(
		"title",
		"summary",
		"metadata",
		0,
	)

	now := uint64(time.Now().Unix())

	if id != 1 {
		panic("proposal id should be 1")
	}
	proposal := GetProposal(id)

	if proposal.Title != "title" {
		panic("proposal title should be title")
	}

	if proposal.Summary != "summary" {
		panic("proposal summary should be summary")
	}

	if proposal.Metadata != "metadata" {
		panic("proposal metadata should be metadata")
	}

	if proposal.ProposalStatus != ProposalStatusDepositPeriod {
		panic("proposal status should be deposit period")
	}

	if proposal.SubmitTime != now {
		panic("proposal submit time should be now")
	}

	if proposal.DepositEndTime != now + getDepositPeriod() {
		panic(fmt.Sprintf("proposal deposit end time should be now + deposit period, %d, %d", proposal.DepositEndTime, now + getDepositPeriod()))
	}

	if proposal.VotingEndTime != 0 {
		panic("proposal voting end time should be 0")
	}

	if proposal.TotalDeposit != 0 {
		panic("proposal total deposits should be 0")
	}
	// force advance to voting period
	proposal.TotalDeposit = getDepositMinimum() + 1

	if proposal.process(now + getDepositPeriod() + 1) {
		panic("proposal process should not halt")
	}

	// force advance to voting passed
	proposal.YesVotes = 100
	proposal.NoVotes = 0

	if proposal.process(now + getDepositPeriod() + 1 + getVotePeriod() + 1) {
		panic("proposal process should not halt")
	}
}