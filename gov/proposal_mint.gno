package gov 

import (
	gnos "gno.land/r/gnos" // GNOS, Gnoswap Share
)

//////////////////////////
// ProposalMint

var _ ProposalContent = (*ProposalMint)(nil)

type ProposalMint struct {
	Receiver 
}

func (p ProposalMint) ProposalType() ProposalType {
	return ProposalTypeMint
}

func (p ProposalMint) isProposal() {}

func (p ProposalMint) isValid() bool {
	for _, receiver := range p.MintReceivers {
		if receiver.Token != GNOS_TOKEN_ADDRESS {
			return false
		}
	}
	return true
}

func (p ProposalMint) execute() error {
	if !p.isValid() {
		return errors.New("unimplemented: only GNOS token is supported")
	}

	for _, receiver := range p.MintReceivers {
		gnos.Mint(receiver.Address, receiver.Amount)
	}

	return nil
}