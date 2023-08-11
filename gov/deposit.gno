package gov

import (
	"std"
	"time"
)

// entry point for deposit on a proposal
func (p *Proposal) deposit(depositor std.Address, amount uint64) bool {
	if !p.isDepositPeriod() {
		return false
	}
	
	if p.ProposalStatus != ProposalStatusDepositPeriod {
		panic("Bug: Proposal.deposit() called on a proposal not in deposit period")
	}

	if amount < getDepositMinimum() {
		return false
	}

	key := proposalKey(p.ProposalID)

	proposalDepositsInterface, ok := proposalDepositsMap.Get(key)
	if !ok {
		proposalDepositsInterface = []Deposit{}
	}
	proposalDeposits := proposalDepositsInterface.([]Deposit)
	proposalDeposits = append(proposalDeposits, Deposit{depositor, amount})
	proposalDepositsMap.Set(key, proposalDeposits)
	p.TotalDeposit += amount

	return true
}

func (p *Proposal) refundDeposits() {
	depositsInterface, ok := proposalDepositsMap.Get(proposalKey(p.ProposalID))
	if !ok {
		return
	}

	deposits := depositsInterface.([]Deposit)
	for _, deposit := range deposits {
		transfer(deposit.Depositor, deposit.Amount)
	}

	proposalDepositsMap.Remove(proposalKey(p.ProposalID))
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
func (p *Proposal) transitFromDepositToVoting() {
	p.ProposalStatus = ProposalStatusVotingPeriod
	p.VotingStartTime = uint64(time.Now().Unix())
	p.VotingEndTime = p.VotingStartTime + getVotePeriod()
}

// checks if proposal has failed to meet deposit minumum
// returns true if:
// - proposal is still in deposit period
// - proposal deposit end time has passed
// - proposal has failed to meet deposit minimum
func (p Proposal) isDepositFailed() bool {
	return p.isDepositPeriod() && uint64(time.Now().Unix()) > p.DepositEndTime && p.TotalDeposit < getDepositMinimum()
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