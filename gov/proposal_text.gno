package gov 

//////////////////////////
// ProposalText

var _ Proposal = (*ProposalText)(nil)

type ProposalText struct {
	// (empty)
}

func (p ProposalText) ProposalType() ProposalType {
	return ProposalTypeText
}

func (p ProposalText) isProposal() {}

func (p ProposalText) execute() {
	// do nothing
}