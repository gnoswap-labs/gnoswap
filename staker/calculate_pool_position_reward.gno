package staker

import (
	"std"
	"strconv"
	"time"

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
	tokenAmountFull       uint64
	tokenAmountActualFull uint64
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
	println()
	println("=== [ START START START ] CALC__CalcPoolPosition")

	height := std.GetHeight()
	println("CALC__CalcPoolPosition__height", height)
	println("CALC__CalcPoolPosition__lastCalculatedHeight", lastCalculatedHeight)
	if height <= lastCalculatedHeight {
		println(" > [XXX] CALC__CalcPoolPosition__SKIP", height, lastCalculatedHeight)
		println()
		return
	}

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

	// calculate pool
	stakerGnsBalance := gnsBalance(consts.STAKER_ADDR)

	println(" > CALC__stakerGnsBalance:", stakerGnsBalance)
	println(" > CALC__externalGnsAmount:", totalExternalGns)

	stakerGnsBalance -= totalExternalGns
	println("CALC__stakerGnsBalance - externalGnsAmount", stakerGnsBalance)
	println("CALC__lastCalculatedBalance:", lastCalculatedBalance)

	mintedGnsAmount := stakerGnsBalance - lastCalculatedBalance
	println("CALC__mintedGnsAmount:", mintedGnsAmount)

	lastCalculatedBalance = stakerGnsBalance

	println("CALC__height:", height)
	println("CALC__lastCalculatedHeight:", lastCalculatedHeight)

	duration := height - lastCalculatedHeight
	println("CALC__duration:", duration)

	println("CALC__getTiersAmount_mintedGnsAmount:", mintedGnsAmount)
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

	println("CALC__tier1Amount:", tier1Amount)
	println("CALC__tier1Num:", tier1Num)
	println("CALC__eachTier1Amount:", eachTier1Amount)

	println("CALC__tier2Amount:", tier2Amount)
	println("CALC__tier2Num:", tier2Num)
	println("CALC__eachTier2Amount:", eachTier2Amount)

	println("CALC__tier3Amount:", tier3Amount)
	println("CALC__tier3Num:", tier3Num)
	println("CALC__eachTier3Amount:", eachTier3Amount)

	println("CALC__duration:", duration)
	println("CALC__height:", height)
	println()

	println("[ START ] CALC__poolTiers DISTRIBUTE")

	// 인터널 에미션 대상 풀 수만큼 반복
	for poolPath, internal := range poolTiers {
		println(" > CALC__poolPath:", poolPath)
		tier := internal.tier

		println(" > CALC__tier:", tier)

		tierAmount := uint64(0)
		if tier == 1 {
			tierAmount = eachTier1Amount
		} else if tier == 2 {
			tierAmount = eachTier2Amount
		} else if tier == 3 {
			tierAmount = eachTier3Amount
		}
		println(" > CALC__tierAmount:", tierAmount)

		println(" > CALC__BEFORE_poolGns[poolPath]:", poolGns[poolPath])
		println(" > CALC__BEFORE_poolAccuGns[poolPath]:", poolAccuGns[poolPath])
		poolGns[poolPath] += tierAmount
		poolAccuGns[poolPath] += tierAmount
		println(" > CALC__AFTER_poolGns[poolPath]:", poolGns[poolPath])
		println(" > CALC__AFTER_poolAccuGns[poolPath]:", poolAccuGns[poolPath])

		// current block minted gns + left from last block distributed gns
		poolCurrentBlockGns[poolPath] = tierAmount
		println(" > CALC__poolCurrentBlockGns[poolPath]:", poolCurrentBlockGns[poolPath])

		println(" > CALC__ADD_poolLastTmpGns[poolPath]:", poolLastTmpGns[poolPath])

		poolCurrentBlockGns[poolPath] += poolLastTmpGns[poolPath]
		println(" > CALC__AFTER_ADD", poolCurrentBlockGns[poolPath])

		poolLastTmpGns[poolPath] = 0
		println(" > CALC__INIT_TO_ZERO_poolLastTmpGns[poolPath]:", poolLastTmpGns[poolPath])

		totalStakedLiquidity, exist := poolTotalStakedLiquidity[poolPath]
		println(" > CALC__poolPath:", poolPath)
		println(" > CALC__totalStakedLiquidity:", totalStakedLiquidity.ToString())

		if exist == false || totalStakedLiquidity.IsZero() {
			println("  > CALC__ZERO_POOL", poolPath, "HAS TIER OF", internal.tier, "BUT NONE STAKED, SEND AMOUNT TO PROTOCOL FEE")
			println("  > CALC__ZERO_poolGns[poolPath]:", poolGns[poolPath])

			send := min(poolGns[poolPath], stakerGnsBalance-totalExternalGns)
			println("  > CALC__ZERO_SEND_min(poolGns[poolPath], stakerGnsBalance-totalExternalGns", send)
			println("  > CALC__BEFORE_STAKER_GNS:", stakerGnsBalance-totalExternalGns)
			println("  > CALC__BEFORE_FEE_GNS:", gnsBalance(consts.PROTOCOL_FEE_ADDR))
			println("  > CALC__BEFORE_lastCalculatedBalance:", lastCalculatedBalance)

			gns.Transfer(a2u(consts.PROTOCOL_FEE_ADDR), send)
			std.Emit(
				"GNOSWAP_PROTOCOL_FEE",
				"m_callType", callType(),
				"m_origCaller", origCaller(),
				"m_prevRealm", prevRealm(),
				"poolPath", poolPath,
				"reason", "emission_target_pool_no_staked",
				"token", consts.GNS_PATH,
				"amount", strconv.FormatUint(send, 10),
			)

			poolGns[poolPath] = 0
			poolCurrentBlockGns[poolPath] = 0

			// gns send happens, so update last calculated balance
			_stakerGnsBalance := gnsBalance(consts.STAKER_ADDR)
			lastCalculatedBalance = _stakerGnsBalance - totalExternalGns

			println("  > CALC__AFTER_STAKER_GNS:", _stakerGnsBalance-totalExternalGns)
			println("  > CALC__AFTER_FEE_GNS:", gnsBalance(consts.PROTOCOL_FEE_ADDR))
			println("  > CALC__AFTER_poolGns[poolPath] = 0")
			println("  > CALC__AFTER_poolCurrentBlockGns[poolPath] = 0")
			println("  > CALC__AFTER_lastCalculatedBalance:", lastCalculatedBalance)
			println("  > ----------------------- WAS EMPTY POOL")
		}
	}
	println("[ END ] CALC__poolTiers DISTRIBUTE END")

	println()

	println("[ START ] CALC__deposits ITERATION")

	// 전체 포지션 반복
	for tokenId, deposit := range deposits {
		poolPath := deposit.targetPoolPath
		poolCurrentBlockAmount := poolCurrentBlockGns[poolPath]
		println(" > CALC__tokenId:", tokenId)
		println(" > CALC__poolCurrentBlockAmount:", poolCurrentBlockAmount)

		// ------------------------------------ INTERNAL
		if poolCurrentBlockAmount > 0 {
			// calculate position gns rewards
			liqRatioX96, exist := positionsLiquidityRatio[tokenId]

			if exist == false || liqRatioX96.IsZero() {
				println(" > CALC__liqRatioX96_IS_ZERO // SKIP", tokenId)
				println()
				continue
			}

			positionAmountX96 := u256.Zero().Mul(u256.NewUint(poolCurrentBlockAmount), liqRatioX96)
			positionAmountX := u256.Zero().Div(positionAmountX96, _q96)
			positionAmount := positionAmountX.Uint64()

			// XXX: REMOVE AFTER QA
			println(" > CALC__liqRatioX96:", liqRatioX96.ToString())
			println(" > CALC__positionAmountX:", positionAmountX.ToString())

			println(" > CALC__BEFORE")
			println(" > CALC__positionGns[tokenId]:", positionGns[tokenId])
			println(" > CALC__poolLastTmpGns[poolPath]:", poolLastTmpGns[poolPath])
			positionLastGns[tokenId] = positionGns[tokenId]
			positionGns[tokenId] += positionAmount
			poolLastTmpGns[poolPath] += positionAmount
			println(" > CALC__AFTER")
			println(" > CALC__positionAmount:", positionAmount)
			println(" > CALC__positionGns[tokenId]:", positionGns[tokenId])
			println(" > CALC__poolLastTmpGns[poolPath]:", poolLastTmpGns[poolPath])
			println()

			// calculate internal amount from previous to now
			rewardMathComputeInternalRewardAmount(tokenId)
		}

		println()
		println()
		println()
	}

	// update flag
	println("UPDATE FLAG")
	lastCalculatedHeight = height
	println(" > lastCalculatedHeight:", lastCalculatedHeight)
	lastCalculatedBalance = gnsBalance(consts.STAKER_ADDR) - totalExternalGns // latest balance
	println(" > lastCalculatedBalance:", lastCalculatedBalance)
	println()

	println("[ START ] CALC__FINAL")
	// 인터널 에미션 대상 풀 수만큼 반복
	for poolPath, _ := range poolTiers {
		amount := poolLastTmpGns[poolPath]
		println(" > CALC__FINAL_POOL", poolPath)
		println(" > CALC__FINAL_amount", amount)
		println(" > CALC__FINAL_poolCurrentBlockGns[poolPath]", poolCurrentBlockGns[poolPath])
		println(" > CALC__FINAL_poolLastTmpGns[poolPath]", poolLastTmpGns[poolPath])
		if amount > 0 {
			if poolCurrentBlockGns[poolPath] >= amount {
				println(" > CALC__SAME_OR_LEFT")
				poolLastTmpGns[poolPath] = poolCurrentBlockGns[poolPath] - amount
				println(" > poolLastTmpGns[poolPath]", poolLastTmpGns[poolPath])
			} else {
				println(" > CALC__FINAL_WRONG")
				poolCurrentBlockGns[poolPath] = 0
			}
		} else {
			println(" > CALC__FINAL__amount = 0")
		}
	}
	println("[ END ] CALC__FINAL")
	println()

	// clear(poolCurrentBlockGns) // gno doesn't support `clear` keyword yet
	poolCurrentBlockGns = make(map[string]uint64)
	println("=== [ END END END ] CALC__CalcPoolPosition")
	println()

	// ------------------------------------ EXTERNAL
	for incentiveId, incentive := range incentives {
		poolPath := incentive.targetPoolPath

		startTimestamp := incentive.startTimestamp
		endTimestamp := incentive.endTimestamp
		now := time.Now().Unix()
		// if inactive incentive, do not calculate
		if !(startTimestamp <= now && now <= endTimestamp) {
			println("  > CALC__EXTERNAL_INACTIVE")
			println("  > start:\t", startTimestamp)
			println("  > now:\t", now)
			println("  > end:\t", endTimestamp)
			println("  > s-n::\t", startTimestamp-now)
			println("  > s-n/b:\t", (startTimestamp-now)/2)
			println()
			continue
		}

		rewardToken := incentive.rewardToken
		rewardAmount := incentive.rewardAmount
		rewardLeft := incentive.rewardLeft
		println("  > CALC__EXTERNAL_rewardToken:\t\t", rewardToken)
		println("  > CALC__EXTERNAL_rewardAmount:\t", rewardAmount.ToString())
		println("  > CALC__EXTERNAL_rewardLeft:\t\t", rewardLeft.ToString())

		for _, tokenId := range poolsPositions[poolPath] {
			// how many blocks passed since
			// max time between (start of the incentive) and (staked at) and (last calculated)
			deposit := deposits[tokenId]
			_max := max(startTimestamp, deposit.stakeTimestamp)
			println("  > CALC__EXTERNAL_max:\t\t\t", _max)
			println("    > startTimestamp:\t\t\t", startTimestamp)
			println("    > deposit.stakeTimestamp:\t\t", deposit.stakeTimestamp)

			_max = max(_max, externalLastCalculatedTimestamp[incentiveId])
			println("  > CALC__EXTERNAL_max:\t\t\t", _max)
			println("    > externalLastCalculatedTimestamp[incentiveId]:", externalLastCalculatedTimestamp[incentiveId])

			blocksPassed := (now - _max) / consts.BLOCK_GENERATION_INTERVAL
			println("  > CALC__EXTERNAL_blocksPassed:\t", blocksPassed)
			println("   > incentive_start:\t\t\t", startTimestamp)
			println("   > stake_timestamp:\t\t\t", deposit.stakeTimestamp)
			println("   > last_calculated:\t\t\t", externalLastCalculatedTimestamp[incentiveId])
			println("   > now:\t\t\t\t", now)
			if blocksPassed == 0 {
				println("  > CALC__EXTERNAL_BLOCKS_PASSED_ZERO")
				continue
			}

			liqRatioX96, exist := positionsLiquidityRatio[tokenId]
			if exist == false || liqRatioX96.IsZero() {
				println("  > CALC__EXTERNAL_liqRatioX96_IS_ZERO // SKIP", tokenId)
				println()
				continue
			}
			println("  > CALC__EXTERNAL_liqRatioX96:\t\t", liqRatioX96.ToString())

			currentPoolRewardX96 := u256.Zero().Mul(incentive.rewardPerBlockX96, u256.NewUint(uint64(blocksPassed)))
			println("  > CALC__EXTERNAL_currentPoolReward:\t", currentPoolRewardX96.ToString())
			println("    > block_passed:\t\t\t", blocksPassed)
			println("    > rewardPerBlockX96:\t\t", incentive.rewardPerBlockX96.ToString())

			positionAmountX96X96 := u256.Zero().Mul(currentPoolRewardX96, liqRatioX96)
			println("  > CALC__EXTERNAL_positionAmountX96X96:", positionAmountX96X96.ToString())

			positionAmountX96 := u256.Zero().Div(positionAmountX96X96, _q96)
			println("  > CALC__EXTERNAL_positionAmountX96:\t", positionAmountX96.ToString())

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
