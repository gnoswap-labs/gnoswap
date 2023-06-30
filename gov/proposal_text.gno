package gov 

//////////////////////////
// ProposalDataText

var _ ProposalData = (*ProposalDataText)(nil)

type ProposalDataText struct {
	// (empty)
}

func (p ProposalDataText) ProposalType() ProposalType {
	return ProposalTypeText
}

func (p ProposalDataText) isProposalData() {}

func (p ProposalDataText) execute() {
	// do nothing
}