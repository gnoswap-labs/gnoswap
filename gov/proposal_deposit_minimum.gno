package gov

var _ ProposalData = (*ProposalDataGovParameterDepositMinimum)(nil)

type ProposalDataGovParameterDepositMinimum struct {
	NewDepositMinimumNumerator bigint
	NewDepositMinimumDenominator bigint
}

func (p ProposalDataGovParameterDepositMinimum) ProposalType() ProposalType {
	return ProposalTypeGovParameterDepositMinimum
}

func (p ProposalDataGovParameterDepositMinimum) isProposalData() {}

func (p ProposalDataGovParameterDepositMinimum) isValid() bool {
	return p.NewDepositMinimumNumerator > 0 && p.NewDepositMinimumDenominator > 0
}

func (p ProposalDataGovParameterDepositMinimum) execute() error {
	setDepositMinimum(p.NewDepositMinimumNumerator, p.NewDepositMinimumDenominator)
	return nil
}