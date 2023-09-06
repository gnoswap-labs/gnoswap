package gov

import (
	"fmt"
	"std"
	"testing"
	"time"

	"gno.land/r/gnos"
)

func TestSubmitProposal(t *testing.T) {
	Init()

	id := SubmitProposalText(
		"title",    // title
		"summary",  // summary
		"metadata", // metadata
		0,          // initial deposit
	)

	now := uint64(time.Now().Unix())

	if id != 1 {
		panic("proposal id should be 1")
	}
	proposal := &proposalsMap[id]

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

	if proposal.DepositEndTime != now+getDepositPeriod() {
		panic(fmt.Sprintf("proposal deposit end time should be now + deposit period, %d, %d", proposal.DepositEndTime, now+getDepositPeriod()))
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

func TestSubmitProposalFailedDeposit(t *testing.T) {
	id := SubmitProposalText(
		"title",
		"summary",
		"metadata",
		0,
	)

	proposal := &proposalsMap[id]
	now := uint64(time.Now().Unix())

	// Proposal.process should halt if deposit period has not ended
	if !proposal.process(now + getDepositPeriod() - 1) {
		panic("proposal process should halt")
	}

	// force advance to voting period
	// failing due to insufficient deposit
	proposal.TotalDeposit = getDepositMinimum() - 1

	if proposal.process(now + getDepositPeriod() + 1) {
		panic("proposal process should halt")
	}

	if proposal.ProposalStatus != ProposalStatusFailed {
		panic(fmt.Sprintf("proposal status should be failed: %d", proposal.ProposalStatus))
	}
}

func TestSubmitProposalRejected(t *testing.T) {
	id := SubmitProposalText(
		"title",
		"summary",
		"metadata",
		0,
	)

	proposal := &proposalsMap[id]
	now := uint64(time.Now().Unix())

	// Proposal.process should halt if deposit period has not ended
	if !proposal.process(now + getDepositPeriod() - 1) {
		panic("proposal process should halt")
	}

	// force advance to voting period
	proposal.TotalDeposit = getDepositMinimum() + 1

	if proposal.process(now + getDepositPeriod() + 1) {
		panic("proposal process should halt")
	}

	// Proposal.process should halt if voting period has not ended
	if !proposal.process(now + getDepositPeriod() + 1 + getVotePeriod() - 1) {
		panic("proposal process should halt")
	}

	// force advance to voting failed
	proposal.YesVotes = 0
	proposal.NoVotes = 100

	if proposal.process(now + getDepositPeriod() + 1 + getVotePeriod() + 1) {
		panic("proposal process should not halt")
	}

	if proposal.ProposalStatus != ProposalStatusRejected {
		panic(fmt.Sprintf("proposal status should be rejected: %d", proposal.ProposalStatus))
	}
}

func TestSubmitProposalCommunityPoolSpend(t *testing.T) {
	std.TestSetOrigCaller(std.CurrentRealm().Addr())
	gnos.Faucet()

	initialBalance := balanceOf(std.CurrentRealm().Addr())

	id := SubmitProposalCommunityPoolSpend(
		"title",
		"summary",
		"metadata",
		0,
		std.Address("recipient"),
		100,
	)

	proposal := &proposalsMap[id]

	if proposal.ProposalType != ProposalTypeCommunityPoolSpend {
		panic("proposal type should be community pool spend")
	}

	if proposal.ProposalStatus != ProposalStatusDepositPeriod {
		panic("proposal status should be deposit period")
	}

	// force advance to voting period
	proposal.TotalDeposit = getDepositMinimum() + 1

	if proposal.process(uint64(time.Now().Unix()) + getDepositPeriod() + 1) {
		panic("proposal process should not halt")
	}

	// force advance to voting passed
	proposal.YesVotes = 100
	proposal.NoVotes = 0

	if proposal.process(uint64(time.Now().Unix()) + getDepositPeriod() + 1 + getVotePeriod() + 1) {
		panic("proposal process should not halt")
	}

	if proposal.ProposalStatus != ProposalStatusPassed {
		panic(fmt.Sprintf("proposal status should be passed: %d", proposal.ProposalStatus))
	}

	if balanceOf(std.Address("recipient")) != 100 {
		panic("recipient balance should be 100")
	}

	if balanceOf(std.CurrentRealm().Addr()) != initialBalance-100 {
		panic("caller balance should be initial balance - 100")
	}
}

func TestSubmitProposalMint(t *testing.T) {
	// Commented out: needs to be admin to mint
	/*
		std.TestSetOrigCaller(std.CurrentRealm().Addr())

		id := SubmitProposalMint(
			"title",
			"summary",
			"metadata",
			0,
			std.Address("recipient"),
			100,
		)

		proposal := &proposalsMap[id]

		if proposal.ProposalType != ProposalTypeMint {
			panic("proposal type should be community pool spend")
		}

		if proposal.ProposalStatus != ProposalStatusDepositPeriod {
			panic("proposal status should be deposit period")
		}

		// force advance to voting period
		proposal.TotalDeposit = getDepositMinimum() + 1

		if proposal.process(uint64(time.Now().Unix()) + getDepositPeriod() + 1) {
			panic("proposal process should not halt")
		}

		// force advance to voting passed
		proposal.YesVotes = 100
		proposal.NoVotes = 0

		if proposal.process(uint64(time.Now().Unix()) + getDepositPeriod() + 1 + getVotePeriod() + 1) {
			panic("proposal process should not halt")
		}

		if proposal.ProposalStatus != ProposalStatusPassed {
			panic(fmt.Sprintf("proposal status should be passed: %d", proposal.ProposalStatus))
		}

		if balanceOf(std.Address("recipient")) != 100 {
			panic("recipient balance should be 100")
		}
	*/
}

func TestProposalParameterChange(t *testing.T) {
	initialDepositMinimum := getDepositMinimum()

	id := SubmitProposalGovParameterDepositMinimum(
		"title",
		"summary",
		"metadata",
		0,

		100,
	)

	proposal := &proposalsMap[id]

	if proposal.ProposalType != ProposalTypeParameterChange {
		panic("proposal type should be community pool spend")
	}

	if proposal.ProposalStatus != ProposalStatusDepositPeriod {
		panic("proposal status should be deposit period")
	}

	// force advance to voting period
	proposal.TotalDeposit = getDepositMinimum() + 1

	if proposal.process(uint64(time.Now().Unix()) + getDepositPeriod() + 1) {
		panic("proposal process should not halt")
	}

	// force advance to voting passed
	proposal.YesVotes = 100
	proposal.NoVotes = 0

	if proposal.process(uint64(time.Now().Unix()) + getDepositPeriod() + 1 + getVotePeriod() + 1) {
		panic("proposal process should not halt")
	}

	if proposal.ProposalStatus != ProposalStatusPassed {
		panic(fmt.Sprintf("proposal status should be passed: %d", proposal.ProposalStatus))
	}

	if getDepositMinimum() != 100 {
		panic(fmt.Sprintf("new deposit minimum should be 100, %d", getDepositMinimum()))
	}
}

// Test scenario:
// units in hours
// 00: [p0 submit]
// 12: [p1 submit]
// 18: [p1 deposit success]
// 20: [p2 submit]
// 24: [p0 deposit fail]
// 36: [p3 submit]
// 40: [p2 deposit success]
// 48: [p3 deposit success]
// 80: [p1 voting reject]
// 112: [p2 voting pass]
// 120: [p3 voting pass]
func TestProposalTally(t *testing.T) {
	hour := uint64(86400)
	now := uint64(time.Now().Unix())

	clock := now
	p0 := testSubmitTextProposalCustomTime(
		"p0",
		"summary",
		"metadata",
		0,
		clock,
	)

	clock = now + 12*hour
	p1 := testSubmitTextProposalCustomTime(
		"p1",
		"summary",
		"metadata",
		0,
		clock,
	)

	clock = now + 18*hour
	// force advance to voting period
	{
		proposal := &proposalsMap[p1]
		proposal.TotalDeposit = getDepositMinimum() + 1
		proposalsMap[proposal.ProposalID] = *proposal

		proposal.process(clock)

		if proposal.ProposalStatus != ProposalStatusVotingPeriod {
			panic(fmt.Sprintf("18: proposal status should be voting period, %d", proposal.ProposalStatus))
		}
	}

	clock = now + 20*hour
	p2 := testSubmitTextProposalCustomTime(
		"p2",
		"summary",
		"metadata",
		0,
		clock,
	)

	clock = now + 24*hour + 1
	// force advance to deposit fail
	{
		proposal := &proposalsMap[p0]

		proposal.process(clock)

		if proposal.ProposalStatus != ProposalStatusFailed {
			panic(fmt.Sprintf("24: proposal status should be failed, %d", proposal.ProposalStatus))
		}
	}

	clock = now + 36*hour
	p3 := testSubmitTextProposalCustomTime(
		"p3",
		"summary",
		"metadata",
		0,
		clock,
	)

	clock = now + 40*hour
	// force advance to voting period
	{
		proposal := &proposalsMap[p2]
		proposal.TotalDeposit = getDepositMinimum() + 1
		proposalsMap[proposal.ProposalID] = *proposal

		proposal.process(clock)

		if proposal.ProposalStatus != ProposalStatusVotingPeriod {
			panic("40: proposal status should be voting period")
		}
	}
	clock = now + 48*hour
	// force advance to voting period
	{
		proposal := &proposalsMap[p3]
		proposal.TotalDeposit = getDepositMinimum() + 1
		proposalsMap[proposal.ProposalID] = *proposal

		proposal.process(clock)

		if proposal.ProposalStatus != ProposalStatusVotingPeriod {
			panic("48: proposal status should be voting period")
		}
	}

	clock = now + 80*hour + 1
	// force advance to voting reject
	{

		proposal := &proposalsMap[p1]

		proposal.YesVotes = 0
		proposal.NoVotes = 100
		proposalsMap[proposal.ProposalID] = *proposal

		proposal.process(clock)

		if proposal.ProposalStatus != ProposalStatusRejected {
			panic("80: proposal status should be rejected")
		}
	}

	clock = now + 112*hour + 1
	// force advance to voting pass
	{
		proposal := &proposalsMap[p2]
		proposal.YesVotes = 100
		proposal.NoVotes = 0
		proposalsMap[proposal.ProposalID] = *proposal

		proposal.process(clock)

		if proposal.ProposalStatus != ProposalStatusPassed {
			panic("112: proposal status should be passed")
		}
	}

	clock = now + 120*hour + 1
	// force advance to voting pass
	{
		proposal := &proposalsMap[p3]
		proposal.YesVotes = 100
		proposal.NoVotes = 0
		proposalsMap[proposal.ProposalID] = *proposal

		proposal.process(clock)

		if proposal.ProposalStatus != ProposalStatusPassed {
			panic("120: proposal status should be passed")
		}
	}
}

func testSubmitTextProposalCustomTime(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,
	currentTime uint64,
) uint64 {
	// copied from api.gno/submitProposal

	origin := std.GetOrigCaller()

	proposalID := getNextProposalID()

	proposal := newProposal(
		proposalID,
		origin,

		initialDeposit,

		title,
		summary,
		metadata,

		ProposalText{},
	)

	proposal.SubmitTime = currentTime
	proposal.DepositEndTime = currentTime + getDepositPeriod()

	proposalDepositsMap[proposalID] = []Deposit{}
	proposalVotesMap[proposalID] = map[string]Vote{}

	// initializes proposals and proposalQueue
	proposalsMap[proposal.ProposalID] = *proposal
	return proposalID
}
