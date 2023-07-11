package gov

import (
	"gno.land/r/pool"
)

//////////////////////////
// ProposalSwapParameterProtocolFee

var _ Proposal = (*ProposalSwapParameterProtocolFee)(nil)

type ProtocolFeeChange struct {
	Token0 string
	Token1 string
	Fee bigint
	NewProtocolFee0 bigint
	NewProtocolFee1 bigint
}

type ProposalSwapParameterProtocolFee struct {
	ProtocolFeeChanges []ProtocolFeeChange
}

func (p ProposalSwapParameterProtocolFee) ProposalType() ProposalType {
	return ProposalTypeSwapParameterProtocolFee
}

func (p ProposalSwapParameterProtocolFee) isProposal() {}

func (p ProposalSwapParameterProtocolFee) isValid() bool {
	for _, change := range p.ProtocolFeeChanges {
		if change.Token0 == "" {
			return false
		}

		if change.Token1 == "" {
			return false
		}

		if change.Token0 >= change.Token1 {
			return false
		}

		if change.Fee == 0 {
			return false
		}

		// TODO: do we want to allow 0 protocol fee?
		/*
		if change.NewProtocolFee0 == 0 {
			return false
		}

		if change.NewProtocolFee1 == 0 {
			return false
		}
		*/
	}
}

func (p ProposalSwapParameterProtocolFee) execute() error {
	for _, change := range p.ProtocolFeeChanges {
		err := pool.SetFeeProtocol(change.TokenA, change.TokenB, change.Fee, change.NewProtocolFee)
		if err != nil {
			return err
		}
	}

	return nil
}