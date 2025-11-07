package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/staker"
)

// collectRewardParams is the parameters for the ExactOutSwapRoute fuzz test.
type collectRewardParams struct {
	positionID   uint64
	unwrapResult bool
}

func (p *collectRewardParams) ToString() string {
	return ufmt.Sprintf("positionID: %d, unwrapResult: %v", p.positionID, p.unwrapResult)
}

func (p *collectRewardParams) IsValid() bool {
	return p.isValidStake()
}

func (p *collectRewardParams) isValidStake() bool {
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

func NewValidCollectRewardParams(t *fuzz.T, positionID uint64) *collectRewardParams {
	return &collectRewardParams{
		positionID:   positionID,
		unwrapResult: false,
	}
}
