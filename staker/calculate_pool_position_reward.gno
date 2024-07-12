package staker

import (
	"std"
	"time"

	"gno.land/r/gnoswap/consts"

	u256 "gno.land/p/gnoswap/uint256"
)

// poolPath -> gnsAmount [accu]
var poolGns map[string]uint64 = make(map[string]uint64)

// poolPath -> gnsAmount [current block]
var poolTmpGns map[string]uint64 = make(map[string]uint64)

// poolPath -> accumulatedGns
var poolAccuGns map[string]uint64 = make(map[string]uint64)

// tokenId -> gnsAmount
var positionGns map[uint64]uint64 = make(map[uint64]uint64)

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
	height := std.GetHeight()
	if height <= lastCalculatedHeight {
		return
	}

	// calculate pool
	stakerGnsBalance := gnsBalance(consts.STAKER_ADDR)
	mintedGnsAmount := stakerGnsBalance - lastGnsBalance

	lastGnsBalance = stakerGnsBalance

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

		poolTmpGns[poolPath] = tierAmount
	}

	for tokenId, deposit := range deposits {
		poolPath := deposit.targetPoolPath
		poolTmpAmount := poolTmpGns[poolPath]

		// calculate position gns rewards
		liqRatioX96 := getMyLiquidityRatio(poolPath, tokenId)
		liqRatioX96x100 := u256.Zero()
		liqRatioX96x100 = u256.Zero().Mul(liqRatioX96, u256.NewUint(100))
		liqRatiox100 := u256.Zero().Div(liqRatioX96x100, u256.MustFromDecimal(consts.Q96))
		liqRatio := liqRatiox100.Uint64()

		positionAmount := poolTmpAmount * liqRatio / 100
		positionGns[tokenId] += positionAmount

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
			liqRatioX96x100 := u256.Zero()
			liqRatioX96x100 = u256.Zero().Mul(liqRatioX96, u256.NewUint(100))
			liqRatiox100 := u256.Zero().Div(liqRatioX96x100, u256.MustFromDecimal(consts.Q96))
			liqRatio := liqRatiox100.Uint64()

			positionAmount := (rewardPerBlock * uint64(blocksPassed)) * liqRatio / 100
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

	// clear tmp poolGns
	// clear(poolTmpGns) // gno doesn't support `clear` keyword yet
	poolTmpGns = make(map[string]uint64)
}
