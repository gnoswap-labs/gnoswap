package gov

var _ ProposalData = (*ProposalDataGovParameterDepositPeriod)(nil)

type ProposalDataGovParameterDepositPeriod struct {
	NewDepositPeriod uint64
}

func (p ProposalDataGovParameterDepositPeriod) ProposalType() ProposalType {
	return ProposalTypeGovParameterDepositPeriod
}

func (p ProposalDataGovParameterDepositPeriod) isProposalData() {}

func (p ProposalDataGovParameterDepositPeriod) isValid() bool {
	return p.NewDepositPeriod > 0
}

func (p ProposalDataGovParameterDepositPeriod) execute() error {
	setDepositPeriod(p.NewDepositPeriod)
	return nil
}