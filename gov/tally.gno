package gov

/*
func tally(currentTime uint64) {
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
*/

// processes a single prooposal
func (p *Proposal) process(currentTime uint64) (stop bool) {
	if !p.isActive() {
		return true
	}

	// deposit minimum met, transit even if it's not end time
	if p.isDepositSuccessful() {
		p.transitFromDepositToVoting(currentTime)
		p.refundDeposits()
		proposalsMap[p.ProposalID] = *p
		return false
	}

	if !p.hasMetEndTime(currentTime) {
		return true
	}

	switch p.ProposalStatus {
	case ProposalStatusDepositPeriod:
		p.processDepositPeriod(currentTime)
	case ProposalStatusVotingPeriod:
		p.processVotingPeriod(currentTime)
	default: // ProposalStatusPassed, ProposalStatusRejected, ProposalStatusFailed
		// do nothing
	}

	proposalsMap[p.ProposalID] = *p

	return false
}

func (p *Proposal) processDepositPeriod(currentTime uint64) {
	if p.isDepositFailed(currentTime) {
		p.transitFromDepositToFailed()
		return
	}

	if p.isDepositSuccessful() {
		p.transitFromDepositToVoting(currentTime)
		p.refundDeposits()
		return
	}

	panic("[GOV] tally.gno__processDepositPeriod() || unreachable: proposal should be either in failed or successful after met deposit end time")
}

func (p *Proposal) processVotingPeriod(currentTime uint64) {
	if p.isVotingRejected(currentTime) {
		p.ProposalStatus = ProposalStatusRejected
		return
	}

	if p.isVotingPassed(currentTime) {
		// be careful about reentrancy here
		// (especially on community pool spend with untrusted tokens)
		p.ProposalStatus = ProposalStatusPassed
		err := p.ProposalData.execute()
		// TODO: handle error
		return
	}
}
