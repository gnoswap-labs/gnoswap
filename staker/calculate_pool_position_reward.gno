package staker

import (
	"std"
	"time"

	"gno.land/r/gnoswap/consts"

	u256 "gno.land/p/gnoswap/uint256"
)

var accuStakerGnsBalance uint64

// poolPath -> gnsAmount [accu]
var poolGns map[string]uint64 = make(map[string]uint64)

// poolPath -> gnsAmount [current block]
var poolCurrentBlockGns map[string]uint64 = make(map[string]uint64)

// poolPath -> gnsAmount [how much left from last block]
var poolLastTmpGns map[string]uint64 = make(map[string]uint64)

// poolPath -> accumulatedGns
var poolAccuGns map[string]uint64 = make(map[string]uint64)

// tokenId -> ratio -> gnsAmount
// var positionGns map[uint64]map[uint64]uint64 = make(map[uint64]map[uint64]uint64)
var positionGns map[uint64]map[uint64]*u256.Uint = make(map[uint64]map[uint64]*u256.Uint)

type externalRewards struct {
	incentiveId        string
	poolPath           string
	tokenPath          string
	tokenAmount        uint64
	tokenAmountClaimed uint64
}

// tokenId -> []externalRewards
var positionExternal map[uint64][]externalRewards = make(map[uint64][]externalRewards)

func CalcPoolPosition() {
	// println("HEIGHT", std.GetHeight())
	height := std.GetHeight()
	if height <= lastCalculatedHeight {
		return
	}

	// calculate pool
	stakerGnsBalance := gnsBalance(consts.STAKER_ADDR)

	println("AAA stakerGnsBalance\t\t", stakerGnsBalance)
	println("AAA lastGnsBalance\t\t", lastGnsBalance)

	mintedGnsAmount := stakerGnsBalance - lastGnsBalance
	println("75% // mintedGnsAmount\t\t", mintedGnsAmount)
	println()

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
		println("tierAmount:", tierAmount)
		poolCurrentBlockGns[poolPath] = tierAmount
		println("poolCurrentBlockGns[poolPath]:", poolCurrentBlockGns[poolPath])

		poolCurrentBlockGns[poolPath] += min(lastGnsBalance, poolLastTmpGns[poolPath]) // TMP
		println("ADD poolCurrentBlockGns[poolPath]:", poolCurrentBlockGns[poolPath])
		println("poolLastTmpGns[poolPath] #1:", poolLastTmpGns[poolPath])
		println()

		poolLastTmpGns[poolPath] = 0
		println("poolLastTmpGns[poolPath] #2:", poolLastTmpGns[poolPath])
	}

	_q96 := u256.MustFromDecimal(consts.Q96)

	for tokenId, deposit := range deposits {
	println()
		println("tokenId:", tokenId)
		poolPath := deposit.targetPoolPath
		poolCurrentBlockAmount := poolCurrentBlockGns[poolPath]
		println("poolCurrentBlockAmount:", poolCurrentBlockAmount)

		// XXX: REMOVE AFTER QA
		println(">> poolPath:", poolPath)
		println(">> poolCurrentBlockAmount:", poolCurrentBlockAmount)

		// calculate position gns rewards
		liqRatioX96 := getMyLiquidityRatio(poolPath, tokenId)

		// poolCurrentBlockAmountX96 := u256.Zero().Mul(u256.NewUint(poolCurrentBlockAmount), _q96)
		positionAmountX96 := u256.Zero().Mul(u256.NewUint(poolCurrentBlockAmount), liqRatioX96)
		// positionAmountX = u256.Zero().Div(positionAmountX, _q96)
		// positionAmount := positionAmountX.Uint64()
		// println("positionAmount:", positionAmount)

		nowHeight := std.GetHeight()
		stakeHeight := deposit.stakeHeight
		calcDuration := uint64(nowHeight - lastCalculatedHeight)
		// avgRewardPerBlock := positionAmount / calcDuration
		// println("calcDuration:", calcDuration)
		// println("avgRewardPerBlock:", avgRewardPerBlock)

		avgRewardPerBlockX96 := new(u256.Uint).Div(positionAmountX96, u256.NewUint(calcDuration))
		println("#### positionAmountX96:", positionAmountX96.ToString())
		println("avgRewardPerBlockX96:", avgRewardPerBlockX96.ToString())

		// println("lastCalculatedHeight:", lastCalculatedHeight)
		// println("stakingHeight:", stakeHeight)
		// println("lastCalculatedHeight:", lastCalculatedHeight)
		for i := lastCalculatedHeight; i < nowHeight; i++ {
			// println("ing height:", i)
			rewardRatio := getRewardRatio(i - stakeHeight)
			// println("rewardRatio:", rewardRatio)
			// println()

			if _, ok := positionGns[tokenId]; !ok {
				println("NEW", tokenId)
				positionGns[tokenId] = make(map[uint64]*u256.Uint)
			}

			if _, ok := positionGns[tokenId][rewardRatio]; !ok {
				println("NEWNEW", tokenId, "RATIO", rewardRatio)
				positionGns[tokenId][rewardRatio] = u256.Zero()
			}

			// println("ADD")
			// println("rewardRatio:", rewardRatio)
			// println("positionGns[tokenId][rewardRatio]:", positionGns[tokenId][rewardRatio].ToString())
			// println("avgRewardPerBlockX96:", avgRewardPerBlockX96.ToString())
			positionGns[tokenId][rewardRatio] = new(u256.Uint).Add(positionGns[tokenId][rewardRatio], avgRewardPerBlockX96)
		}

		for ratio, v := range positionGns[tokenId] {
			println("tokenId:", tokenId)
			println("ratio:", ratio)
			println("v:", v.ToString())
		}

		// rewardRatio := getRewardRatio(nowHeight - stakeHeight)

		// if _, ok := positionGns[tokenId]; !ok {
		// 	positionGns[tokenId] = make(map[uint64]uint64)
		// }
		// positionGns[tokenId][rewardRatio] += positionAmount
		positionAmount := new(u256.Uint).Div(positionAmountX96, _q96).Uint64()
		println("positionAmount:", positionAmount)
		// println("@@@@@@@@currentLeft:", currentLeft)
		// currentLeft -= positionAmount
		poolLastTmpGns[poolPath] += positionAmount
		// println("poolLastTmpGns[poolPath]", poolLastTmpGns[poolPath])
		// println("@@@@@@@@ tokenId:", tokenId, "positionAmount", positionAmount)
		// println("@@@@@@@@currentLeft:", currentLeft)
		// println()

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

	// poolLastTmpGns
	for poolPath, amount := range poolLastTmpGns {
		poolLastTmpGns[poolPath] = poolCurrentBlockGns[poolPath] - amount
		// println("UU poolPath:", poolPath)
		// println("UU Current:", poolCurrentBlockGns[poolPath])
		// println("UU amount:", amount)
		// println("UU poolLastTmpGns[poolPath]:", poolLastTmpGns[poolPath])
	}

	// clear tmp poolGns
	// clear(poolCurrentBlockGns) // gno doesn't support `clear` keyword yet
	poolCurrentBlockGns = make(map[string]uint64)

	lastGnsBalance = stakerGnsBalance
}
