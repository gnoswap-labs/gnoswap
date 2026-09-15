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
// MaxVotingWeight returns the maximum voting weight captured for the proposal.
//
// Returns:
//   - int64: maximum voting weight used when evaluating the proposal's quorum.
func (p *ProposalVoteStatus) MaxVotingWeight() int64 { return p.maxVotingWeight }

// QuorumAmount returns the voting weight required for the proposal to satisfy quorum.
//
// Returns:
//   - int64: minimum total vote weight required by this proposal.
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
// SetYesWeight replaces the proposal's accumulated yes-vote weight.
//
// Parameters:
//   - yes: total weight to record for affirmative votes.
func (p *ProposalVoteStatus) SetYesWeight(yes int64) {
	p.yea = yes
}

// SetNoWeight replaces the proposal's accumulated no-vote weight.
//
// Parameters:
//   - no: total weight to record for negative votes.
func (p *ProposalVoteStatus) SetNoWeight(no int64) {
	p.nay = no
}

// SetMaxVotingWeight records the proposal's maximum voting-weight snapshot.
//
// Parameters:
//   - maxVotingWeight: maximum voting weight available when the proposal was created.
func (p *ProposalVoteStatus) SetMaxVotingWeight(maxVotingWeight int64) {
	p.maxVotingWeight = maxVotingWeight
}

// SetQuorumAmount records the proposal's quorum requirement.
//
// Parameters:
//   - quorumAmount: minimum total vote weight required for this proposal.
func (p *ProposalVoteStatus) SetQuorumAmount(quorumAmount int64) {
	p.quorumAmount = quorumAmount
}

// NewProposalVoteStatus creates a new vote status for a proposal.
// Initializes vote tallies to zero and calculates the quorum requirement.
//
// Parameters:
//   - maxVotingWeight: maximum possible voting weight for this proposal
//   - quorumAmount: quorum amount required for passage
//
// Returns:
//   - *ProposalVoteStatus: new vote status instance
func NewProposalVoteStatus(
	maxVotingWeight int64,
	quorumAmount int64,
) *ProposalVoteStatus {
	return &ProposalVoteStatus{
		yea:             0,               // Start with no "yes" votes
		nay:             0,               // Start with no "no" votes
		maxVotingWeight: maxVotingWeight, // Set maximum possible votes
		quorumAmount:    quorumAmount,    // Set required votes for passage
	}
}

// Clone returns an independent copy of the vote status, or nil when the receiver is nil.
//
// Returns:
//   - *ProposalVoteStatus: copied vote tallies and requirements, or nil for a nil receiver.
func (p *ProposalVoteStatus) Clone() *ProposalVoteStatus {
	if p == nil {
		return nil
	}

	return &ProposalVoteStatus{
		yea:             p.yea,
		nay:             p.nay,
		maxVotingWeight: p.maxVotingWeight,
		quorumAmount:    p.quorumAmount,
	}
}
