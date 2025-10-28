package governance

// Proposal represents a governance proposal with all its associated data and state.
// This is the core structure that tracks proposal lifecycle from creation to execution.
type Proposal struct {
	id            int64             // Unique identifier for the proposal
	proposer      address           // The address of the proposer
	configVersion int64             // The version of the governance config used
	status        *ProposalStatus   // Current status and voting information
	metadata      *ProposalMetadata // Title and description
	data          *ProposalData     // Type-specific proposal data
	createdAt     int64             // Creation timestamp
	createdHeight int64             // Block height at creation
}

// ID returns the unique identifier of the proposal.
func (p *Proposal) ID() int64 {
	return p.id
}

// Type returns the type of this proposal.
func (p *Proposal) Type() ProposalType {
	return p.data.ProposalType()
}

// Title returns the proposal title.
func (p *Proposal) Title() string {
	return p.metadata.Title()
}

// Description returns the proposal description.
func (p *Proposal) Description() string {
	return p.metadata.Description()
}

// Proposer returns the address of the proposal creator.
func (p *Proposal) Proposer() address {
	return p.proposer
}

// CreatedAt returns the creation timestamp of the proposal.
func (p *Proposal) CreatedAt() int64 {
	return p.status.schedule.createTime
}

// VotingYesWeight returns the total weight of "yes" votes.
func (p *Proposal) VotingYesWeight() int64 {
	return p.status.voteStatus.yea
}

// VotingNoWeight returns the total weight of "no" votes.
func (p *Proposal) VotingNoWeight() int64 {
	return p.status.voteStatus.nay
}

// VotingTotalWeight returns total weight of all votes cast.
func (p *Proposal) VotingTotalWeight() int64 {
	return p.status.voteStatus.TotalVoteWeight()
}

// VotingQuorumAmount returns minimum vote weight required for proposal to pass.
func (p *Proposal) VotingQuorumAmount() int64 {
	return p.status.voteStatus.quorumAmount
}

// VotingMaxWeight returns maximum possible voting weight for this proposal.
func (p *Proposal) VotingMaxWeight() int64 {
	return p.status.voteStatus.maxVotingWeight
}

// ConfigVersion returns the governance configuration version used for this proposal.
func (p *Proposal) ConfigVersion() int64 {
	return p.configVersion
}

// Data returns the proposal data.
func (p *Proposal) Data() *ProposalData {
	return p.data
}

// Status returns the proposal status.
func (p *Proposal) Status() *ProposalStatus {
	return p.status
}

// Metadata returns the proposal metadata.
func (p *Proposal) Metadata() *ProposalMetadata {
	return p.metadata
}


// IsTextType checks if this is a text proposal.
func (p *Proposal) IsTextType() bool {
	return p.Type() == Text
}

// IsCommunityPoolSpendType checks if this is a community pool spend proposal.
func (p *Proposal) IsCommunityPoolSpendType() bool {
	return p.Type() == CommunityPoolSpend
}

// IsParameterChangeType checks if this is a parameter change proposal.
func (p *Proposal) IsParameterChangeType() bool {
	return p.Type() == ParameterChange
}

// IsProposer checks if the given address is the proposer of this proposal.
func (p *Proposal) IsProposer(addr address) bool {
	return p.proposer == addr
}

// NewProposal creates a new proposal instance with the provided parameters.
// NewProposal is the main constructor for creating governance proposals.
//   - metadata: proposal title and description
//   - data: type-specific proposal data
//   - proposerAddress: address of the proposal creator
//   - configVersion: governance configuration version
//   - createdAt: creation timestamp
//   - createdHeight: creation block height
//
// Returns:
//   - *Proposal: newly created proposal instance
func NewProposal(
	proposalID int64,
	status *ProposalStatus,
	metadata *ProposalMetadata,
	data *ProposalData,
	proposerAddress address,
	configVersion int64,
	createdAt int64,
	createdHeight int64,
) *Proposal {
	return &Proposal{
		id:            proposalID,
		proposer:      proposerAddress,
		status:        status,
		metadata:      metadata,
		data:          data,
		configVersion: configVersion,
		createdAt:     createdAt,
		createdHeight: createdHeight,
	}
}
