package gov 

import (
	"std"

	gnos "gno.land/r/gnos" // GNOS, Gnoswap Share
)

//////////////////////////
// ProposalCommunityPoolSpend

var _ ProposalData = (*ProposalCommunityPoolSpend)(nil)

type ProposalCommunityPoolSpend struct {
	Token     std.Address
	Recipient std.Address
	Amount    uint64
}

func (p ProposalCommunityPoolSpend) ProposalType() ProposalType {
	return ProposalTypeCommunityPoolSpend
}

func (p ProposalCommunityPoolSpend) isProposalData() {}

func (p ProposalCommunityPoolSpend) isValid() bool {
	/*
	if p.Token != GNOS_TOKEN_ADDRESS {
		return false
	}
	*/
}

func (p ProposalCommunityPoolSpend) execute() error {
	// XXXXXXXX
	// commented out, replace `GNOS_TOKEN_ADDRESS` with the address of the GNOS token contract
	/*
	if p.Token != GNOS_TOKEN_ADDRESS {
		return errors.New("unimplemented: only GNOS token is supported")
	}
	*/

	// TODO: if transfer failes, return error
	// TODO: we might need to whitelist set of tokens that can be transferred from the community pool, as some might panic on transfer
	transfer(p.Recipient, p.Amount)

	return nil
}