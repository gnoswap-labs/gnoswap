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

var lastCalculatedBalance uint64

func CalcPoolPosition() {
	height := std.GetHeight()

	println("CalcPoolPosition__", height)
	if height <= lastCalculatedHeight {
		println("CalcPoolPosition__SKIP", height, lastCalculatedHeight)
		println()
		return
	}

	// calculate pool
	stakerGnsBalance := gnsBalance(consts.STAKER_ADDR)
	println("CALC__stakerGnsBalance:", stakerGnsBalance)

	mintedGnsAmount := en.GetLastDistributeToStaker()
	println("CALC__mintedGnsAmount:", mintedGnsAmount)
	if std.GetOrigCaller().String() == "" {
		println("CALC__ABCI_QUERY")
		if stakerGnsBalance > lastCalculatedBalance {
			println("CALC__ABCI_QUERY__stakerGnsBalance > lastCalculatedBalance")
			println("CALC__ABCI_QUERY__stakerGnsBalance:", stakerGnsBalance)
			println("CALC__ABCI_QUERY__lastCalculatedBalance:", lastCalculatedBalance)
			mintedGnsAmount = stakerGnsBalance - lastCalculatedBalance
			println("CALC__ABCI_QUERY__mintedGnsAmount:", mintedGnsAmount)
		} else {
			println("CALC__ABCI_QUERY__stakerGnsBalance <= lastCalculatedBalance")
			println("CALC__ABCI_QUERY__stakerGnsBalance:", stakerGnsBalance)
			println("CALC__ABCI_QUERY__lastCalculatedBalance:", lastCalculatedBalance)
			// mintedGnsAmount = 0
		}
	}
	println("CALC__USE_THIS_mintedGnsAmount:", mintedGnsAmount)

	lastGnsBalance = stakerGnsBalance

	tier1Amount, tier2Amount, tier3Amount := getTiersAmount(mintedGnsAmount)
	tier1Num, tier2Num, tier3Num := getNumPoolTiers()
	println("CALC__tier1Num:", tier1Num)
	println("CALC__tier2Num:", tier2Num)
	println("CALC__tier3Num:", tier3Num)

	for poolPath, internal := range poolTiers {
		println("CALC__poolTiers ITERA")
		println("CALC__poolPath:", poolPath)
		tier := internal.tier
		tierAmount := uint64(0)
		println("CALC__tier:", tier)
		if tier == 1 {
			tierAmount = tier1Amount / tier1Num
		} else if tier == 2 {
			tierAmount = tier2Amount / tier2Num
		} else if tier == 3 {
			tierAmount = tier3Amount / tier3Num
		}
		println("CALC__tierAmount:", tierAmount)

		println("CALC__BEFORE_poolGns[poolPath]:", poolGns[poolPath])
		println("CALC__BEFORE_poolAccuGns[poolPath]:", poolAccuGns[poolPath])
		poolGns[poolPath] += tierAmount
		poolAccuGns[poolPath] += tierAmount
		println("CALC__AFTER_poolGns[poolPath]:", poolGns[poolPath])
		println("CALC__AFTER_poolAccuGns[poolPath]:", poolAccuGns[poolPath])

		// current block minted gns + left from last block distributed gns
		poolCurrentBlockGns[poolPath] = tierAmount
		println("CALC__poolCurrentBlockGns[poolPath]:", poolCurrentBlockGns[poolPath])

		println("CALC__ADD_poolLastTmpGns[poolPath]:", poolLastTmpGns[poolPath])

		poolCurrentBlockGns[poolPath] += poolLastTmpGns[poolPath]
		println("CALC__AFTER_ADD", poolCurrentBlockGns[poolPath])

		poolLastTmpGns[poolPath] = 0
		println("CALC__INIT_TO_ZERO_poolLastTmpGns[poolPath]:", poolLastTmpGns[poolPath])
	}

	_q96 := u256.MustFromDecimal(consts.Q96)

	for poolPath, internal := range poolTiers {
		totalStakedLiquidity := getPoolTotalStakedLiquidity(poolPath)
		println("CALC__poolPath:", poolPath, "totalStakedLiquidity:", totalStakedLiquidity.ToString())
		if totalStakedLiquidity.ToString() == "0" {
			println("CALC__ZERO_POOL", poolPath, "HAS TIER OF", internal.tier, "BUT NONE STAKED, SEND AMOUNT TO PROTOCOL FEE")
			println("CALC__ZERO_poolGns[poolPath]:", poolGns[poolPath])

			send := min(poolGns[poolPath], gnsBalance(consts.STAKER_ADDR))
			println("CALC__ZERO_SEND_min(poolGns[poolPath], gnsBalance(consts.STAKER_ADDR)", send)
			println("CALC__BEFORE_STAKER_GNS:", gnsBalance(consts.STAKER_ADDR))
			println("CALC__BEFORE_FEE_GNS:", gnsBalance(consts.PROTOCOL_FEE_ADDR))

			gns.Transfer(a2u(consts.PROTOCOL_FEE_ADDR), send)
			poolGns[poolPath] = 0
			poolCurrentBlockGns[poolPath] = 0

			println("CALC__AFTER_STAKER_GNS:", gnsBalance(consts.STAKER_ADDR))
			println("CALC__AFTER_FEE_GNS:", gnsBalance(consts.PROTOCOL_FEE_ADDR))

			println()
			println()
			println("---------------------------------------------------------------- EMPTY POOL")
			println()
			println()
			println()
		}
	}

	for tokenId, deposit := range deposits {
		poolPath := deposit.targetPoolPath
		poolCurrentBlockAmount := poolCurrentBlockGns[poolPath]

		if poolCurrentBlockAmount == 0 {
			continue
		}

		println()
		println("CALC__tokenId:", tokenId)
		println("CALC__poolCurrentBlockAmount:", poolCurrentBlockAmount)

		// calculate position gns rewards
		liqRatioX96 := getMyLiquidityRatio(poolPath, tokenId)

		positionAmountX96 := u256.Zero().Mul(u256.NewUint(poolCurrentBlockAmount), liqRatioX96)
		positionAmountX := u256.Zero().Div(positionAmountX96, _q96)
		positionAmount := positionAmountX.Uint64()

		// XXX: REMOVE AFTER QA
		println("CALC__liqRatioX96:", liqRatioX96.ToString())
		println("CALC__positionAmountX:", positionAmountX.ToString())

		println("CALC__BEFORE")
		println("CALC__positionGns[tokenId]:", positionGns[tokenId])
		println("CALC__poolLastTmpGns[poolPath]:", poolLastTmpGns[poolPath])
		positionGns[tokenId] += positionAmount
		poolLastTmpGns[poolPath] += positionAmount
		println("CALC__AFTER")
		println("CALC__positionAmount:", positionAmount)
		println("CALC__positionGns[tokenId]:", positionGns[tokenId])
		println("CALC__poolLastTmpGns[poolPath]:", poolLastTmpGns[poolPath])

		// calculate position external rewards
		incentiveIds := poolIncentives[poolPath]
		for _, incentiveId := range incentiveIds {
			incentive := incentives[incentiveId]

			startTimestamp := incentive.startTimestamp
			endTimestamp := incentive.endTimestamp
			now := time.Now().Unix()

			// if inactive incentive, do not calculate
			if !(startTimestamp <= now && now <= endTimestamp) {
				continue
			}

			rewardToken := incentive.rewardToken
			rewardAmount := incentive.rewardAmount
			rewardLeft := incentive.rewardLeft

			incentiveDuration := endTimestamp - startTimestamp
			incentiveBlock := incentiveDuration / consts.BLOCK_GENERATION_INTERVAL
			rewardPerBlock256 := new(u256.Uint).Div(rewardAmount, u256.NewUint(uint64(incentiveBlock)))
			rewardPerBlock := rewardPerBlock256.Uint64()

			// how many blocks passed since the start of the incentive
			blocksPassed := (now - startTimestamp) / consts.BLOCK_GENERATION_INTERVAL
			liqRatioX96 := getMyLiquidityRatio(poolPath, tokenId)

			currentPoolReward := u256.NewUint(rewardPerBlock * uint64(blocksPassed))
			positionAmountX := u256.Zero().Mul(currentPoolReward, liqRatioX96)
			positionAmountX = u256.Zero().Div(positionAmountX, _q96)
			positionAmount := positionAmountX.Uint64()

			if positionAmount > rewardLeft.Uint64() {
				positionAmount = rewardLeft.Uint64()
			}

			if len(positionExternal[tokenId]) == 0 {
				positionExternal[tokenId] = append(positionExternal[tokenId], externalRewards{
					incentiveId:        incentiveId,
					poolPath:           poolPath,
					tokenPath:          rewardToken,
					tokenAmount:        positionAmount,
					tokenAmountClaimed: 0,
				})
			} else {
				for i, external := range positionExternal[tokenId] {
					if external.incentiveId == incentiveId {
						external.tokenAmount = (positionAmount - external.tokenAmountClaimed)
						positionExternal[tokenId][i] = external
						break
					}
				}
			}
		}
	}

	// update flag
	lastCalculatedHeight = height
	lastCalculatedBalance = stakerGnsBalance

	for poolPath, _ := range poolTiers {
		amount := poolLastTmpGns[poolPath]
		println("CALC__FINAL_POOL", poolPath)
		println("CALC__FINAL_amount", amount)
		println("CALC__FINAL_poolCurrentBlockGns[poolPath]", poolCurrentBlockGns[poolPath])
		println("CALC__FINAL_poolLastTmpGns[poolPath]", poolLastTmpGns[poolPath])
		if amount > 0 {
			if poolCurrentBlockGns[poolPath] >= amount {
				println("CALC__SAME_OR_LEFT")
				poolLastTmpGns[poolPath] = poolCurrentBlockGns[poolPath] - amount
				println("poolLastTmpGns[poolPath]", poolLastTmpGns[poolPath])
			} else {
				println("CALC__FINAL_WRONG")
				poolCurrentBlockGns[poolPath] = 0
			}
		} else {
			println("CALC__FINAL__amount = 0")
		}
	}

	// clear(poolCurrentBlockGns) // gno doesn't support `clear` keyword yet
	poolCurrentBlockGns = make(map[string]uint64)
	println("[----ENDENDEND] END_CALC_CalcPoolPosition")
}
