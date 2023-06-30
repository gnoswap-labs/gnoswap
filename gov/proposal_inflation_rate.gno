package gov

import (
	"gno.land/r/pool"
)

var _ ProposalData = (*ProposalDataSwapParameterInflationRate)(nil)

type ProposalDataSwapParameterInflationRate struct {
	NewInflationRate bigint
}

func (p ProposalDataGovParameterDepositPeriod) ProposalType() ProposalType {
	return ProposalTypeGovParameterDepositPeriod
}

func (p ProposalDataGovParameterDepositPeriod) isProposalData() {}

func (p ProposalDataSwapParameterInflationRate) isValid() bool {
	// TODO: set some hard limit?
	return true
}

func (p ProposalDataSwapParameterInflationRate) execute() error {
	return pool.SetInflationRate(p.NewInflationRate)
}