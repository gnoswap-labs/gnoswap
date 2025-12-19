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
func (p *ProposalVoteStatus) MaxVotingWeight() int64 { return p.maxVotingWeight }
func (p *ProposalVoteStatus) QuorumAmount() int64 { return p.quorumAmount }

// YesWeight returns the total weight of "yes" votes.
//
// Returns:
//   - int64: total "yes" vote weight
func (p *ProposalVoteStatus) YesWeight() int64 {
	return p.yea
}

// NoWeight returns the total weight of "no" votes.
//
// Returns:
//   - int64: total "no" vote weight
func (p *ProposalVoteStatus) NoWeight() int64 {
	return p.nay
}

/* Setter methods */
func (p *ProposalVoteStatus) SetYesWeight(yes int64) {
	p.yea = yes
}

func (p *ProposalVoteStatus) SetNoWeight(no int64) {
	p.nay = no
}

func (p *ProposalVoteStatus) SetMaxVotingWeight(maxVotingWeight int64) {
	p.maxVotingWeight = maxVotingWeight
}

func (p *ProposalVoteStatus) SetQuorumAmount(quorumAmount int64) {
	p.quorumAmount = quorumAmount
}

// NewProposalVoteStatus creates a new vote status for a proposal.
// Initializes vote tallies to zero and calculates the quorum requirement.
//
// Parameters:
//   - maxVotingWeight: maximum possible voting weight for this proposal
//   - quorum: quorum percentage required for passage (0-100)
//
// Returns:
//   - *ProposalVoteStatus: new vote status instance
func NewProposalVoteStatus(
	maxVotingWeight int64,
	quorum int64,
) *ProposalVoteStatus {
	// Calculate the absolute YES vote weight needed to meet quorum
	quorumAmount := maxVotingWeight * quorum / 100

	return &ProposalVoteStatus{
		yea:             0,               // Start with no "yes" votes
		nay:             0,               // Start with no "no" votes
		maxVotingWeight: maxVotingWeight, // Set maximum possible votes
		quorumAmount:    quorumAmount,    // Set required votes for passage
	}
}
