package staker

import (
	"std"
	"time"

	"gno.land/r/gnoswap/consts"

	"gno.land/r/gnoswap/gns"

	en "gno.land/r/gnoswap/emission"

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

// tokenId -> height
var positionCollectHeight map[uint64]uint64 = make(map[uint64]uint64)

type externalRewards struct {
	incentiveId        string
	poolPath           string
	tokenPath          string
	tokenAmount        uint64
	tokenAmountClaimed uint64
}

// tokenId -> []externalRewards
var positionExternal map[uint64][]externalRewards = make(map[uint64][]externalRewards)

var (
	lastCalculatedHeight    int64
	lastCalculatedTimestamp int64
	lastCalculatedBalance   uint64
)

func CalcPoolPosition() {
	println()
	println("=== [ START START START ] CALC__CalcPoolPosition")
	_q96 := u256.MustFromDecimal(consts.Q96)

	height := std.GetHeight()

	println("CALC__CalcPoolPosition__height", height)
	println("CALC__CalcPoolPosition__lastCalculatedHeight", lastCalculatedHeight)
	if height <= lastCalculatedHeight {
		println(" > [XXX] CALC__CalcPoolPosition__SKIP", height, lastCalculatedHeight)
		println()
		return
	}

	// calculate pool
	stakerGnsBalance := gnsBalance(consts.STAKER_ADDR)
	println("CALC__stakerGnsBalance:", stakerGnsBalance)

	mintedGnsAmount := en.GetLastDistributeToStaker()
	println("CALC__mintedGnsAmount:", mintedGnsAmount)

	/*
		if std.GetOrigCaller().String() == "" {
			println(" > CALC__ABCI_QUERY")
			if stakerGnsBalance > lastCalculatedBalance {
				println("  >> CALC__ABCI_QUERY__stakerGnsBalance > lastCalculatedBalance")
				println("  >> CALC__ABCI_QUERY__stakerGnsBalance:", stakerGnsBalance)
				println("  >> CALC__ABCI_QUERY__lastCalculatedBalance:", lastCalculatedBalance)
				mintedGnsAmount = stakerGnsBalance - lastCalculatedBalance
				println("  >> CALC__ABCI_QUERY__mintedGnsAmount:", mintedGnsAmount)
			} else {
				println("  >> CALC__ABCI_QUERY__stakerGnsBalance <= lastCalculatedBalance")
				println("  >> CALC__ABCI_QUERY__stakerGnsBalance:", stakerGnsBalance)
				println("  >> CALC__ABCI_QUERY__lastCalculatedBalance:", lastCalculatedBalance)
				// mintedGnsAmount = 0
			}
		} else {
			println(" > CALC__ACTUAL_TX_CALL")
		}
	*/

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

	println("[ START ] CALC__poolTiers DISTRIBUTE END")
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

			send := min(poolGns[poolPath], gnsBalance(consts.STAKER_ADDR))
			println("  > CALC__ZERO_SEND_min(poolGns[poolPath], gnsBalance(consts.STAKER_ADDR)", send)
			println("  > CALC__BEFORE_STAKER_GNS:", gnsBalance(consts.STAKER_ADDR))
			println("  > CALC__BEFORE_FEE_GNS:", gnsBalance(consts.PROTOCOL_FEE_ADDR))

			gns.Transfer(a2u(consts.PROTOCOL_FEE_ADDR), send)
			poolGns[poolPath] = 0
			poolCurrentBlockGns[poolPath] = 0

			println("  > CALC__AFTER_STAKER_GNS:", gnsBalance(consts.STAKER_ADDR))
			println("  > CALC__AFTER_FEE_GNS:", gnsBalance(consts.PROTOCOL_FEE_ADDR))
			println("  > CALC__AFTET_poolGns[poolPath] = 0")
			println("  > CALC__AFTET_poolCurrentBlockGns[poolPath] = 0")
			println("  > ----------------------- WAS EMPTY POOL")
		}
	}
	println("[ END ] CALC__poolTiers DISTRIBUTE END")

	println()

	println("[ START ] CALC__deposits ITERATION")
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
			positionGns[tokenId] += positionAmount
			poolLastTmpGns[poolPath] += positionAmount
			println(" > CALC__AFTER")
			println(" > CALC__positionAmount:", positionAmount)
			println(" > CALC__positionGns[tokenId]:", positionGns[tokenId])
			println(" > CALC__poolLastTmpGns[poolPath]:", poolLastTmpGns[poolPath])
			println()
		}

		// ------------------------------------ EXTERNAL
		// calculate position external rewards
		incentiveIds := poolIncentives[poolPath]
		println()
		println(" > [START] CALC__EXTERNAL START")
		for _, incentiveId := range incentiveIds {
			println("  > CALC__EXTERNAL_incentiveId:", incentiveId)
			incentive := incentives[incentiveId]

			startTimestamp := incentive.startTimestamp
			endTimestamp := incentive.endTimestamp
			now := time.Now().Unix()
			// if inactive incentive, do not calculate
			if !(startTimestamp <= now && now <= endTimestamp) {
				println("  > CALC__EXTERNAL_INACTIVE")
				println()
				continue
			}

			rewardToken := incentive.rewardToken
			rewardAmount := incentive.rewardAmount
			rewardLeft := incentive.rewardLeft
			println("  > CALC__EXTERNAL_rewardToken:\t", rewardToken)
			println("  > CALC__EXTERNAL_rewardAmount:\t", rewardAmount.ToString())
			println("  > CALC__EXTERNAL_rewardLeft:\t", rewardLeft.ToString())

			// how many blocks passed since the start of the incentive
			blocksPassed := (now - startTimestamp) / consts.BLOCK_GENERATION_INTERVAL
			println("  > CALC__EXTERNAL_blocksPassed:", blocksPassed)
			liqRatioX96 := getMyLiquidityRatio(poolPath, tokenId)
			println("  > CALC__EXTERNAL_liqRatioX96:", liqRatioX96.ToString())

			currentPoolReward := u256.NewUint(incentive.rewardPerBlock * uint64(blocksPassed))
			println("  > CALC__EXTERNAL_currentPoolReward:", currentPoolReward.ToString())
			positionAmountX := u256.Zero().Mul(currentPoolReward, liqRatioX96)
			positionAmountX = u256.Zero().Div(positionAmountX, _q96)
			positionAmount := positionAmountX.Uint64()
			println("  > CALC__EXTERNAL_positionAmount:", positionAmount)

			if positionAmount > rewardLeft.Uint64() {
				positionAmount = rewardLeft.Uint64()
			}

			if len(positionExternal[tokenId]) == 0 {
				println("  > CALC__EXTERNAL__len(positionExternal[tokenId]) == 0")
				positionExternal[tokenId] = append(positionExternal[tokenId], externalRewards{
					incentiveId:        incentiveId,
					poolPath:           poolPath,
					tokenPath:          rewardToken,
					tokenAmount:        positionAmount,
					tokenAmountClaimed: 0,
				})
				println("  > CALC__EXTERNAL__positionExternal[tokenId]:", positionExternal[tokenId])
			} else {
				println("  > CALC__EXTERNAL__len(positionExternal[tokenId]) > 0")
				for i, external := range positionExternal[tokenId] {
					println("   > CALC__external.incentiveId:", external.incentiveId)
					if external.incentiveId == incentiveId {
						println("    > CALC__EXTERNAL__FOUND")
						println("    > CALC__EXTERNAL__BEFORE", external.tokenAmount)
						external.tokenAmount = (positionAmount - external.tokenAmountClaimed)
						println("    > CALC__EXTERNAL__AFTER", external.tokenAmount)
						positionExternal[tokenId][i] = external
						break
					}
				}
			}
		}
	}
	println("[ END ] CALC__EXTERNAL END")
	println()

	// update flag
	println("UPDATE FLAG")
	lastCalculatedHeight = height
	lastCalculatedTimestamp = time.Now().Unix()
	lastCalculatedBalance = stakerGnsBalance
	println()

	println("[START] CALC__FINAL")
	for poolPath, _ := range poolTiers {
		amount := poolLastTmpGns[poolPath]
		println(" > CALC__FINAL_POOL", poolPath)
		println(" > CALC__FINAL_amount", amount)
		println(" > CALC__FINAL_poolCurrentBlockGns[poolPath]", poolCurrentBlockGns[poolPath])
		println(" > CALC__FINAL_poolLastTmpGns[poolPath]", poolLastTmpGns[poolPath])
		println(" > CALC__FINAL_POOL", poolPath)
		println(" > CALC__FINAL_amount", amount)
		println(" > CALC__FINAL_poolCurrentBlockGns[poolPath]", poolCurrentBlockGns[poolPath])
		println(" > CALC__FINAL_poolLastTmpGns[poolPath]", poolLastTmpGns[poolPath])
		if amount > 0 {
			if poolCurrentBlockGns[poolPath] >= amount {
				println(" > CALC__SAME_OR_LEFT")
				println(" > CALC__SAME_OR_LEFT")
				poolLastTmpGns[poolPath] = poolCurrentBlockGns[poolPath] - amount
				println(" > poolLastTmpGns[poolPath]", poolLastTmpGns[poolPath])
				println(" > poolLastTmpGns[poolPath]", poolLastTmpGns[poolPath])
			} else {
				println(" > CALC__FINAL_WRONG")
				println(" > CALC__FINAL_WRONG")
				poolCurrentBlockGns[poolPath] = 0
			}
		} else {
			println(" > CALC__FINAL__amount = 0")
			println(" > CALC__FINAL__amount = 0")
		}
	}
	println("[END] CALC__FINAL")
	println()

	// clear(poolCurrentBlockGns) // gno doesn't support `clear` keyword yet
	poolCurrentBlockGns = make(map[string]uint64)
	println("=== [ END END END ] CALC__CalcPoolPosition")
	println()
}
