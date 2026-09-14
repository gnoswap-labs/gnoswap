package governance

import bptree "gno.land/p/nt/bptree/v0"

// Proposal represents a governance proposal with all its associated data and state.
// This is the core structure that tracks proposal lifecycle from creation to execution.
type Proposal struct {
	id            int64
	proposer      address
	configVersion int64
	status        ProposalStatus
	metadata      ProposalMetadata
	data          ProposalData
	snapshotTime  int64
	createdHeight int64
}

// ID returns the unique identifier of the proposal.
func (p Proposal) ID() int64 {
	return p.id
}

// Type returns the type of this proposal.
func (p Proposal) Type() ProposalType {
	return p.data.ProposalType()
}

// Title returns the proposal title.
func (p Proposal) Title() string {
	return p.metadata.Title()
}

// Description returns the proposal description.
func (p Proposal) Description() string {
	return p.metadata.Description()
}

// Proposer returns the address of the proposal creator.
func (p Proposal) Proposer() address {
	return p.proposer
}

// CreatedHeight returns the block height the proposal was created at.
func (p Proposal) CreatedHeight() int64 {
	return p.createdHeight
}

// CreatedAt returns the creation timestamp of the proposal.
func (p Proposal) CreatedAt() int64 {
	return p.status.Schedule().CreateTime()
}

// VotingYesWeight returns the total weight of "yes" votes.
func (p Proposal) VotingYesWeight() int64 {
	return p.status.VoteStatus().YesWeight()
}

// VotingNoWeight returns the total weight of "no" votes.
func (p Proposal) VotingNoWeight() int64 {
	return p.status.VoteStatus().NoWeight()
}

// VotingQuorumAmount returns minimum vote weight required for proposal to pass.
func (p Proposal) VotingQuorumAmount() int64 {
	return p.status.VoteStatus().QuorumAmount()
}

// VotingMaxWeight returns maximum possible voting weight for this proposal.
func (p Proposal) VotingMaxWeight() int64 {
	return p.status.VoteStatus().MaxVotingWeight()
}

// ConfigVersion returns the governance configuration version used for this proposal.
func (p Proposal) ConfigVersion() int64 {
	return p.configVersion
}

// SnapshotTime returns the snapshot time for voting weight lookup.
func (p Proposal) SnapshotTime() int64 {
	return p.snapshotTime
}

// Data returns the type-specific proposal data value.
func (p Proposal) Data() ProposalData {
	return p.data
}

// Status returns the proposal status value.
func (p Proposal) Status() ProposalStatus {
	return p.status
}

// Metadata returns the inline proposal metadata value.
func (p Proposal) Metadata() ProposalMetadata {
	return p.metadata
}

// WithData returns a copy with updated proposal data.
func (p Proposal) WithData(data ProposalData) Proposal {
	p.data = data
	return p
}

// WithStatus returns a copy with updated proposal status.
func (p Proposal) WithStatus(status ProposalStatus) Proposal {
	p.status = status
	return p
}

// WithMetadata returns a copy with updated proposal metadata.
func (p Proposal) WithMetadata(metadata ProposalMetadata) Proposal {
	p.metadata = metadata
	return p
}

// IsTextType checks if this is a text proposal.
func (p Proposal) IsTextType() bool {
	return p.Type() == Text
}

// IsCommunityPoolSpendType checks if this is a community pool spend proposal.
func (p Proposal) IsCommunityPoolSpendType() bool {
	return p.Type() == CommunityPoolSpend
}

// IsParameterChangeType checks if this is a parameter change proposal.
func (p Proposal) IsParameterChangeType() bool {
	return p.Type() == ParameterChange
}

// IsProposer checks if the given address is the proposer of this proposal.
func (p Proposal) IsProposer(addr address) bool {
	return p.proposer == addr
}

// MakeProposal creates a new proposal value with the provided parameters.
func MakeProposal(
	proposalID int64,
	status ProposalStatus,
	metadata ProposalMetadata,
	data ProposalData,
	proposerAddress address,
	configVersion int64,
	snapshotTime int64,
	createdHeight int64,
) Proposal {
	return Proposal{
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

// DefaultProposal returns an empty proposal value for unsuccessful lookups and operations.
func DefaultProposal() Proposal {
	return Proposal{}
}

func NewProposalTree() *bptree.BPTree {
	return bptree.NewBPTreeN(16)
}

func NewUserProposalTree() *bptree.BPTree {
	return bptree.NewBPTreeN(16)
}

func NewVotingInfoTree() *bptree.BPTree {
	return bptree.NewBPTreeN(16)
}

func NewProposalUserVotingInfoTree() *bptree.BPTree {
	return bptree.NewBPTreeN(16)
}
