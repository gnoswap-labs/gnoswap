package gov


func (p *Proposal) deposit(depositor Address, amount bigint) bool {
	panic("unimplemented")
}

func (p *Proposal) isDepositPeriod() bool {
	return p.Status == ProposalStatusDepositPeriod
}

// checks if proposal has meet deposit minimum
// returns true if:
// - proposal is still in deposit period
// - proposal has met deposit minimum
func (p Proposal) isDepositSuccessful() bool {
	panic("unimplemented")
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
	panic("unimplemented")
}

// checks if proposal has failed to meet deposit minumum
// returns true if:
// - proposal is still in deposit period
// - proposal deposit end time has passed
// - proposal has failed to meet deposit minimum
func (p Proposal) isDepositFailed() bool {
	panic("unimplemented")
}

// returns updated proposal to be in failed state
// should be called only if p.isDepositFailed() returns true
// updates:
// - ProposalStatus set to ProposalStatusFailed
// - Other fields are left unchanged
// this function panics if called on an invalid proposal 
func (p *Proposal) transitionFromDepositToFailed() {
	panic("unimplemented")
}