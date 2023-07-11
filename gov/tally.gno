package gov

// processes a single prooposal. assumes that the proposal is at the front of the queue
func (p *Proposal) process(currentTime uint64) {
	if !p.isActive() {
		return
	}

	if !p.hasMetEndTime(currentTime) {
		return
	}

	switch p.ProposalStatus {
	case ProposalStatusDepositPeriod:
		return p.processDepositPeriod(currentTime)
	case ProposalStatusVotingPeriod:
		return p.processVotingPeriod(currentTime)
	default: // ProposalStatusPassed, ProposalStatusRejected, ProposalStatusFailed
		// do nothing
	}
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
		p.transitFromVotingToRejected()
		return
	}

	if p.isVotingPassed() {
		// be careful about reentrancy here
		// (especially on community pool spend with untrusted tokens)
		p.transitFromVotingToPassed()
		err := p.ProposalData.execute()
		// TODO: handle error
		return	
	}
}