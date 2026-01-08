package staker

import (
	"strings"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/nt/ufmt"
)

// stakeTokenParams is the parameters for the ExactOutSwapRoute fuzz test.
type stakeTokenParams struct {
	positionID            uint64
	internalIncentiveTier uint64
	externalIncentiveIds  []string
}

func (p *stakeTokenParams) ToString() string {
	externalIncentiveIds := strings.Join(p.externalIncentiveIds, ",")
	return ufmt.Sprintf("positionID: %d, internalIncentiveTier: %d, externalIncentiveIds: %s", p.positionID, p.internalIncentiveTier, externalIncentiveIds)
}

func (p *stakeTokenParams) IsValid() bool {
	return p.isValidStake()
}

func (p *stakeTokenParams) isValidStake() bool {
	if p.internalIncentiveTier > 0 {
		return true
	}

	if len(p.externalIncentiveIds) > 0 {
		return true
	}

	return false
}

func (p *stakeTokenParams) setInternalIncentiveTier(tier uint64) {
	p.internalIncentiveTier = tier
}

func (p *stakeTokenParams) addExternalIncentiveId(id string) {
	p.externalIncentiveIds = append(p.externalIncentiveIds, id)
}

func NewValidStakeTokenParams(t *fuzz.T, positionID uint64) *stakeTokenParams {
	return &stakeTokenParams{
		positionID:            positionID,
		internalIncentiveTier: 0,
		externalIncentiveIds:  make([]string, 0),
	}
}
