package governance

import bptree "gno.land/p/nt/bptree/v0"

// Proposal represents a governance proposal with all its associated data and state.
// This is the core structure that tracks proposal lifecycle from creation to execution.
type Proposal struct {
	id            int64             // Unique identifier for the proposal
	proposer      address           // The address of the proposer
	configVersion int64             // The version of the governance config used
	status        *ProposalStatus   // Current status and voting information
	metadata      *ProposalMetadata // Title and description
	data          *ProposalData     // Type-specific proposal data
	snapshotTime  int64             // Timestamp for voting weight snapshot lookup
	createdHeight int64             // Block height at creation
}

// ID returns the unique identifier assigned to the proposal.
//
// Returns:
//   - int64: proposal identifier used as its storage key
func (p *Proposal) ID() int64 {
	return p.id
}

// Type returns the proposal's type discriminator from its type-specific data.
//
// Returns:
//   - ProposalType: proposal kind, such as text, community-pool spend, or parameter change
func (p *Proposal) Type() ProposalType {
	return p.data.ProposalType()
}

// Title returns the proposal title stored in its metadata.
//
// Returns:
//   - string: proposal title
func (p *Proposal) Title() string {
	return p.metadata.Title()
}

// Description returns the proposal description stored in its metadata.
//
// Returns:
//   - string: proposal description
func (p *Proposal) Description() string {
	return p.metadata.Description()
}

// Proposer returns the address that created the proposal.
//
// Returns:
//   - address: proposal creator's address
func (p *Proposal) Proposer() address {
	return p.proposer
}

// CreatedHeight returns the block height at which the proposal was created.
//
// Returns:
//   - int64: proposal creation block height
func (p *Proposal) CreatedHeight() int64 {
	return p.createdHeight
}

// CreatedAt returns the proposal creation timestamp recorded in its schedule.
//
// Returns:
//   - int64: proposal creation timestamp
func (p *Proposal) CreatedAt() int64 {
	return p.status.schedule.createTime
}

// VotingYesWeight returns the total weight recorded for "yes" votes.
//
// Returns:
//   - int64: current "yes" vote weight
func (p *Proposal) VotingYesWeight() int64 {
	return p.status.voteStatus.yea
}

// VotingNoWeight returns the total weight recorded for "no" votes.
//
// Returns:
//   - int64: current "no" vote weight
func (p *Proposal) VotingNoWeight() int64 {
	return p.status.voteStatus.nay
}

// VotingQuorumAmount returns the minimum total vote weight required to pass.
//
// Returns:
//   - int64: quorum vote weight required by this proposal's configuration
func (p *Proposal) VotingQuorumAmount() int64 {
	return p.status.voteStatus.quorumAmount
}

// VotingMaxWeight returns the maximum voting weight recorded for this proposal.
//
// Returns:
//   - int64: maximum voting weight used for the proposal's quorum calculation
func (p *Proposal) VotingMaxWeight() int64 {
	return p.status.voteStatus.maxVotingWeight
}

// ConfigVersion returns the governance configuration version used by the proposal.
//
// Returns:
//   - int64: configuration version captured when the proposal was created
func (p *Proposal) ConfigVersion() int64 {
	return p.configVersion
}

// SnapshotTime returns the timestamp used to look up historical voting weight.
//
// Returns:
//   - int64: voting-weight snapshot timestamp
func (p *Proposal) SnapshotTime() int64 {
	return p.snapshotTime
}

// Data returns the proposal's type-specific data.
//
// Returns:
//   - *ProposalData: type-specific proposal data stored on the proposal
func (p *Proposal) Data() *ProposalData {
	return p.data
}

// Status returns the proposal's schedule, vote, and action status.
//
// Returns:
//   - *ProposalStatus: mutable aggregate status associated with the proposal
func (p *Proposal) Status() *ProposalStatus {
	return p.status
}

// Metadata returns the proposal's title and description metadata.
//
// Returns:
//   - *ProposalMetadata: metadata stored on the proposal
func (p *Proposal) Metadata() *ProposalMetadata {
	return p.metadata
}

// IsTextType reports whether the proposal is a text proposal.
//
// Returns:
//   - bool: true when the proposal type is Text
func (p *Proposal) IsTextType() bool {
	return p.Type() == Text
}

// IsCommunityPoolSpendType reports whether the proposal spends community-pool funds.
//
// Returns:
//   - bool: true when the proposal type is CommunityPoolSpend
func (p *Proposal) IsCommunityPoolSpendType() bool {
	return p.Type() == CommunityPoolSpend
}

// IsParameterChangeType reports whether the proposal changes governance parameters.
//
// Returns:
//   - bool: true when the proposal type is ParameterChange
func (p *Proposal) IsParameterChangeType() bool {
	return p.Type() == ParameterChange
}

// IsProposer reports whether addr matches the proposal's proposer address.
//
// Parameters:
//   - addr: address to compare with the proposal proposer
//
// Returns:
//   - bool: true when addr is the proposal proposer
func (p *Proposal) IsProposer(addr address) bool {
	return p.proposer == addr
}

// NewProposal creates a new proposal instance with the supplied identity,
// lifecycle, metadata, and type-specific data.
//
// Parameters:
//   - proposalID: unique identifier assigned to the proposal
//   - status: initial schedule, action, and voting status
//   - metadata: proposal title and description metadata
//   - data: type-specific proposal data
//   - proposerAddress: address of the proposal creator
//   - configVersion: governance configuration version captured for the proposal
//   - snapshotTime: timestamp anchor for historical voting-weight lookup
//   - createdHeight: block height at which the proposal was created
//
// Returns:
//   - *Proposal: newly initialized proposal containing the supplied fields
func NewProposal(
	proposalID int64,
	status *ProposalStatus,
	metadata *ProposalMetadata,
	data *ProposalData,
	proposerAddress address,
	configVersion int64,
	snapshotTime int64,
	createdHeight int64,
) *Proposal {
	return &Proposal{
		id:            proposalID,
		proposer:      proposerAddress,
		status:        status,
		metadata:      metadata,
		data:          data,
		configVersion: configVersion,
		snapshotTime:  snapshotTime,
		createdHeight: createdHeight,
	}
}

// Clone returns a deep copy of the proposal, including its type-specific data
// and nested execution messages.
//
// The returned proposal and all nested status, metadata, data, and message
// values are independent copies; mutating the clone does not mutate realm state.
//
// Returns:
//   - *Proposal: independent proposal copy, or nil when the receiver is nil
func (p *Proposal) Clone() *Proposal {
	if p == nil {
		return nil
	}

	return &Proposal{
		id:            p.id,
		proposer:      p.proposer,
		configVersion: p.configVersion,
		status:        p.status.Clone(),
		metadata:      p.metadata.Clone(),
		data:          p.data.Clone(),
		snapshotTime:  p.snapshotTime,
		createdHeight: p.createdHeight,
	}
}

// NewProposalTree creates an empty B+ tree for proposals keyed by proposal ID.
//
// Returns:
//   - *bptree.BPTree: empty 16-way proposal tree
func NewProposalTree() *bptree.BPTree {
	return bptree.NewBPTreeN(16)
}

// NewUserProposalTree creates an empty B+ tree mapping users to proposal IDs.
//
// Returns:
//   - *bptree.BPTree: empty 16-way user-proposal index tree
func NewUserProposalTree() *bptree.BPTree {
	return bptree.NewBPTreeN(16)
}

// NewVotingInfoTree creates an empty B+ tree for per-user voting information.
//
// Returns:
//   - *bptree.BPTree: empty 16-way voting-information tree
func NewVotingInfoTree() *bptree.BPTree {
	return bptree.NewBPTreeN(16)
}

// NewProposalUserVotingInfoTree creates an empty B+ tree mapping proposal IDs
// to their per-user voting-information trees.
//
// Returns:
//   - *bptree.BPTree: empty 16-way proposal voting-information index tree
func NewProposalUserVotingInfoTree() *bptree.BPTree {
	return bptree.NewBPTreeN(16)
}
