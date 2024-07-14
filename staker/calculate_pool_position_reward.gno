package staker

import (
	"std"
	"time"

	"gno.land/r/gnoswap/consts"

	"gno.land/r/gnoswap/gns"

	en "gno.land/r/gnoswap/emission"

	u256 "gno.land/p/gnoswap/uint256"
)

var accuStakerGnsBalance uint64

// poolPath -> gnsAmount [accu]
var poolGns map[string]uint64 = make(map[string]uint64)

// poolPath -> gnsAmount [current block]
var poolCurrentBlockGns map[string]uint64 = make(map[string]uint64)
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
	// println("HEIGHT", std.GetHeight())
	height := std.GetHeight()
	if height <= lastCalculatedHeight {
		return
	}

	// calculate pool
	stakerGnsBalance := gnsBalance(consts.STAKER_ADDR)
	println("@@@ stakerGnsBalance:", stakerGnsBalance)

	mintedGnsAmount := en.GetLastDistributeToStaker()
	if std.GetOrigCaller().String() == "" {
		println("CALC__ABCI_QUERY")
		if stakerGnsBalance > lastCalculatedBalance {
			mintedGnsAmount = stakerGnsBalance - lastCalculatedBalance
		}
	}

	// lastGnsBalance = stakerGnsBalance

	tier1Amount, tier2Amount, tier3Amount := getTiersAmount(mintedGnsAmount)
	tier1Num, tier2Num, tier3Num := getNumPoolTiers()

	for poolPath, internal := range poolTiers {
		tier := internal.tier
		tierAmount := uint64(0)
		if tier == 1 {
			tierAmount = tier1Amount / tier1Num
		} else if tier == 2 {
			tierAmount = tier2Amount / tier2Num
		} else if tier == 3 {
			tierAmount = tier3Amount / tier3Num
		}
		poolGns[poolPath] += tierAmount
		poolAccuGns[poolPath] += tierAmount

		// current block minted gns + left from last block distributed gns
		println("CALC__poolPath:", poolPath)
		println("CALC__tierAmount:", tierAmount)

		poolCurrentBlockGns[poolPath] = tierAmount
		println("CALC__poolCurrentBlockGns[poolPath]:", poolCurrentBlockGns[poolPath])

		// println("CALC__ADD poolLastTmpGns[poolPath]:", poolCurrentBlockGns[poolPath]+poolLastTmpGns[poolPath])
		// poolCurrentBlockGns[poolPath] += poolLastTmpGns[poolPath]
		// println("CALC__AFTER_ADD", poolCurrentBlockGns[poolPath])

		println("CALC__poolLastTmpGns[poolPath] #1:", poolLastTmpGns[poolPath])
		poolLastTmpGns[poolPath] = 0
		println("CALC__poolLastTmpGns[poolPath] #2:", poolLastTmpGns[poolPath])
	}

	_q96 := u256.MustFromDecimal(consts.Q96)

	for poolPath, _ := range poolTiers {
		totalStakedLiquidity := getPoolTotalStakedLiquidity(poolPath)
		println("CALC__poolPath:", poolPath, "totalStakedLiquidity:", totalStakedLiquidity.ToString())
		if totalStakedLiquidity.ToString() == "0" {
			println("CALC__POOL", poolPath, "HAS TIER BUT NONE STAEKD, SEND AMOUNT TO PROTOCOL FEE")
			println("CALC__STAKER BALANCE:", gnsBalance(consts.STAKER_ADDR))
			println("CALC__poolGns[poolPath]:", poolGns[poolPath])
			println("CALC__min(poolGns[poolPath], gnsBalance(consts.STAKER_ADDR)", min(poolGns[poolPath], gnsBalance(consts.STAKER_ADDR)))
			gns.Transfer(a2u(consts.PROTOCOL_FEE_ADDR), min(poolGns[poolPath], gnsBalance(consts.STAKER_ADDR)))
			poolGns[poolPath] = 0
			poolCurrentBlockGns[poolPath] = 0
		}
	}

	for tokenId, deposit := range deposits {
		println()
		println("tokenId:", tokenId)
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
		println("liqRatioX96:", liqRatioX96.ToString())
		println("positionAmountX:", positionAmountX.ToString())

		positionGns[tokenId] += positionAmount
		poolLastTmpGns[poolPath] -= positionAmount

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
		// position iterate ends
	}
	// update flag
	lastCalculatedHeight = height
	lastCalculatedBalance = stakerGnsBalance

	for poolPath, _ := range poolTiers {
		println("CALC__POOL", poolPath)
		amount := poolLastTmpGns[poolPath]
		println("CALC__amount", amount)
		if amount > 0 {
			poolLastTmpGns[poolPath] = poolCurrentBlockGns[poolPath] - amount
			println("CALC__!! amount", amount)
			println("CALC__!! poolLastTmpGns[poolPath]", poolLastTmpGns[poolPath])
		}
	}

	// clear(poolCurrentBlockGns) // gno doesn't support `clear` keyword yet
	poolCurrentBlockGns = make(map[string]uint64)

	println("[----ENDENDEND] END_CALC_CalcPoolPosition")
}
