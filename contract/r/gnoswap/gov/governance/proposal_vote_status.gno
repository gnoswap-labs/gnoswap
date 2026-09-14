package governance

// ProposalVoteStatus tracks the voting tallies and requirements for a proposal.
// This structure manages vote counting, quorum calculation, and voting outcome determination.
type ProposalVoteStatus struct {
	yea             int64 // Total weight of "yes" votes collected
	nay             int64 // Total weight of "no" votes collected
	maxVotingWeight int64 // The max voting weight at the time of proposal creation
	quorumAmount    int64 // How many total votes must be collected for the proposal to be valid
}

/* Getter methods */
func (p ProposalVoteStatus) MaxVotingWeight() int64 { return p.maxVotingWeight }
func (p ProposalVoteStatus) QuorumAmount() int64    { return p.quorumAmount }

// YesWeight returns the total weight of "yes" votes.
func (p ProposalVoteStatus) YesWeight() int64 {
	return p.yea
}

// NoWeight returns the total weight of "no" votes.
func (p ProposalVoteStatus) NoWeight() int64 {
	return p.nay
}

/* Functional updates */
func (p ProposalVoteStatus) SetYesWeight(yes int64) ProposalVoteStatus {
	p.yea = yes
	return p
}

func (p ProposalVoteStatus) SetNoWeight(no int64) ProposalVoteStatus {
	p.nay = no
	return p
}

func (p ProposalVoteStatus) SetMaxVotingWeight(maxVotingWeight int64) ProposalVoteStatus {
	p.maxVotingWeight = maxVotingWeight
	return p
}

func (p ProposalVoteStatus) SetQuorumAmount(quorumAmount int64) ProposalVoteStatus {
	p.quorumAmount = quorumAmount
	return p
}

// MakeProposalVoteStatus creates a new vote status value with the supplied
// voting weight and quorum requirement. Vote tallies start at zero.
func MakeProposalVoteStatus(
	maxVotingWeight int64,
	quorumAmount int64,
) ProposalVoteStatus {
	return ProposalVoteStatus{
		maxVotingWeight: maxVotingWeight,
		quorumAmount:    quorumAmount,
	}
}
