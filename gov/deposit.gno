package gov


// entry point for deposit on a proposal
func (p *Proposal) deposit(depositor Address, amount bigint) bool {
	if !p.isDepositPeriod() {
		return false
	}
	
	if p.Status != ProposalStatusDepositPeriod {
		panic("Bug: Proposal.deposit() called on a proposal not in deposit period")
	}

	if amount < getDepositMinimum() {
		return false
	}

	proposalDeposis, ok := proposalDepositsMap.Get(p.ID)
	if !ok {
		proposalDeposits = []Deposit{}
	}
	proposalDeposits = append(proposalDeposits, Deposit{depositor, amount})
	proposalDepositsMap.Set(p.ID, proposalDeposits)
	p.TotalDeposit += amount

	return true
}

func (p *Proposal) isDepositPeriod() bool {
	return p.Status == ProposalStatusDepositPeriod
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
	p.VotingStartTime = std.GetBlockTime()
	p.VotingEndTime = p.VotingStartTime + getVotingPeriod()
}

// checks if proposal has failed to meet deposit minumum
// returns true if:
// - proposal is still in deposit period
// - proposal deposit end time has passed
// - proposal has failed to meet deposit minimum
func (p Proposal) isDepositFailed() bool {
	return p.isDepositPeriod() && std.GetBlockTime() > p.DepositEndTime && p.TotalDeposit < getDepositMinimum()
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