package gov

import (
	"std"
	"time"
)

func tally() {
	currentTime := uint64(time.Now().Unix())

	proposalQueue.Iterate("", "", func(key string, value interface{}) bool {
		proposalID := value.(uint64)
		proposal := GetProposal(proposalID)
		if proposal.process(currentTime) {
			return true
		}

		proposalQueue.Remove(key)
		proposals.Set(proposalKey(proposalID), proposal)
		return false
	})
}

// processes a single prooposal. assumes that the proposal is at the front of the queue
func (p *Proposal) process(currentTime uint64) (stop bool) {
	if !p.isActive() {
		return true
	}

	if !p.hasMetEndTime(currentTime) {
		return true
	}

	switch p.ProposalStatus {
	case ProposalStatusDepositPeriod:
		p.processDepositPeriod(currentTime)
		return false
	case ProposalStatusVotingPeriod:
		p.processVotingPeriod(currentTime)
		return false
	default: // ProposalStatusPassed, ProposalStatusRejected, ProposalStatusFailed
		// do nothing
	}

	return false
}

func (p *Proposal) processDepositPeriod(currentTime uint64) {
	if p.isDepositFailed() {
		p.transitFromDepositToFailed()
		return
	}

	if p.isDepositSuccessful() {
		p.transitFromDepositToVoting()
		p.refundDeposits()
		return
	}
}

func (p *Proposal) processVotingPeriod(currentTime uint64) {
	if p.isVotingRejected() {
		p.ProposalStatus = ProposalStatusRejected
		return
	}

	if p.isVotingPassed() {
		// be careful about reentrancy here
		// (especially on community pool spend with untrusted tokens)
		p.ProposalStatus = ProposalStatusPassed
		err := p.ProposalData.execute()
		// TODO: handle error
		return	
	}
}