package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/staker"
)

// unStakeTokenParams is the parameters for the ExactOutSwapRoute fuzz test.
type unStakeTokenParams struct {
	positionID   uint64
	unwrapResult bool
}

func (p *unStakeTokenParams) ToString() string {
	return ufmt.Sprintf("positionID: %d, unwrapResult: %v", p.positionID, p.unwrapResult)
}

func (p *unStakeTokenParams) IsValid() bool {
	return p.isValidStake()
}

func (p *unStakeTokenParams) isValidStake() bool {
	positionInfo, exist := position.GetPosition(p.positionID)
	if !exist {
		return false
	}

	poolPath := positionInfo.PoolKey()

	poolTier := staker.GetPoolTier(poolPath)
	if poolTier > 0 {
		return true
	}

	poolTiers := staker.GetPoolIncentiveIdList(poolPath)
	if len(poolTiers) > 0 {
		return true
	}

	return false
}

func NewValidUnStakeTokenParams(t *fuzz.T, positionID uint64) *unStakeTokenParams {
	return &unStakeTokenParams{
		positionID:   positionID,
		unwrapResult: false,
	}
}
