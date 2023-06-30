package gov 

import (
	"gno.land/r/pool"
	"gno.land/r/staker"
)

//////////////////////////
// ProposalDataEmergencyHalt

var _ ProposalData = (*ProposalDataEmergencyHalt)(nil)

type ProposalDataEmergencyHalt struct {
	HaltPool bool
	HaltStaker bool
	HaltGov bool
}

func (p ProposalDataEmergencyHalt) ProposalType() ProposalType {
	return ProposalTypeEmergencyHalt
}

func (p ProposalDataEmergencyHalt) isProposalData() {}

func (p ProposalDataEmergencyHalt) isValid() bool {
	return true
}

func (p ProposalDataEmergencyHalt) execute() error {
	if p.HaltPool {
		pool.Halt()
	}

	if p.HaltStaker {
		staker.Halt()
	}

	if p.HaltGov {
		halt()
	}

	return nil
}