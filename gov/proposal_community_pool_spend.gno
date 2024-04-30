package gov

import (
	"errors"
	"std"
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
	if p.Token != GNS_TOKEN_ADDRESS {
		return false
	}

	return true
}

func (p ProposalCommunityPoolSpend) execute() error {
	if p.Token != GNS_TOKEN_ADDRESS {
		return errors.New("unimplemented: only GNS token is supported")
	}

	// TODO: if transfer failes, return error
	// TODO: we might need to whitelist set of tokens that can be transferred from the community pool, as some might panic on transfer
	transfer(p.Recipient, p.Amount)

	return nil
}
