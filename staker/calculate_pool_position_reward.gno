package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"

	pn "gno.land/r/gnoswap/v2/position"

	u256 "gno.land/p/gnoswap/uint256"
)

// poolPath -> gnsAmount [accu]
var poolGns map[string]uint64 = make(map[string]uint64)

// poolPath -> gnsAmount [current block]
var poolCurrentBlockGns map[string]uint64 = make(map[string]uint64)

// poolPath -> gnsAmount [how much left from last block]
var poolLastTmpGns map[string]uint64 = make(map[string]uint64)

// poolPath -> accumulatedGns ( API VAR )
var poolAccuGns map[string]uint64 = make(map[string]uint64)

// tokenId -> gnsAmount
var positionGns map[uint64]uint64 = make(map[uint64]uint64)

// tokenId -> lastGnsAmount
var positionLastGns map[uint64]uint64 = make(map[uint64]uint64)

// tokenId -> incentiveId -> lastRewardAmount
var positionLastExternal map[uint64]map[string]*u256.Uint = make(map[uint64]map[string]*u256.Uint)

// incentiveId -> lastCalculatedTimestamp
var externalLastCalculatedTimestamp map[string]int64 = make(map[string]int64)

// incentiveId -> gnsAmount
var externalGns map[string]uint64 = make(map[string]uint64)

// poolPath -> totalStakedLiquidity(inRange)
var poolTotalStakedLiquidity map[string]*u256.Uint = make(map[string]*u256.Uint)

// tokenId -> positionRatio
var positionsLiquidityRatio map[uint64]*u256.Uint = make(map[uint64]*u256.Uint)

// poolPath -> []tokenId
var poolsPositions map[string][]uint64 = make(map[string][]uint64)

// Q96
var _q96 = u256.MustFromDecimal(consts.Q96)

type externalRewards struct {
	incentiveId    string
	poolPath       string
	tokenPath      string
	tokenAmountX96 *u256.Uint
	//
	tokenAmountFull   uint64
	tokenAmountToGive uint64
}

// tokenId -> incentiveId -> externalRewards
var positionExternal map[uint64]map[string]externalRewards = make(map[uint64]map[string]externalRewards)

var (
	lastCalculatedHeight  int64
	lastCalculatedBalance uint64
)

// XXX: need to improve nested iteration
// CalcPoolPosition calculates and updates the position of pools and rewards for stakers.
//
// It performs the following operations:
//
//  1. Calculates newly minted GNS tokens and distributes them among pool tiers.
//  2. Updates pool GNS balances and accumulated GNS for each pool.
//  3. Calculates and updates internal rewards for each staker's position.
//  4. Calculates and updates external rewards from incentives for each staker's postion.
//
// This function is meant to be called periodically to keep the pool postions
// and reward calculations up-to-date.
//
// It uses the current block height and its timestamp to determine the calculation period.
func CalcPoolPosition() {
	height := std.GetHeight()

	if height <= lastCalculatedHeight {

		return
	}

	prevAddr, prevRealm := getPrev()

	// calculate each pool's total staked liquidity
	poolTotalStakedLiquidity = make(map[string]*u256.Uint) // clear
	for tokenId, deposit := range deposits {
		poolPath := deposit.targetPoolPath
		if _, exist := poolTotalStakedLiquidity[poolPath]; !exist {
			poolTotalStakedLiquidity[poolPath] = u256.Zero()
		}

		isInRange := pn.PositionIsInRange(tokenId)
		if isInRange == false {
			continue
		}

		positionLiquidity := pn.PositionGetPositionLiquidity(tokenId)
		poolTotalStakedLiquidity[poolPath] = poolTotalStakedLiquidity[poolPath].Add(poolTotalStakedLiquidity[poolPath], positionLiquidity)
	}

	// calculate each position's liquidity ratio
	// + also which pool has which positions
	positionsLiquidityRatio = make(map[uint64]*u256.Uint) // clear
	poolsPositions = make(map[string][]uint64)            // clear

	for tokenId, deposit := range deposits {
		poolPath := deposit.targetPoolPath
		isInRange := pn.PositionIsInRange(tokenId)
		if isInRange == false {
			positionsLiquidityRatio[tokenId] = u256.Zero()
		} else {
			poolTotalStakedLiquidity := poolTotalStakedLiquidity[poolPath]
			positionLiquidity := pn.PositionGetPositionLiquidity(tokenId)

			positionLiquidityX96x := new(u256.Uint).Mul(positionLiquidity, _q96)
			positionLiquidityX96x = positionLiquidityX96x.Mul(positionLiquidityX96x, u256.NewUint(1_000_000_000))

			poolTotalStakedLiquidityX96 := new(u256.Uint).Mul(poolTotalStakedLiquidity, _q96)

			positionLiquidityRatio := new(u256.Uint).Div(positionLiquidityX96x, poolTotalStakedLiquidityX96)         // this value needs to be divided by 1_000_000_000
			positionLiquidityRatio = positionLiquidityRatio.Mul(positionLiquidityRatio, _q96)                        // so first mul consts.Q96
			positionLiquidityRatio = positionLiquidityRatio.Div(positionLiquidityRatio, u256.NewUint(1_000_000_000)) // then divided by 1_000_000_000

			positionsLiquidityRatio[tokenId] = positionLiquidityRatio

			// poolsPositions
			poolsPositions[poolPath] = append(poolsPositions[poolPath], tokenId)
		}
	}

	// calculate external gns amounts
	totalExternalGns := externalGnsAmount()

	totalExternalGns += externalDepositGnsAmount()

	// calculate pool
	stakerGnsBalance := gnsBalance(consts.STAKER_ADDR)

	stakerGnsBalance -= totalExternalGns

	mintedGnsAmount := stakerGnsBalance - lastCalculatedBalance

	lastCalculatedBalance = stakerGnsBalance

	duration := height - lastCalculatedHeight

	tier1Amount, tier2Amount, tier3Amount := getTiersAmount(mintedGnsAmount)
	tier1Num, tier2Num, tier3Num := getNumPoolTiers()

	var eachTier1Amount, eachTier2Amount, eachTier3Amount uint64
	if tier1Num > 0 {
		eachTier1Amount = tier1Amount / tier1Num
	}

	if tier2Num > 0 {
		eachTier2Amount = tier2Amount / tier2Num
	}

	if tier3Num > 0 {
		eachTier3Amount = tier3Amount / tier3Num
	}

	// 인터널 에미션 대상 풀 수만큼 반복
	for poolPath, internal := range poolTiers {

		tier := internal.tier

		tierAmount := uint64(0)
		if tier == 1 {
			tierAmount = eachTier1Amount
		} else if tier == 2 {
			tierAmount = eachTier2Amount
		} else if tier == 3 {
			tierAmount = eachTier3Amount
		}

		poolGns[poolPath] += tierAmount
		poolAccuGns[poolPath] += tierAmount

		// current block minted gns + left from last block distributed gns
		poolCurrentBlockGns[poolPath] = tierAmount

		poolCurrentBlockGns[poolPath] += poolLastTmpGns[poolPath]

		poolLastTmpGns[poolPath] = 0

		totalStakedLiquidity, exist := poolTotalStakedLiquidity[poolPath]

		if exist == false || totalStakedLiquidity.IsZero() {

			send := min(poolGns[poolPath], stakerGnsBalance-totalExternalGns)

			gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), send)
			std.Emit(
				"CommunityPoolEmptyEmission",
				"prevAddr", prevAddr,
				"prevRealm", prevRealm,
				"internal_poolPath", poolPath,
				"internal_amount", ufmt.Sprintf("%d", send),
			)

			poolGns[poolPath] = 0
			poolCurrentBlockGns[poolPath] = 0

			// gns send happens, so update last calculated balance
			_stakerGnsBalance := gnsBalance(consts.STAKER_ADDR)
			lastCalculatedBalance = _stakerGnsBalance - totalExternalGns

		}
	}

	// 전체 포지션 반복
	for tokenId, deposit := range deposits { // 찐 대상만
		poolPath := deposit.targetPoolPath
		poolCurrentBlockAmount := poolCurrentBlockGns[poolPath]

		// ------------------------------------ INTERNAL
		if poolCurrentBlockAmount > 0 {
			// calculate position gns rewards
			liqRatioX96, exist := positionsLiquidityRatio[tokenId]

			if exist == false || liqRatioX96.IsZero() {

				continue
			}

			positionAmountX96 := u256.Zero().Mul(u256.NewUint(poolCurrentBlockAmount), liqRatioX96)
			positionAmountX := u256.Zero().Div(positionAmountX96, _q96)
			positionAmount := positionAmountX.Uint64()

			// XXX: REMOVE AFTER QA

			positionLastGns[tokenId] = positionGns[tokenId]
			positionGns[tokenId] += positionAmount
			poolLastTmpGns[poolPath] += positionAmount

			// calculate internal amount from previous to now
			rewardMathComputeInternalRewardAmount(tokenId)
		}

	}

	// update flag

	lastCalculatedHeight = height

	lastCalculatedBalance = gnsBalance(consts.STAKER_ADDR) - totalExternalGns // latest balance

	// 인터널 에미션 대상 풀 수만큼 반복
	for poolPath, _ := range poolTiers {
		amount := poolLastTmpGns[poolPath]

		if amount > 0 {
			if poolCurrentBlockGns[poolPath] >= amount {
				poolLastTmpGns[poolPath] = poolCurrentBlockGns[poolPath] - amount
			} else {
				poolCurrentBlockGns[poolPath] = 0
			}
		}
	}

	// clear(poolCurrentBlockGns) // gno doesn't support `clear` keyword yet
	poolCurrentBlockGns = make(map[string]uint64)

	// ------------------------------------ EXTERNAL
	external := NewExternalCalculator(height)
	external.calculate(incentives) // XXX: no returning any value?
}

func externalGnsAmount() uint64 {
	amount := uint64(0)
	for _, v := range externalGns {
		amount += v
	}
	return amount
}

func externalDepositGnsAmount() uint64 {
	amount := uint64(0)

	for _, incentive := range incentives {
		amount += incentive.depositGnsAmount
	}

	return amount
}

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
		}
	}
	externalLastCalculatedTimestamp[ictvId] = ec.now
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
	positionAmount = u256.Zero().Div(positionAmount, _q96) // X96

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
func (ex *ExternalCalculator) initPositionMaps(tokId uint64, ictvId string, ictv ExternalIncentive) {
	if _, exist := positionLastExternal[tokId]; !exist {
		positionLastExternal[tokId] = make(map[string]*u256.Uint)
	}

	blockPassed := ex.getBlockPassed(tokId, ictvId, ictv)

	if _, exist := positionsExternalLastCalculatedHeight[tokId]; !exist {
		positionsExternalLastCalculatedHeight[tokId] = make(map[string]int64)
		positionsExternalLastCalculatedHeight[tokId][ictvId] = ex.height - int64(blockPassed)
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
