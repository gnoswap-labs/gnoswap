package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/staker"
)

// stakeTokenParams is the parameters for the ExactOutSwapRoute fuzz test.
type stakeTokenParams struct {
	positionID uint64
	referrer   string
}

func (p *stakeTokenParams) ToString() string {
	return ufmt.Sprintf("positionID: %d, referrer: %s", p.positionID, p.referrer)
}

func (p *stakeTokenParams) IsValid() bool {
	return p.isValidStake()
}

func (p *stakeTokenParams) isValidStake() bool {
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

func NewValidStakeTokenParams(t *fuzz.T, positionID uint64) *stakeTokenParams {
	return &stakeTokenParams{
		positionID: positionID,
		referrer:   "",
	}
}
