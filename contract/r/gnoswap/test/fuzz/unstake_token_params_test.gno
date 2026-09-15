package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// unStakeTokenParams contains parameters for the UnStakeToken fuzz test.
type unStakeTokenParams struct {
	positionID   uint64
	unwrapResult bool

	isStaked bool
}

func (p *unStakeTokenParams) ToString() string {
	return ufmt.Sprintf("positionID: %d, isStaked: %v", p.positionID, p.isStaked)
}

func (p *unStakeTokenParams) IsValid() bool {
	return p.isValidStake()
}

func (p *unStakeTokenParams) isValidStake() bool {
	return p.isStaked
}

func NewValidUnStakeTokenParams(t *fuzz.T, positionID uint64, isStaked bool) *unStakeTokenParams {
	return &unStakeTokenParams{
		positionID:   positionID,
		unwrapResult: false,
		isStaked:     isStaked,
	}
}
