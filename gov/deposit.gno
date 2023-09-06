package gov

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"
)

// entry point for deposit on a proposal
func (p *Proposal) deposit(depositor std.Address, amount uint64) bool {
	if !p.isDepositPeriod() {
		return false
	}

	if p.ProposalStatus != ProposalStatusDepositPeriod {
		panic(ufmt.Sprintf("[GOV] deposit.gno__deposit() || called on a proposal not in deposit period__p.ProposalStatus(%s) != ProposalStatusDepositPeriod(%s)", p.ProposalStatus, ProposalStatusDepositPeriod))
	}

	if amount < getDepositMinimum() {
		return false
	}

	proposalDeposits := proposalDepositsMap[p.ProposalID]
	proposalDeposits = append(proposalDeposits, Deposit{depositor, amount})
	proposalDepositsMap[p.ProposalID] = proposalDeposits

	p.TotalDeposit += amount

	if p.isDepositSuccessful() {
		p.transitFromDepositToVoting(uint64(time.Now().Unix()))
	}

	return true
}

func (p *Proposal) refundDeposits() {

	deposits := proposalDepositsMap[p.ProposalID]

	for _, deposit := range deposits {
		transfer(deposit.Depositor, deposit.Amount)
	}

	delete(proposalDepositsMap, p.ProposalID)
}

func (p *Proposal) isDepositPeriod() bool {
	return p.ProposalStatus == ProposalStatusDepositPeriod
}

// checks if proposal has meet deposit minimum
// returns true if:
// - proposal is still in deposit period
// - proposal has met deposit minimum
func (p Proposal) isDepositSuccessful() bool {
	return p.isDepositPeriod() && p.TotalDeposit >= getDepositMinimum()
}

// updates proposal to be in voting period
// should be called only if p.isDepositSuccessful() returns true
// updates:
// - ProposalStatus set to ProposalStatusVotingPeriod
// - VotingStartTime set to current block time
// - VotingEndTime set to current block time + VotingPeriod
// - Other fields are left unchanged
// this function panics if called on an invalid proposal
func (p *Proposal) transitFromDepositToVoting(currentTime uint64) {
	p.ProposalStatus = ProposalStatusVotingPeriod
	p.VotingStartTime = currentTime
	p.VotingEndTime = p.VotingStartTime + getVotePeriod()
}

// checks if proposal has failed to meet deposit minumum
// returns true if:
// - proposal is still in deposit period
// - proposal deposit end time has passed
// - proposal has failed to meet deposit minimum
func (p Proposal) isDepositFailed(currentTime uint64) bool {
	return p.isDepositPeriod() && currentTime > p.DepositEndTime && p.TotalDeposit < getDepositMinimum()
}

// returns updated proposal to be in failed state
// should be called only if p.isDepositFailed() returns true
// updates:
// - ProposalStatus set to ProposalStatusFailed
// - Other fields are left unchanged
// this function panics if called on an invalid proposal
func (p *Proposal) transitFromDepositToFailed() {
	p.ProposalStatus = ProposalStatusFailed
}
