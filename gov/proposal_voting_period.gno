package gov

var _ ProposalData = (*ProposalDataGovParameterVotingPeriod)(nil)

type ProposalDataGovParameterVotingPeriod struct {
	NewVotingPeriod uint64
}

func (p ProposalDataGovParameterVotingPeriod) ProposalType() ProposalType {
	return ProposalTypeGovParameterVotingPeriod
}

func (p ProposalDataGovParameterVotingPeriod) isProposalData() {}

func (p ProposalDataGovParameterVotingPeriod) isValid() bool {
	return p.NewVotingPeriod > 0
}

func (p ProposalDataGovParameterVotingPeriod) execute() error {
	setVotingPeriod(p.NewVotingPeriod)
	return nil
}