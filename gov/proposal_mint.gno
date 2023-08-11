package gov 

import (
	gnos "gno.land/r/gnos" // GNOS, Gnoswap Share
)

//////////////////////////
// ProposalMint

var _ ProposalContent = (*ProposalMint)(nil)

type ProposalMint struct {
	Receiver Address
	Amount   uint64
	Token    Address
}

func (p ProposalMint) ProposalType() ProposalType {
	return ProposalTypeMint
}

func (p ProposalMint) isProposal() {}

func (p ProposalMint) isValid() bool {
	if p.Token != GNOS_TOKEN_ADDRESS {
		return false
	}
	return true
}

func (p ProposalMint) execute() error {
	if !p.isValid() {
		return errors.New("unimplemented: only GNOS token is supported")
	}

	gnos.Mint(receiver.Address, receiver.Amount)

	return nil
}