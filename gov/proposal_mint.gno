package gov 

import (
	"std"

	"errors"

	gnos "gno.land/r/gnos" // GNOS, Gnoswap Share
)

//////////////////////////
// ProposalMint

var _ ProposalData = (*ProposalMint)(nil)

type ProposalMint struct {
	Recipient std.Address
	Amount   uint64
	Token    std.Address
}

func (p ProposalMint) ProposalType() ProposalType {
	return ProposalTypeMint
}

func (p ProposalMint) isProposalData() {}

func (p ProposalMint) isValid() bool {
	// XXXXXX
	/*
	if p.Token != GNOS_TOKEN_ADDRESS {
		return false
	}
	*/
	return true
}

func (p ProposalMint) execute() error {
	if !p.isValid() {
		return errors.New("unimplemented: only GNOS token is supported")
	}

	mint(p.Recipient, p.Amount)

	return nil
}