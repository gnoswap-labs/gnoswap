package staker

import (
	"time"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/common"
)

// collectRewardParams is the parameters for the ExactOutSwapRoute fuzz test.
type collectRewardParams struct {
	positionID   uint64
	unwrapResult bool

	isStaked                bool
	skipBlocks              int64
	previousBalances        map[string]int64
	startIncentiveTimestamp int64
}

func (p *collectRewardParams) ToString() string {
	return ufmt.Sprintf("positionID: %d, isStaked: %v, skipBlocks: %d, startIncentiveTimestamp: %d", p.positionID, p.isStaked, p.skipBlocks, p.startIncentiveTimestamp)
}

func (p *collectRewardParams) IsValid() bool {
	return p.isValidStake()
}

func (p *collectRewardParams) isValidStake() bool {
	return p.isStaked
}

func (p *collectRewardParams) isStartedDistribution() bool {
	currentTimestamp := time.Now().Unix()
	return currentTimestamp > p.startIncentiveTimestamp && p.skipBlocks > 0
}

func (p *collectRewardParams) hasBalanceChanges() bool {
	if len(p.previousBalances) == 0 {
		return false
	}

	for tokenPath, previousBalance := range p.previousBalances {
		currentBalance := common.BalanceOf(tokenPath, adminAddr)
		if currentBalance > previousBalance {
			return true
		}
	}

	return false
}

func (p *collectRewardParams) updatePreviousBalances(tokenPaths ...string) {
	for _, tokenPath := range tokenPaths {
		p.previousBalances[tokenPath] = common.BalanceOf(tokenPath, adminAddr)
	}
}

func NewValidCollectRewardParams(t *fuzz.T, positionID uint64, isStaked bool, startIncentiveTimestamp int64) *collectRewardParams {
	skipBlocks := fuzz.Int64Range(1, 180*24*60*60/5).Draw(t, "skipBlocks").(int64)
	return &collectRewardParams{
		positionID:              positionID,
		unwrapResult:            false,
		isStaked:                isStaked,
		skipBlocks:              skipBlocks,
		previousBalances:        make(map[string]int64),
		startIncentiveTimestamp: startIncentiveTimestamp,
	}
}
