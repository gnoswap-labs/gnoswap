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

	// Repeat for the number of internal emission target pools
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

	for tokenId, deposit := range deposits {
		poolPath := deposit.targetPoolPath
		poolCurrentBlockAmount := poolCurrentBlockGns[poolPath]

		if poolCurrentBlockAmount > 0 {
			// calculate position gns rewards
			liqRatioX96, exist := positionsLiquidityRatio[tokenId]

			if exist == false || liqRatioX96.IsZero() {
				continue
			}

			positionAmountX96 := u256.Zero().Mul(u256.NewUint(poolCurrentBlockAmount), liqRatioX96)
			positionAmountX := u256.Zero().Div(positionAmountX96, _q96)
			positionAmount := positionAmountX.Uint64()

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

	// Repeat for the number of internal emission target pools (clean up)
	for poolPath, _ := range poolTiers {
		amount := poolLastTmpGns[poolPath]
		if amount > 0 {
			if poolCurrentBlockGns[poolPath] >= amount {
				poolLastTmpGns[poolPath] = poolCurrentBlockGns[poolPath] - amount
			} else {
				poolCurrentBlockGns[poolPath] = 0
			}
		} else {
		}
	}

	// clear(poolCurrentBlockGns) // gno doesn't support `clear` keyword yet
	poolCurrentBlockGns = make(map[string]uint64)

	// ------------------------------------ EXTERNAL
	for incentiveId, incentive := range incentives {
		poolPath := incentive.targetPoolPath

		startTimestamp := incentive.startTimestamp
		endTimestamp := incentive.endTimestamp
		now := time.Now().Unix()
		// if inactive incentive, do not calculate
		if !(startTimestamp <= now && now <= endTimestamp) {
			continue
		}

		rewardToken := incentive.rewardToken
		rewardLeft := incentive.rewardLeft

		for _, tokenId := range poolsPositions[poolPath] {
			// how many blocks passed since
			// max time between (start of the incentive) and (staked at) and (last calculated)
			deposit := deposits[tokenId]
			_max := max(startTimestamp, deposit.stakeTimestamp)

			_max = max(_max, externalLastCalculatedTimestamp[incentiveId])

			blocksPassed := (now - _max) / consts.BLOCK_GENERATION_INTERVAL
			if blocksPassed == 0 {
				continue
			}

			liqRatioX96, exist := positionsLiquidityRatio[tokenId]
			if exist == false || liqRatioX96.IsZero() {
				continue
			}

			currentPoolRewardX96 := u256.Zero().Mul(incentive.rewardPerBlockX96, u256.NewUint(uint64(blocksPassed)))

			positionAmountX96X96 := u256.Zero().Mul(currentPoolRewardX96, liqRatioX96)

			positionAmountX96 := u256.Zero().Div(positionAmountX96X96, _q96)

			rewardLeftX96 := new(u256.Uint).Mul(rewardLeft, _q96)
			if positionAmountX96.Gt(rewardLeftX96) {
				positionAmountX96 = rewardLeftX96
			}

			_, exist = positionLastExternal[tokenId]
			if !exist {
				positionLastExternal[tokenId] = make(map[string]*u256.Uint)
			}

			_, exist = positionsExternalLastCalculatedHeight[tokenId]
			if !exist {
				positionsExternalLastCalculatedHeight[tokenId] = make(map[string]int64)
				positionsExternalLastCalculatedHeight[tokenId][incentiveId] = height - int64(blocksPassed)
			}

			_, exist = positionsExternalWarmUpAmount[tokenId]
			if !exist {
				positionsExternalWarmUpAmount[tokenId] = make(map[string]warmUpAmount)
			}

			_, exist = positionsExternalWarmUpAmount[tokenId][incentiveId]
			if !exist {
				positionsExternalWarmUpAmount[tokenId][incentiveId] = warmUpAmount{}
			}

			_, exist = positionExternal[tokenId]
			if !exist {
				positionExternal[tokenId] = make(map[string]externalRewards)
			}

			_, exist = positionExternal[tokenId][incentiveId]
			if !exist {
				positionExternal[tokenId][incentiveId] = externalRewards{
					incentiveId:    incentiveId,
					poolPath:       poolPath,
					tokenPath:      rewardToken,
					tokenAmountX96: positionAmountX96,
				}
				positionLastExternal[tokenId][incentiveId] = u256.Zero()
			} else {
				tempLastExternalAmount := positionExternal[tokenId][incentiveId].tokenAmountX96
				positionLastExternal[tokenId][incentiveId] = tempLastExternalAmount
				positionExternal[tokenId][incentiveId] = externalRewards{
					incentiveId:    incentiveId,
					poolPath:       poolPath,
					tokenPath:      rewardToken,
					tokenAmountX96: new(u256.Uint).Add(tempLastExternalAmount, positionAmountX96),
				}
			}

			rewardMathComputeExternalRewardAmount(tokenId, incentiveId)
			positionsExternalLastCalculatedHeight[tokenId][incentiveId] = height
		}
		externalLastCalculatedTimestamp[incentiveId] = now
	}
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
