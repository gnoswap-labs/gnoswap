package staker

import (
	"std"
	"strconv"
	"time"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"

	u256 "gno.land/p/gnoswap/uint256"
)

// poolPath -> gnsAmount [accu]
var poolGns map[string]uint64 = make(map[string]uint64)

// poolPath -> gnsAmount [current block]
var poolCurrentBlockGns map[string]uint64 = make(map[string]uint64)

// poolPath -> gnsAmount [how much left from last block]
var poolLastTmpGns map[string]uint64 = make(map[string]uint64)

// poolPath -> accumulatedGns
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
	_q96 := u256.MustFromDecimal(consts.Q96)

	height := std.GetHeight()
	now := time.Now().Unix()

	println("CALC__CalcPoolPosition__height", height)
	println("CALC__CalcPoolPosition__lastCalculatedHeight", lastCalculatedHeight)
	if height <= lastCalculatedHeight {
		println(" > [XXX] CALC__CalcPoolPosition__SKIP", height, lastCalculatedHeight)
		println()
		return
	}

	// calculate pool
	stakerGnsBalance := gnsBalance(consts.STAKER_ADDR)
	println(" > CALC__stakerGnsBalance:", stakerGnsBalance)
	println(" > CALC__externalGnsAmount:", externalGnsAmount())

	stakerGnsBalance -= externalGnsAmount()
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
	println("CALC__tier1Num:", tier1Num)
	println("CALC__tier1Amount:", tier1Amount)

	println("CALC__tier2Num:", tier2Num)
	println("CALC__tier2Amount:", tier2Amount)

	println("CALC__tier3Num:", tier3Num)
	println("CALC__tier3Amount:", tier3Amount)

	println("CALC__duration:", duration)
	println("CALC__height:", height)
	println()

	println("[ START ] CALC__poolTiers DISTRIBUTE")
	for poolPath, internal := range poolTiers {
		println(" > CALC__poolPath:", poolPath)
		tier := internal.tier
		startHeight := internal.startHeight
		tierAmount := uint64(0)
		println(" > CALC__tier:", tier)
		println(" > CALC__startHeight:", startHeight)

		if tier == 1 {
			tierAmount = tier1Amount / tier1Num
		} else if tier == 2 {
			tierAmount = tier2Amount / tier2Num
		} else if tier == 3 {
			tierAmount = tier3Amount / tier3Num
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

		totalStakedLiquidity := getPoolTotalStakedLiquidity(poolPath)
		println(" > CALC__poolPath:", poolPath, "totalStakedLiquidity:", totalStakedLiquidity.ToString())

		if totalStakedLiquidity.ToString() == "0" {
			println("  > CALC__ZERO_POOL", poolPath, "HAS TIER OF", internal.tier, "BUT NONE STAKED, SEND AMOUNT TO PROTOCOL FEE")
			println("  > CALC__ZERO_poolGns[poolPath]:", poolGns[poolPath])

			send := min(poolGns[poolPath], gnsBalance(consts.STAKER_ADDR)-externalGnsAmount())
			println("  > CALC__ZERO_SEND_min(poolGns[poolPath], gnsBalance(consts.STAKER_ADDR)-externalGnsAmount()", send)
			println("  > CALC__BEFORE_STAKER_GNS:", gnsBalance(consts.STAKER_ADDR)-externalGnsAmount())
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
			lastCalculatedBalance = gnsBalance(consts.STAKER_ADDR) - externalGnsAmount()

			println("  > CALC__AFTER_STAKER_GNS:", gnsBalance(consts.STAKER_ADDR)-externalGnsAmount())
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

	externalToUpdate := []string{}
	for tokenId, deposit := range deposits {
		poolPath := deposit.targetPoolPath
		poolCurrentBlockAmount := poolCurrentBlockGns[poolPath]
		println(" > CALC__tokenId:", tokenId)
		println(" > CALC__poolCurrentBlockAmount:", poolCurrentBlockAmount)

		// ------------------------------------ INTERNAL
		if poolCurrentBlockAmount > 0 {
			// calculate position gns rewards
			liqRatioX96 := getMyLiquidityRatio(poolPath, tokenId)

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

		// ------------------------------------ EXTERNAL
		// calculate position external rewards
		incentiveIds := poolIncentives[poolPath]
		println("[ START ] CALC__EXTERNAL, TOKEN_ID", tokenId)
		for _, incentiveId := range incentiveIds {
			println("  > CALC__EXTERNAL_incentiveId:", incentiveId)
			incentive := incentives[incentiveId]

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

			// how many blocks passed since
			// max time between (start of the incentive) and (staked at) and (last calculated)
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

			liqRatioX96 := getMyLiquidityRatio(poolPath, tokenId)
			println("  > CALC__EXTERNAL_liqRatioX96:\t\t", liqRatioX96.ToString())

			currentPoolRewardX96 := u256.Zero().Mul(incentive.rewardPerBlockX96, u256.NewUint(uint64(blocksPassed)))
			println("  > CALC__EXTERNAL_currentPoolReward:\t", currentPoolRewardX96.ToString())
			println("    > block_passed:\t\t\t", blocksPassed)
			println("    > rewardPerBlockX96:\t\t", incentive.rewardPerBlockX96.ToString())

			positionAmountX96_x2 := u256.Zero().Mul(currentPoolRewardX96, liqRatioX96)
			println("  > CALC__EXTERNAL_positionAmountX96_x2:", positionAmountX96_x2.ToString())

			positionAmountX96 := u256.Zero().Div(positionAmountX96_x2, _q96)
			println("  > CALC__EXTERNAL_positionAmountX96:\t", positionAmountX96.ToString())

			rewardLeftX96 := new(u256.Uint).Mul(rewardLeft, _q96)
			if positionAmountX96.Gt(rewardLeftX96) {
				positionAmountX96 = rewardLeftX96
			}

			_, exist := positionLastExternal[tokenId]
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
			externalToUpdate = append(externalToUpdate, incentiveId)
		}
		println("[ END ] CALC__EXTERNAL, TOKEN_ID", tokenId)
	}
	// update all external incentives time
	uniquExternals := removeDupeStr(externalToUpdate)
	for _, incentiveId := range uniquExternals {
		externalLastCalculatedTimestamp[incentiveId] = now
	}

	// update flag
	println("UPDATE FLAG")
	lastCalculatedHeight = height
	println(" > lastCalculatedHeight:", lastCalculatedHeight)
	lastCalculatedBalance = gnsBalance(consts.STAKER_ADDR) - externalGnsAmount()
	println(" > lastCalculatedBalance:", lastCalculatedBalance)
	println()

	println("[ START ] CALC__FINAL")
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
}

func removeDupeStr(strSlice []string) []string {
	seen := make(map[string]struct{}, len(strSlice))
	result := make([]string, 0, len(strSlice))

	for _, str := range strSlice {
		if _, ok := seen[str]; !ok {
			seen[str] = struct{}{}
			result = append(result, str)
		}
	}

	return result
}

func externalGnsAmount() uint64 {
	amount := uint64(0)
	for _, v := range externalGns {
		amount += v
	}
	return amount
}
