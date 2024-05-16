package gov

import (
	"std"

	"errors"
)

//////////////////////////
// ProposalMint

var _ ProposalData = (*ProposalMint)(nil)

type ProposalMint struct {
	Recipient std.Address
	Amount    uint64
	Token     std.Address
}

func (p ProposalMint) ProposalType() ProposalType {
	return ProposalTypeMint
}

func (p ProposalMint) isProposalData() {}

func (p ProposalMint) isValid() bool {

	if p.Token != GNS_TOKEN_ADDRESS {
		return false
	}

	return true
}

func (p ProposalMint) execute() error {
	if !p.isValid() {
		return errors.New("unimplemented: only GNS token is supported")
	}

	// mint(p.Recipient, p.Amount)

	return nil
}
