package staker

import (
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/consts"
)

// region *****refactor******

type ExternalIncentiveMap map[string]ExternalIncentive

// ExternalCalculator manages the calculation of external incentive rewards.
//
// This maintains its own timestamp to ensure consistent time-based calculations
// accross multiple operation calls.
//
// TODO: better name
type ExternalCalculator struct {
	height int64
	now    int64
}

func NewExternalCalculator(height int64) *ExternalCalculator {
	now := time.Now().Unix()
	return &ExternalCalculator{height, now}
}

// calculate processes all active incentives and their rewards.
//
// it iterates throught incentives, checks their activity status,
// and processes rewards only for active ones to optimize computation.
//
// To maintain the functional purity, it passes the [ExternalIncentiveMap] as an argument.
func (ec *ExternalCalculator) calculate(ictvs ExternalIncentiveMap) {
	for id, ictv := range ictvs {
		if !ec.active(ictv) {
			continue
		}

		ec.process(id, ictv)
		externalLastCalculatedTimestamp[id] = ec.now
	}
}

// active determines if an incentive is currently valid based on its time window.
func (ec *ExternalCalculator) active(ictv ExternalIncentive) bool {
	return ictv.startTimestamp <= ec.now && ec.now <= ictv.endTimestamp
}

// process handles reward calculation for a single incentive across all its positions.
//
// SIDE EFFECT: updates the global state once all position calculations are done,
// maintaining consistency in reward distribution timing.
func (ec *ExternalCalculator) process(ictvId string, ictv ExternalIncentive) {
	for _, tokId := range poolsPositions[ictv.targetPoolPath] {
		if ec.must(tokId, ictvId, ictv) {
			blockPassed := ec.getBlockPassed(tokId, ictvId, ictv)
			ec.updatePosition(tokId, ictvId, ictv, blockPassed)
			ec.initPositionMaps(tokId, ictvId, ictv, blockPassed)

			rewardMathComputeExternalRewardAmount2(tokId, ictvId)
			positionsExternalLastCalculatedHeight[tokId][ictvId] = ec.height
		}
	}
}

// must determines if a position should receive rewards at this calculation cycle.
//
// it checks both the time elapsed and liquidity conditions to ensure
// rewards are only calculated for valid, active positions.
func (ec *ExternalCalculator) must(tokId uint64, ictvId string, ictv ExternalIncentive) bool {
	passed := ec.getBlockPassed(tokId, ictvId, ictv)
	if passed == 0 {
		return false
	}

	liqRatioX96, exist := positionsLiquidityRatio[tokId]
	return exist && !liqRatioX96.IsZero()
}

// getBlockPassed calculates the number of blocks that have passed since the last
// reward calculation.
//
// TOO MANY SIDE-EFFECTS: use block height instead of timestamp
func (ec *ExternalCalculator) getBlockPassed(tokId uint64, ictvId string, ictv ExternalIncentive) int64 {
	deposit := deposits[tokId]
	last := max(ictv.startTimestamp, deposit.stakeTimestamp)
	last = max(last, externalLastCalculatedTimestamp[ictvId])

	// WARNING: error prone. need to use block height instead of timestamp
	return (ec.now - last) / consts.BLOCK_GENERATION_INTERVAL
}

// updatePosition calculates the reward amount for a single position.
//
// It applies the liquidity ratio to the total pool reward and ensures
// the result is in Q96 format.
func (ec *ExternalCalculator) updatePosition(
	tokId uint64,
	ictvId string,
	ictv ExternalIncentive,
	blockPassed int64,
) *u256.Uint {
	// TODO: reuse this value that extracted from `must`?
	liqRatioX96 := positionsLiquidityRatio[tokId]

	currentPoolRewardX96 := u256.Zero().Mul(
		ictv.rewardPerBlockX96,
		u256.NewUint(uint64(blockPassed)),
	)

	positionAmount := u256.Zero().Mul(currentPoolRewardX96, liqRatioX96) // X96X96
	positionAmount = u256.Zero().Div(positionAmount, _q96)               // X96

	rewardLeft := new(u256.Uint).Mul(ictv.rewardLeft, _q96)
	if positionAmount.Gt(rewardLeft) {
		return rewardLeft
	}

	return positionAmount
}

// initPositionMaps ensures all necessary data structures are initialized
// for a position's reward tracking.
//
// WARNING: this initialization is required before any reward calculations can proceed,
// preventing null pointer exceptions and maintaining consistent reward tracking.
//
// IDEMPOTENT: calling it multiple times with the same parameters will result in the same state.
func (ex *ExternalCalculator) initPositionMaps(tokId uint64, ictvId string, ictv ExternalIncentive, blocksPassed int64) {
	liqRatioX96, exist := positionsLiquidityRatio[tokId]
	if exist == false || liqRatioX96.IsZero() {
		return
	}

	currentPoolRewardX96 := u256.Zero().Mul(ictv.rewardPerBlockX96, u256.NewUint(uint64(blocksPassed)))
	positionAmountX96X96 := u256.Zero().Mul(currentPoolRewardX96, liqRatioX96)
	positionAmountX96 := u256.Zero().Div(positionAmountX96X96, _q96)

	if _, exist := positionLastExternal[tokId]; !exist {
		positionLastExternal[tokId] = make(map[string]*u256.Uint)
	}

	if _, exist := positionsExternalLastCalculatedHeight[tokId]; !exist {
		positionsExternalLastCalculatedHeight[tokId] = make(map[string]int64)
		positionsExternalLastCalculatedHeight[tokId][ictvId] = ex.height - int64(blocksPassed)
	}

	if _, exist := positionsExternalWarmUpAmount[tokId]; !exist {
		positionsExternalWarmUpAmount[tokId] = make(map[string]warmUpAmount)
	}

	if _, exist := positionsExternalWarmUpAmount[tokId][ictvId]; !exist {
		positionsExternalWarmUpAmount[tokId][ictvId] = warmUpAmount{}
	}

	if _, exist := positionExternal[tokId]; !exist {
		positionExternal[tokId] = make(map[string]externalRewards)
	}

	_, exist = positionExternal[tokId][ictvId]
	if !exist {
		positionExternal[tokId][ictvId] = createNewPositionReward(ictvId, ictv.targetPoolPath, ictv.rewardToken, positionAmountX96)
		positionLastExternal[tokId][ictvId] = u256.Zero()
	} else {
		tempLastExternalAmount := positionExternal[tokId][ictvId].tokenAmountX96
		positionLastExternal[tokId][ictvId] = tempLastExternalAmount
		positionExternal[tokId][ictvId] = externalRewards{
			incentiveId:    ictvId,
			poolPath:       ictv.targetPoolPath,
			tokenPath:      ictv.rewardToken,
			tokenAmountX96: new(u256.Uint).Add(tempLastExternalAmount, positionAmountX96),
		}
	}
}

// createNewPositionReward creates a new position reward record.
func createNewPositionReward(
	ictvId string,
	poolPath string,
	tokenPath string,
	positionAmountX96 *u256.Uint,
) externalRewards {
	return externalRewards{
		incentiveId:    ictvId,
		poolPath:       poolPath,
		tokenPath:      tokenPath,
		tokenAmountX96: positionAmountX96,
	}
}

// updateExistingPositionReward creates a new reward record with updated amounts.
func updateExistingPositionReward(
	existing externalRewards,
	positionAmountX96 *u256.Uint,
) externalRewards {
	return externalRewards{
		incentiveId:    existing.incentiveId,
		poolPath:       existing.poolPath,
		tokenPath:      existing.tokenPath,
		tokenAmountX96: new(u256.Uint).Add(existing.tokenAmountX96, positionAmountX96),
	}
}

// updatePositionRewards coordinates the creation or update of position rewards.
func (ex *ExternalCalculator) updatePositionRewards(
	tokId uint64,
	ictvId string,
	ictv ExternalIncentive,
	positionAmountX96 *u256.Uint,
) {
	amount, exist := positionExternal[tokId][ictvId]
	if exist {
		positionLastExternal[tokId][ictvId] = amount.tokenAmountX96
		positionExternal[tokId][ictvId] = updateExistingPositionReward(
			amount,
			positionAmountX96,
		)
		return
	}

	newReward := createNewPositionReward(
		ictvId,
		ictv.targetPoolPath,
		ictv.rewardToken,
		positionAmountX96,
	)
	positionExternal[tokId][ictvId] = newReward
	positionLastExternal[tokId][ictvId] = positionAmountX96
}

// 남는 수량 어떻게?
