package gov

type VoteOption uint8 

const (
	VoteNil VoteOption = iota
	VoteAbstain
	VoteNo
	VoteYes
)

type Vote struct {
	VoteOption VoteOption
	Power    bigint
}

// returns true if vote was successful
// returns false if proposal is not in voting period
// if the vote type is the same with the existing vote, no-op.
// otherwise, the {Yes, No, Abstain}Votes of the proposal is updated accordingly with the voter's power.
func (p Proposal) vote(vote VoteOption) bool {
	panic("unimplemented")
}

// checks if the vote have met the pass condition
// this does not mean the proposal has passed, as the voting period may not have ended yet.
//
// returns true if:
// - proposal is in voting period
// - (YesVotes+NoVotes)/totalVotingPower >= VoteQuorumNumerator/VoteQuorumDenominator
// - YesVotes > NoVotes
func (p Proposal) isPassConditionMet(totalVotingPower bigint) bool {
	panic("unimplemented")	
}

// checks if proposal has passed
// returns true if:
// - proposal is in voting period
// - VotingEndTime has passed
// - proposal.isPassConditionMet() returns true
func (p Proposal) isVotingPassed() bool {
	panic("unimplemented")
}

// checks if proposal has failed
// returns true if:
// - proposal is in voting period
// - VotingEndTime has passed
// - proposal.isPassConditionMet() returns false
func (p Proposal) isVotingRejected() bool {
	panic("unimplemented")
}

// updates the proposal to reflect the voting power change of a voter.
// assumes that the voting type has not been changed.
func (p *Proposal) reflectVotingPowerUpdate(oldVotingPower, newVotingPower bigint) {
	panic("unimplemented")
}

