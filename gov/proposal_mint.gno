package gov 

import (
	gnos "gno.land/r/gnos" // GNOS, Gnoswap Share
)

//////////////////////////
// ProposalDataMint

var _ ProposalData = (*ProposalDataMint)(nil)

type MintReceiver struct {
	Token  Address
	Address Address
	Amount  bigint
}

type ProposalDataMint struct {
	MintReceivers []MintReceiver
}

func (p ProposalDataMint) ProposalType() ProposalType {
	return ProposalTypeMint
}

func (p ProposalDataMint) isProposalData() {}

func (p ProposalDataMint) isValid() bool {
	for _, receiver := range p.MintReceivers {
		if receiver.Token != GNOS_TOKEN_ADDRESS {
			return false
		}
	}
	return true
}

func (p ProposalDataMint) execute() error {
	if !p.isValid() {
		return errors.New("unimplemented: only GNOS token is supported")
	}

	for _, receiver := range p.MintReceivers {
		gnos.Mint(receiver.Address, receiver.Amount)
	}

	return nil
}