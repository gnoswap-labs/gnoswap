package gov 

//////////////////////////
// ProposalText

var _ ProposalData = ProposalText{} 

type ProposalText struct {
	// (empty)
}

func (p ProposalText) ProposalType() ProposalType {
	return ProposalTypeText
}

func (p ProposalText) isProposalData() {}

func (p ProposalText) execute() error {
	return nil
}