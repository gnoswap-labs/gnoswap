package gov

import (
	"gno.land/r/pool"
)

//////////////////////////
// ProposalDataSwapParameterProtocolFee

var _ ProposalData = (*ProposalDataSwapParameterProtocolFee)(nil)

type ProposalDataSwapParameterProtocolFee struct {
	NewProtocolFee bigint
}

func (p ProposalDataSwapParameterProtocolFee) ProposalType() ProposalType {
	return ProposalTypeSwapParameterProtocolFee
}

func (p ProposalDataSwapParameterProtocolFee) isProposalData() {}

func (p ProposalDataSwapParameterProtocolFee) isValid() bool {
	// TODO: we might need to set a hard limit on the protocol fee?
	return true
}

func (p ProposalDataSwapParameterProtocolFee) execute() error {
	return pool.SetProtocolFee(p.NewProtocolFee)
}