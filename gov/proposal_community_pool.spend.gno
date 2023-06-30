package gov 

import (
	gnos "gno.land/r/gnos" // GNOS, Gnoswap Share
)

//////////////////////////
// ProposalDataCommunityPoolSpend

var _ ProposalData = (*ProposalDataCommunityPoolSpend)(nil)

type ProposalDataCommunityPoolSpend struct {
	Token     Address
	Recipient Address
	Amount    bigint
}

func (p ProposalDataCommunityPoolSpend) ProposalType() ProposalType {
	return ProposalTypeCommunityPoolSpend
}

func (p ProposalDataCommunityPoolSpend) isProposalData() {}

func (p ProposalDataCommunityPoolSpend) isValid() bool {
	if p.Token != GNOS_TOKEN_ADDRESS {
		return false
	}
}

func (p ProposalDataCommunityPoolSpend) execute() error {
	if p.Token != GNOS_TOKEN_ADDRESS {
		return errors.New("unimplemented: only GNOS token is supported")
	}

	// TODO: if transfer failes, return error
	// TODO: we might need to whitelist set of tokens that can be transferred from the community pool, as some might panic on transfer
	gnos.Transfer(p.Recipient, p.Amount)

	return nil
}