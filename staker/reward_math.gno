package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v2/consts"

	pos "gno.land/r/gnoswap/v2/position"
)

type warmUpAmount struct {
	full30 uint64
	give30 uint64
	left30 uint64

	full50 uint64
	give50 uint64
	left50 uint64

	full70 uint64
	give70 uint64
	left70 uint64

	full100 uint64
	give100 uint64 // doesn't need this I think
	left100 uint64 // doesn't need this I think
}

var positionsInternalWarmUpAmount = make(map[uint64]warmUpAmount) // positionId => warmUpAmount

var positionsExternalWarmUpAmount = make(map[uint64]map[string]warmUpAmount)  // positionId => incentiveId => warmUpAmount
var positionsExternalLastCalculatedHeight = make(map[uint64]map[string]int64) // positionId => incentiveId => lastCalculatedHeight

func rewardMathComputeInternalRewardAmount(tokenId uint64) (uint64, uint64) {
	println("[ START ] REWARD__INTERNAL_rewardMathComputeInternalRewardAmount_TOKEN_ID:", tokenId)
	deposit := deposits[tokenId]

	// using block
	stakeHeight := deposit.stakeHeight
	currentHeight := std.GetHeight()
	stakedDuration := currentHeight - stakeHeight
	durationRatio := getRewardRatio(stakedDuration)

	println(" > REWARD__INTERNAL_rewardMathComputeInternalRewardAmount_HEIGHT:", currentHeight)

	// 과거 계산 시점부터 현재 블록까지 쌓인 리워드에 대해 각 가중치별로 분배
	toDistribute := positionGns[tokenId] - positionLastGns[tokenId]
	println(" > REWARD__INTERNAL_positionGns[tokenId]", positionGns[tokenId])
	println(" > REWARD__INTERNAL_positionLastGns[tokenId]", positionLastGns[tokenId])

	until30 := uint64(stakeHeight + warmUp[50] - 1)  // 150
	until50 := uint64(stakeHeight + warmUp[70] - 1)  // 300
	until70 := uint64(stakeHeight + warmUp[100] - 1) // 900
	begin100 := uint64(stakeHeight + warmUp[100])    // 901~

	lastCalculatedHeightU64 := uint64(lastCalculatedHeight)

	q96 := u256.MustFromDecimal(consts.Q96)
	toDistributeX96 := new(u256.Uint).Mul(u256.NewUint(toDistribute), q96)
	avgGnsBlockAmountX96 := new(u256.Uint).Div(toDistributeX96, u256.NewUint(uint64(currentHeight)-lastCalculatedHeightU64))
	println(" > REWARD__INTERNAL_toDistribute:", toDistribute)
	println(" > REWARD__INTERNAL_uint64(currentHeight)-lastCalculatedHeightU64):", uint64(currentHeight)-lastCalculatedHeightU64)
	println(" > REWARD__INTERNAL_avgGnsBlockAmountX96:", avgGnsBlockAmountX96.ToString())

	positionWarmUpAmount, exist := positionsInternalWarmUpAmount[tokenId]
	if !exist {
		panic("THIS SHOULD NOT HAPPEN")
	}
	println(" > REWARD__INTERNAL_BEFORE_positionWarmUpAmount.full100", positionWarmUpAmount.full100)
	println(" > REWARD__INTERNAL_BEFORE_positionWarmUpAmount.give100", positionWarmUpAmount.give100)
	println(" > REWARD__INTERNAL_BEFORE_positionWarmUpAmount.left100", positionWarmUpAmount.left100)
	println()
	println(" > REWARD__INTERNAL_BEFORE_positionWarmUpAmount.full70", positionWarmUpAmount.full70)
	println(" > REWARD__INTERNAL_BEFORE_positionWarmUpAmount.give70", positionWarmUpAmount.give70)
	println(" > REWARD__INTERNAL_BEFORE_positionWarmUpAmount.left70", positionWarmUpAmount.left70)
	println()
	println(" > REWARD__INTERNAL_BEFORE_positionWarmUpAmount.full50", positionWarmUpAmount.full50)
	println(" > REWARD__INTERNAL_BEFORE_positionWarmUpAmount.give50", positionWarmUpAmount.give50)
	println(" > REWARD__INTERNAL_BEFORE_positionWarmUpAmount.left50", positionWarmUpAmount.left50)
	println()
	println(" > REWARD__INTERNAL_BEFORE_positionWarmUpAmount.full30", positionWarmUpAmount.full30)
	println(" > REWARD__INTERNAL_BEFORE_positionWarmUpAmount.give30", positionWarmUpAmount.give30)
	println(" > REWARD__INTERNAL_BEFORE_positionWarmUpAmount.left30", positionWarmUpAmount.left30)
	println()

	switch durationRatio {
	case 100:
		if lastCalculatedHeightU64 > begin100 {
			println(" > REWARD__INTERNAL_REWARD ONLY 100%")
			// 100%
			dur100 := uint64(currentHeight) - lastCalculatedHeightU64
			println("  > REWARD__INTERNAL_DUR100", dur100)
			full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
			// println("  > REWARD__INTERNAL_AMOUNT100", amount)
			positionWarmUpAmount.full100 += full
			positionWarmUpAmount.give100 += toGive
			positionWarmUpAmount.left100 += full - toGive
			// gnsAmountToGive += amount // UPDATE EACH PERIOD
			// println("  > REWARD__INTERNAL_100%", gnsAmountToGive)
		} else {
			if lastCalculatedHeightU64 > until50 {
				println(" > REWARD__INTERNAL_REWARD 100% AND 70%")
				// 100%
				dur100 := uint64(currentHeight) - until70
				println("  > REWARD__INTERNAL_DUR100", dur100)
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
				positionWarmUpAmount.full100 += full
				positionWarmUpAmount.give100 += toGive
				positionWarmUpAmount.left100 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT100", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__INTERNAL_100%", gnsAmountToGive)

				// 70%
				dur70 := until70 - lastCalculatedHeightU64
				println("  > REWARD__INTERNAL_DUR70", dur70)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT70", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__INTERNAL_70%", gnsAmountToGive)
			} else if lastCalculatedHeightU64 > until30 {
				println(" > REWARD__INTERNAL_REWARD 100% AND 70% AND 50%")
				// 100%
				dur100 := uint64(currentHeight) - until70
				println("  > REWARD__INTERNAL_DUR100", dur100)
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
				positionWarmUpAmount.full100 += full
				positionWarmUpAmount.give100 += toGive
				positionWarmUpAmount.left100 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT100", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__INTERNAL_100%", gnsAmountToGive)

				// 70%
				dur70 := until70 - until50
				println("  > REWARD__INTERNAL_DUR70", dur70)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT70", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__INTERNAL_70%", gnsAmountToGive)

				// 50%
				dur50 := until50 - lastCalculatedHeightU64
				println("  > REWARD__INTERNAL_DUR50", dur50)
				// println("  > REWARD__INTERNAL_50%", gnsAmountToGive)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur50, 50)
				positionWarmUpAmount.full50 += full
				positionWarmUpAmount.give50 += toGive
				positionWarmUpAmount.left50 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT50", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
			} else {
				println(" > REWARD__INTERNAL_REWARD 100% AND 70% AND 50% AND 30%")
				// 100%
				dur100 := uint64(currentHeight) - until70
				println("  > REWARD__INTERNAL_DUR100", dur100)
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
				positionWarmUpAmount.full100 += full
				positionWarmUpAmount.give100 += toGive
				positionWarmUpAmount.left100 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT100", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__INTERNAL_100%", gnsAmountToGive)

				// 70%
				dur70 := until70 - until50
				println("  > REWARD__INTERNAL_DUR70", dur70)
				// println("  > REWARD__INTERNAL_70%", gnsAmountToGive)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT70", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD

				// 50%
				dur50 := until50 - until30
				println("  > REWARD__INTERNAL_DUR50", dur50)
				// println("  > REWARD__INTERNAL_50%", gnsAmountToGive)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur50, 50)
				positionWarmUpAmount.full50 += full
				positionWarmUpAmount.give50 += toGive
				positionWarmUpAmount.left50 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT50", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD

				// 30%
				dur30 := until30 - lastCalculatedHeightU64
				println("  > REWARD__INTERNAL_DUR30", dur30)
				// println("  > REWARD__INTERNAL_30%", gnsAmountToGive)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur30, 30)
				positionWarmUpAmount.full30 += full
				positionWarmUpAmount.give30 += toGive
				positionWarmUpAmount.left30 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT30", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
			}
		}

	case 70:
		if lastCalculatedHeightU64 > until50 {
			println(" > REWARD__INTERNAL_REWARD ONLY 70%")
			// 70%
			dur70 := uint64(currentHeight) - lastCalculatedHeightU64
			println("  > REWARD__INTERNAL_DUR70", dur70)
			full, toGive := calcAmount(avgGnsBlockAmountX96, dur70, 70)
			positionWarmUpAmount.full70 += full
			positionWarmUpAmount.give70 += toGive
			positionWarmUpAmount.left70 += full - toGive
			// println("  > REWARD__INTERNAL_AMOUNT70", amount)
			// gnsAmountToGive += amount // UPDATE EACH PERIOD
			// println("  > REWARD__INTERNAL_70%", gnsAmountToGive)
		} else {
			if lastCalculatedHeightU64 > until30 {
				println(" > REWARD__INTERNAL_REWAWRD 70% AND 50%")
				// 70%
				dur70 := uint64(currentHeight) - until50
				println("  > REWARD__INTERNAL_DUR70", dur70)
				// println("  > REWARD__INTERNAL_70%", gnsAmountToGive)
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT70", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD

				// 50%
				dur50 := until50 - lastCalculatedHeightU64
				println("  > REWARD__INTERNAL_DUR50", dur50)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur50, 50)
				positionWarmUpAmount.full50 += full
				positionWarmUpAmount.give50 += toGive
				positionWarmUpAmount.left50 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT50", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__INTERNAL_50%", gnsAmountToGive)
			} else {
				println(" > REWARD__INTERNAL_REWARD 70% AND 50% AND 30%")
				// 70%
				dur70 := uint64(currentHeight) - until50
				println("  > REWARD__INTERNAL_DUR70", dur70)
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT70", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__INTERNAL_70%", gnsAmountToGive)

				// 50%
				dur50 := until50 - until30
				println("  > REWARD__INTERNAL_DUR50", dur50)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur50, 50)
				positionWarmUpAmount.full50 += full
				positionWarmUpAmount.give50 += toGive
				positionWarmUpAmount.left50 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT50", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__INTERNAL_50%", gnsAmountToGive)

				// 30%
				dur30 := until30 - lastCalculatedHeightU64
				println("  > REWARD__INTERNAL_DUR30", dur30)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur30, 30)
				positionWarmUpAmount.full30 += full
				positionWarmUpAmount.give30 += toGive
				positionWarmUpAmount.left30 += full - toGive
				// println("  > REWARD__INTERNAL_AMOUNT30", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__INTERNAL_30%", gnsAmountToGive)
			}
		}

	case 50:
		if lastCalculatedHeightU64 > until30 {
			println(" > REWARD__INTERNAL_REWARD ONLY 50%")
			// 50%
			dur50 := uint64(currentHeight) - lastCalculatedHeightU64
			println("  > REWARD__INTERNAL_DUR50", dur50)
			full, toGive := calcAmount(avgGnsBlockAmountX96, dur50, 50)
			positionWarmUpAmount.full50 += full
			positionWarmUpAmount.give50 += toGive
			positionWarmUpAmount.left50 += full - toGive
			// println("  > REWARD__INTERNAL_AMOUNT50", amount)
			// gnsAmountToGive += amount // UPDATE EACH PERIOD
			// println("  > REWARD__INTERNAL_50%", gnsAmountToGive)
		} else {
			println(" > REWARD__INTERNAL_REWAD 50% AND 30%")
			dur50 := uint64(currentHeight) - until30
			println("  > REWARD__INTERNAL_DUR50", dur50)
			full, toGive := calcAmount(avgGnsBlockAmountX96, dur50, 50)
			positionWarmUpAmount.full50 += full
			positionWarmUpAmount.give50 += toGive
			positionWarmUpAmount.left50 += full - toGive
			// println("  > REWARD__INTERNAL_AMOUNT50", amount)
			// gnsAmountToGive += amount // UPDATE EACH PERIOD
			// println("  > REWARD__INTERNAL_50%", gnsAmountToGive)

			// 30%
			dur30 := until30 - lastCalculatedHeightU64
			full, toGive = calcAmount(avgGnsBlockAmountX96, dur30, 30)
			positionWarmUpAmount.full30 += full
			positionWarmUpAmount.give30 += toGive
			positionWarmUpAmount.left30 += full - toGive
			// println("  > REWARD__INTERNAL_AMOUNT30", amount)
			// gnsAmountToGive += amount // UPDATE EACH PERIOD
			println("  > REWARD__INTERNAL_DUR30", dur30)
			// println("  > REWARD__INTERNAL_30%", gnsAmountToGive)
		}

	case 30:
		println(" > REWARD__INTERNAL_REWARD 30%")
		dur30 := uint64(currentHeight) - lastCalculatedHeightU64
		full, toGive := calcAmount(avgGnsBlockAmountX96, dur30, 30)
		positionWarmUpAmount.full30 += full
		positionWarmUpAmount.give30 += toGive
		positionWarmUpAmount.left30 += full - toGive
		// gnsAmountToGive += amount // UPDATE EACH PERIOD
		// println("  > REWARD__INTERNAL_AMOUNT30", amount)
		println("  > REWARD__INTERNAL_DUR30", dur30)
		// println("  > REWARD__INTERNAL_30%", amount)

	default:
		println(" > REWARD__INTERNAL_0 REWARD RATIO")
	}

	println(" > REWARD__INTERNAL_STAKER", gnsBalance(consts.STAKER_ADDR))
	println(" > REWARD__INTERNAL_tokenId:", tokenId)
	println(" > REWARD__INTERNAL_toDistribute:", toDistribute)
	// println(" > REWARD__INTERNAL_gnsAmountToGive", gnsAmountToGive)

	println(" > REWARD__INTERNAL_stakeHeight:", stakeHeight)
	println(" > REWARD__INTERNAL_durationRatio:", durationRatio)
	println(" > REWARD__INTERNAL_currentHeight:", currentHeight)
	println(" > REWARD__INTERNAL_[?] lastCalculatedHeight:", lastCalculatedHeight)
	println(" > REWARD__INTERNAL_until30:", until30)
	println(" > REWARD__INTERNAL_until50:", until50)
	println(" > REWARD__INTERNAL_until70:", until70)
	println(" > REWARD__INTERNAL_begin100:", begin100)

	println(" > REWARD__INTERNAL_full30:", positionWarmUpAmount.full30)
	println(" > REWARD__INTERNAL_give30:", positionWarmUpAmount.give30)

	println(" > REWARD__INTERNAL_full50:", positionWarmUpAmount.full50)
	println(" > REWARD__INTERNAL_give50:", positionWarmUpAmount.give50)

	println(" > REWARD__INTERNAL_full70:", positionWarmUpAmount.full70)
	println(" > REWARD__INTERNAL_give70:", positionWarmUpAmount.give70)

	println(" > REWARD__INTERNAL_full100:", positionWarmUpAmount.full100)
	println(" > REWARD__INTERNAL_give100:", positionWarmUpAmount.give100)

	accuFull := uint64(0)
	accuGive := uint64(0)

	accuFull += positionWarmUpAmount.full30 + positionWarmUpAmount.full50 + positionWarmUpAmount.full70 + positionWarmUpAmount.full100
	accuGive += positionWarmUpAmount.give30 + positionWarmUpAmount.give50 + positionWarmUpAmount.give70 + positionWarmUpAmount.give100

	println(" > REWARD__INTERNAL_accuFull:", accuFull)
	println(" > REWARD__INTERNAL_accuGive:", accuGive)

	positionsInternalWarmUpAmount[tokenId] = positionWarmUpAmount
	println(" > REWARD__INTERNAL_positionsInternalWarmUpAmount[tokenId]:", positionsInternalWarmUpAmount[tokenId])

	println("[ END ] REWARD__INTERNAL_rewardMathComputeInternalRewardAmount_TOKEN_ID:", tokenId)
	println()

	return accuFull, accuGive
}

func rewardMathComputeExternalRewardAmount(tokenId uint64, incentiveId string) (uint64, uint64) {
	println("[ START ] REWARD__EXTERNAL_rewardMathComputeInternalRewardAmount_TOKEN_ID:", tokenId)
	println("  > REWARD__EXTERNAL_incentiveId:", incentiveId)

	currentHeight := std.GetHeight()

	externals := positionExternal[tokenId]

	_max := max(incentives[incentiveId].startTimestamp, deposits[tokenId].stakeTimestamp)
	println("  > REWARD__EXTERNAL_incentives[incentiveId].startTimestamp:", incentives[incentiveId].startTimestamp)
	println("  > REWARD__EXTERNAL_deposits[tokenId].stakeTimestamp:", deposits[tokenId].stakeTimestamp)
	println("  > REWARD__EXTERNAL_max:", _max)

	stakedOrExternalDuration := (time.Now().Unix() - _max) / consts.BLOCK_GENERATION_INTERVAL
	println("  > REWARD__EXTERNAL_time.Now().Unix():", time.Now().Unix())
	println("  > REWARD__EXTERNAL_consts.BLOCK_GENERATION_INTERVAL:", consts.BLOCK_GENERATION_INTERVAL)
	println("  > REWARD__EXTERNAL_stakedOrExternalDuration:", stakedOrExternalDuration)

	stakedOrExternalStartedHeight := std.GetHeight() - stakedOrExternalDuration
	println("  > REWARD__EXTERNAL_height:", std.GetHeight())
	println("  > REWARD__EXTERNAL_stakedOrExternalStartedHeight:", stakedOrExternalStartedHeight)

	until30 := uint64(stakedOrExternalStartedHeight + warmUp[50] - 1)  // 150
	until50 := uint64(stakedOrExternalStartedHeight + warmUp[70] - 1)  // 300
	until70 := uint64(stakedOrExternalStartedHeight + warmUp[100] - 1) // 900
	begin100 := uint64(stakedOrExternalStartedHeight + warmUp[100])    // 901~

	for _, external := range externals {
		if external.incentiveId == incentiveId {
			println("   > REWARD__EXTERNAL_incentiveId:", incentiveId)

			tokenAmountX96 := external.tokenAmountX96
			toDistributeX96 := new(u256.Uint).Sub(tokenAmountX96, positionLastExternal[tokenId][incentiveId])
			println("   > REWARD__EXTERNAL_tokenAmountX96:", tokenAmountX96.ToString())
			println("   > REWARD__EXTERNAL_positionLastExternal[tokenId][incentiveId]:", positionLastExternal[tokenId][incentiveId].ToString())
			println("   > REWARD__EXTERNAL_toDistributeX96:", toDistributeX96.ToString())
			if tokenAmountX96.Lt(positionLastExternal[tokenId][incentiveId]) {
				panic("THIS SHOULD NOT HAPPEN_EXTERNAL #1")
			}

			lastCalculatedHeightU64 := uint64(positionsExternalLastCalculatedHeight[tokenId][incentiveId])
			println("   > REWARD__EXTERNAL_lastCalculatedHeightU64:", lastCalculatedHeightU64)

			avgExternalBlockAmountX96 := new(u256.Uint).Div(toDistributeX96, u256.NewUint(uint64(std.GetHeight())-lastCalculatedHeightU64))
			println("   > REWARD__EXTERNAL_toDistirbuteX96:", toDistributeX96.ToString())
			println("   > REWARD__EXTERNAL_uint64(std.GetHeight())-lastCalculatedHeightU64):", uint64(std.GetHeight())-lastCalculatedHeightU64)
			println("   > REWARD__EXTERNAL_avgExternalBlockAmountX96:", avgExternalBlockAmountX96.ToString())

			positionExternalWarmUpAmount, exist := positionsExternalWarmUpAmount[tokenId][incentiveId]
			if !exist {
				println("tokenId:", tokenId)
				println("incentiveId:", incentiveId)
				panic("THIS SHOULD NOT HAPPEN_EXTERNAL #2")
			}

			println("   > REWARD__EXTERNAL_BEFORE_positionExternalWarmUpAmount.full100", positionExternalWarmUpAmount.full100)
			println("   > REWARD__EXTERNAL_BEFORE_positionExternalWarmUpAmount.give100", positionExternalWarmUpAmount.give100)
			println("   > REWARD__EXTERNAL_BEFORE_positionExternalWarmUpAmount.left100", positionExternalWarmUpAmount.left100)
			println()
			println("   > REWARD__EXTERNAL_BEFORE_positionExternalWarmUpAmount.full70", positionExternalWarmUpAmount.full70)
			println("   > REWARD__EXTERNAL_BEFORE_positionExternalWarmUpAmount.give70", positionExternalWarmUpAmount.give70)
			println("   > REWARD__EXTERNAL_BEFORE_positionExternalWarmUpAmount.left70", positionExternalWarmUpAmount.left70)
			println()
			println("   > REWARD__EXTERNAL_BEFORE_positionExternalWarmUpAmount.full50", positionExternalWarmUpAmount.full50)
			println("   > REWARD__EXTERNAL_BEFORE_positionExternalWarmUpAmount.give50", positionExternalWarmUpAmount.give50)
			println("   > REWARD__EXTERNAL_BEFORE_positionExternalWarmUpAmount.left50", positionExternalWarmUpAmount.left50)
			println()
			println("   > REWARD__EXTERNAL_BEFORE_positionExternalWarmUpAmount.full30", positionExternalWarmUpAmount.full30)
			println("   > REWARD__EXTERNAL_BEFORE_positionExternalWarmUpAmount.give30", positionExternalWarmUpAmount.give30)
			println("   > REWARD__EXTERNAL_BEFORE_positionExternalWarmUpAmount.left30", positionExternalWarmUpAmount.left30)
			println()

			durationRatio := getRewardRatio(stakedOrExternalDuration)

			switch durationRatio {
			case 100:
				if lastCalculatedHeightU64 > begin100 {
					println(" > REWARD__EXTERNAL_REWARD ONLY 100%")
					// 100%
					dur100 := uint64(currentHeight) - lastCalculatedHeightU64
					println("  > REWARD__EXTERNAL_DUR100", dur100)
					full, toGive := calcAmount(avgExternalBlockAmountX96, dur100, 100)
					positionExternalWarmUpAmount.full100 += full
					positionExternalWarmUpAmount.give100 += toGive
					positionExternalWarmUpAmount.left100 += full - toGive
					// gnsAmountToGive += amount // UPDATE EACH PERIOD
				} else {
					if lastCalculatedHeightU64 > until50 {
						println(" > REWARD__EXTERNAL_REWARD 100% AND 70%")
						// 100%
						dur100 := uint64(currentHeight) - until70
						println("  > REWARD__EXTERNAL_DUR100", dur100)
						full, toGive := calcAmount(avgExternalBlockAmountX96, dur100, 100)
						positionExternalWarmUpAmount.full100 += full
						positionExternalWarmUpAmount.give100 += toGive
						positionExternalWarmUpAmount.left100 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD

						// 70%
						dur70 := until70 - lastCalculatedHeightU64
						println("  > REWARD__EXTERNAL_DUR70", dur70)
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur70, 70)
						positionExternalWarmUpAmount.full70 += full
						positionExternalWarmUpAmount.give70 += toGive
						positionExternalWarmUpAmount.left70 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD
					} else if lastCalculatedHeightU64 > until30 {
						println(" > REWARD__EXTERNAL_REWARD 100% AND 70% AND 50%")
						// 100%
						dur100 := uint64(currentHeight) - until70
						println("  > REWARD__EXTERNAL_DUR100", dur100)
						full, toGive := calcAmount(avgExternalBlockAmountX96, dur100, 100)
						positionExternalWarmUpAmount.full100 += full
						positionExternalWarmUpAmount.give100 += toGive
						positionExternalWarmUpAmount.left100 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD

						// 70%
						dur70 := until70 - until50
						println("  > REWARD__EXTERNAL_DUR70", dur70)
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur70, 70)
						positionExternalWarmUpAmount.full70 += full
						positionExternalWarmUpAmount.give70 += toGive
						positionExternalWarmUpAmount.left70 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD

						// 50%
						dur50 := until50 - lastCalculatedHeightU64
						println("  > REWARD__EXTERNAL_DUR50", dur50)
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur50, 50)
						positionExternalWarmUpAmount.full50 += full
						positionExternalWarmUpAmount.give50 += toGive
						positionExternalWarmUpAmount.left50 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD
					} else {
						println(" > REWARD__EXTERNAL_REWARD 100% AND 70% AND 50% AND 30%")
						// 100%
						dur100 := uint64(currentHeight) - until70
						println("  > REWARD__EXTERNAL_DUR100", dur100)
						full, toGive := calcAmount(avgExternalBlockAmountX96, dur100, 100)
						positionExternalWarmUpAmount.full100 += full
						positionExternalWarmUpAmount.give100 += toGive
						positionExternalWarmUpAmount.left100 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD

						// 70%
						dur70 := until70 - until50
						println("  > REWARD__EXTERNAL_DUR70", dur70)
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur70, 70)
						positionExternalWarmUpAmount.full70 += full
						positionExternalWarmUpAmount.give70 += toGive
						positionExternalWarmUpAmount.left70 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD

						// 50%
						dur50 := until50 - until30
						println("  > REWARD__EXTERNAL_DUR50", dur50)
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur50, 50)
						positionExternalWarmUpAmount.full50 += full
						positionExternalWarmUpAmount.give50 += toGive
						positionExternalWarmUpAmount.left50 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD

						// 30%
						dur30 := until30 - lastCalculatedHeightU64
						println("  > REWARD__EXTERNAL_DUR30", dur30)
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur30, 30)
						positionExternalWarmUpAmount.full30 += full
						positionExternalWarmUpAmount.give30 += toGive
						positionExternalWarmUpAmount.left30 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD
					}
				}

			case 70:
				if lastCalculatedHeightU64 > until50 {
					println(" > REWARD__EXTERNAL_REWARD ONLY 70%")
					// 70%
					dur70 := uint64(currentHeight) - lastCalculatedHeightU64
					println("  > REWARD__EXTERNAL_DUR70", dur70)
					full, toGive := calcAmount(avgExternalBlockAmountX96, dur70, 70)
					positionExternalWarmUpAmount.full70 += full
					positionExternalWarmUpAmount.give70 += toGive
					positionExternalWarmUpAmount.left70 += full - toGive
					// gnsAmountToGive += amount // UPDATE EACH PERIOD
				} else {
					if lastCalculatedHeightU64 > until30 {
						println(" > REWARD__EXTERNAL_REWAWRD 70% AND 50%")
						// 70%
						dur70 := uint64(currentHeight) - until50
						println("  > REWARD__EXTERNAL_DUR70", dur70)
						full, toGive := calcAmount(avgExternalBlockAmountX96, dur70, 70)
						positionExternalWarmUpAmount.full70 += full
						positionExternalWarmUpAmount.give70 += toGive
						positionExternalWarmUpAmount.left70 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD

						// 50%
						dur50 := until50 - lastCalculatedHeightU64
						println("  > REWARD__EXTERNAL_DUR50", dur50)
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur50, 50)
						positionExternalWarmUpAmount.full50 += full
						positionExternalWarmUpAmount.give50 += toGive
						positionExternalWarmUpAmount.left50 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD
					} else {
						println(" > REWARD__EXTERNAL_REWARD 70% AND 50% AND 30%")
						// 70%
						dur70 := uint64(currentHeight) - until50
						println("  > REWARD__EXTERNAL_DUR70", dur70)
						full, toGive := calcAmount(avgExternalBlockAmountX96, dur70, 70)
						positionExternalWarmUpAmount.full70 += full
						positionExternalWarmUpAmount.give70 += toGive
						positionExternalWarmUpAmount.left70 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD

						// 50%
						dur50 := until50 - until30
						println("  > REWARD__EXTERNAL_DUR50", dur50)
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur50, 50)
						positionExternalWarmUpAmount.full50 += full
						positionExternalWarmUpAmount.give50 += toGive
						positionExternalWarmUpAmount.left50 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD

						// 30%
						dur30 := until30 - lastCalculatedHeightU64
						println("  > REWARD__EXTERNAL_DUR30", dur30)
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur30, 30)
						positionExternalWarmUpAmount.full30 += full
						positionExternalWarmUpAmount.give30 += toGive
						positionExternalWarmUpAmount.left30 += full - toGive
						// gnsAmountToGive += amount // UPDATE EACH PERIOD
					}
				}

			case 50:
				if lastCalculatedHeightU64 > until30 {
					println(" > REWARD__EXTERNAL_REWARD ONLY 50%")
					// 50%
					dur50 := uint64(currentHeight) - lastCalculatedHeightU64
					println("  > REWARD__EXTERNAL_DUR50", dur50)
					full, toGive := calcAmount(avgExternalBlockAmountX96, dur50, 50)
					positionExternalWarmUpAmount.full50 += full
					positionExternalWarmUpAmount.give50 += toGive
					positionExternalWarmUpAmount.left50 += full - toGive
					// gnsAmountToGive += amount // UPDATE EACH PERIOD
				} else {
					println(" > REWARD__EXTERNAL_REWAD 50% AND 30%")
					dur50 := uint64(currentHeight) - until30
					println("  > REWARD__EXTERNAL_DUR50", dur50)
					full, toGive := calcAmount(avgExternalBlockAmountX96, dur50, 50)
					positionExternalWarmUpAmount.full50 += full
					positionExternalWarmUpAmount.give50 += toGive
					positionExternalWarmUpAmount.left50 += full - toGive
					// gnsAmountToGive += amount // UPDATE EACH PERIOD

					// 30%
					dur30 := until30 - lastCalculatedHeightU64
					full, toGive = calcAmount(avgExternalBlockAmountX96, dur30, 30)
					positionExternalWarmUpAmount.full30 += full
					positionExternalWarmUpAmount.give30 += toGive
					positionExternalWarmUpAmount.left30 += full - toGive
					// gnsAmountToGive += amount // UPDATE EACH PERIOD
					println("  > REWARD__EXTERNAL_DUR30", dur30)
				}

			case 30:
				println(" > REWARD__EXTERNAL_REWARD 30%")
				dur30 := uint64(currentHeight) - lastCalculatedHeightU64
				full, toGive := calcAmount(avgExternalBlockAmountX96, dur30, 30)
				positionExternalWarmUpAmount.full30 += full
				positionExternalWarmUpAmount.give30 += toGive
				positionExternalWarmUpAmount.left30 += full - toGive
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				println("  > REWARD__EXTERNAL_DUR30", dur30)

			default:
				println("  > REWARD__EXTERNAL_0 REWARD RATIO")
			}

			println()
			println("  > REWARD_==================================")
			println("  > REWARD__EXTERNAL_tokenId:", tokenId)
			println("  > REWARD__EXTERNAL_toDistirbuteX96:", toDistributeX96.ToString())

			println("  > REWARD__EXTERNAL_currentHeight:", currentHeight)
			println("  > REWARD__EXTERNAL_stakeHeight:", deposits[tokenId].stakeHeight)
			println("  > REWARD__EXTERNAL_stakedOrExternalStartedHeight:", stakedOrExternalStartedHeight)
			println("  > REWARD__EXTERNAL_stakedOrExternalDuration:", stakedOrExternalDuration)
			println("  > REWARD__EXTERNAL_durationRatio:", durationRatio)
			println("  > REWARD__EXTERNAL_lastCalculatedHeightU64:", lastCalculatedHeightU64)
			println("  > REWARD__EXTERNAL_until30:", until30)
			println("  > REWARD__EXTERNAL_until50:", until50)
			println("  > REWARD__EXTERNAL_until70:", until70)
			println("  > REWARD__EXTERNAL_begin100:", begin100)

			println("  > REWARD__EXTERNAL_full30:", positionExternalWarmUpAmount.full30)
			println("  > REWARD__EXTERNAL_give30:", positionExternalWarmUpAmount.give30)

			println("  > REWARD__EXTERNAL_full50:", positionExternalWarmUpAmount.full50)
			println("  > REWARD__EXTERNAL_give50:", positionExternalWarmUpAmount.give50)

			println("  > REWARD__EXTERNAL_full70:", positionExternalWarmUpAmount.full70)
			println("  > REWARD__EXTERNAL_give70:", positionExternalWarmUpAmount.give70)

			println("  > REWARD__EXTERNAL_full100:", positionExternalWarmUpAmount.full100)
			println("  > REWARD__EXTERNAL_give100:", positionExternalWarmUpAmount.give100)

			accuFull := uint64(0)
			accuGive := uint64(0)

			accuFull += positionExternalWarmUpAmount.full30 + positionExternalWarmUpAmount.full50 + positionExternalWarmUpAmount.full70 + positionExternalWarmUpAmount.full100
			accuGive += positionExternalWarmUpAmount.give30 + positionExternalWarmUpAmount.give50 + positionExternalWarmUpAmount.give70 + positionExternalWarmUpAmount.give100

			println("  > REWARD__EXTERNAL_accuFull:", accuFull)
			println("  > REWARD__EXTERNAL_accuGive:", accuGive)

			positionsExternalWarmUpAmount[tokenId][incentiveId] = positionExternalWarmUpAmount
			// println("  > REWARD__EXTERNAL_positionsExternalWarmUpAmount[tokenId][incentiveId]:", positionsExternalWarmUpAmount[tokenId][incentiveId])

			println("[ END ] REWARD__EXTERNAL_rewardMathComputeExternalRewardAmount_TOKEN_ID:", tokenId, " INCENTIVE_ID:", incentiveId)
			println()

			return accuFull, accuGive
		}
	}

	panic("NO INCENTIVE_ID FOUND")
}

func getPoolTotalStakedLiquidity(poolPath string) *u256.Uint {
	poolStakedLiquidity := u256.Zero()
	// get all staked liquidity
	for tokenId, deposit := range deposits { // key is tokenId // used in this range loop only
		if deposit.targetPoolPath == poolPath {
			isInRange := pos.PositionIsInRange(tokenId)
			if isInRange == false {
				continue
			}

			positionLiquidity := pos.PositionGetPositionLiquidity(tokenId)
			poolStakedLiquidity = new(u256.Uint).Add(poolStakedLiquidity, positionLiquidity)
		}
	}

	return poolStakedLiquidity
}

func getMyLiquidityRatio(poolPath string, tokenId uint64) *u256.Uint {
	_q96 := u256.MustFromDecimal(consts.Q96)

	poolStakedLiquidity := getPoolTotalStakedLiquidity(poolPath)
	// XXX REMOVE AFTER QA
	// println()
	// println("tokenId:", tokenId)
	// println("POOL_LIQ:", poolStakedLiquidity.ToString())

	// my(current tokenId) liquidity
	myLiquidity := pos.PositionGetPositionLiquidity(tokenId)

	// XXX REMOVE AFTER QA
	// println("MY_LIQ:", myLiquidity.ToString())

	isInRange := pos.PositionIsInRange(tokenId)
	if isInRange == false {
		return u256.Zero()
	}

	myLiquidityX96 := new(u256.Uint).Mul(myLiquidity, _q96)
	myLiquidityX96X10000000 := new(u256.Uint).Mul(myLiquidityX96, u256.NewUint(1_000_000_000))

	poolStakedLiquidityX96 := new(u256.Uint).Mul(poolStakedLiquidity, _q96)

	myLiquidityRatio := new(u256.Uint).Div(myLiquidityX96X10000000, poolStakedLiquidityX96) // this value needs to be divided by 1_000_000_000
	myLiquidityRatio = new(u256.Uint).Mul(myLiquidityRatio, _q96)                           // so first mul consts.Q96
	myLiquidityRatio = new(u256.Uint).Div(myLiquidityRatio, u256.NewUint(1_000_000_000))    // then divided by 1_000_000_000

	// XXX REMOVE AFTER QA
	// println("myLiquidityRatio:", myLiquidityRatio.ToString())
	return myLiquidityRatio
}

// get current pool tier and reward ratio
func getPoolTierAndRatio(poolPath string) (uint64, *u256.Uint) {
	_q96 := u256.MustFromDecimal(consts.Q96)

	// current pool's tier
	internal, ok := poolTiers[poolPath]
	if !ok {
		return 0, u256.Zero()
	}
	tier := internal.tier

	// that tiers ratio
	ratio := getTierRatio(tier)
	ratioX96 := new(u256.Uint).Mul(u256.NewUint(ratio), _q96) // first consts.Q96

	// finally current pools ratio
	numTier1, numTier2, numTier3 := getNumPoolTiers()

	var weight *u256.Uint
	switch tier {
	case 1:
		weight = new(u256.Uint).Div(ratioX96, u256.NewUint(numTier1))
	case 2:
		weight = new(u256.Uint).Div(ratioX96, u256.NewUint(numTier2))
	case 3:
		weight = new(u256.Uint).Div(ratioX96, u256.NewUint(numTier3))
	default:
		panic(ufmt.Sprintf("[STAKER] reward_math.gno__getPoolTierAndRatio() || invalid tier(%d)", tier))
	}

	return tier, weight
}

// get number of pools for each tier
func getNumPoolTiers() (uint64, uint64, uint64) {
	var tier1, tier2, tier3 uint64

	for _, v := range poolTiers {
		switch v.tier {
		case 1:
			tier1++
		case 2:
			tier2++
		case 3:
			tier3++
		default:
			panic(ufmt.Sprintf("[STAKER] reward_math.gno__getNumPoolTiers() || invalid tier(%d)", v))
		}
	}

	return tier1, tier2, tier3
}

// get reward ratio by staking duration height
func getRewardRatio(height int64) uint64 {
	switch {
	case height >= warmUp[100]:
		return 100
	case height >= warmUp[70]:
		return 70
	case height >= warmUp[50]:
		return 50
	case height >= warmUp[30]:
		return 30
	default:
		return 0
	}
}

func getTierRatio(tier uint64) uint64 {
	if tier < 1 || tier > 3 {
		panic(ufmt.Sprintf("[STAKER] reward_math.gno__getTierRatio() || tier(%d) must be 1 ~ 3", tier))
	}

	ratio1, ratio2, ratio3 := listTierRatio()
	switch tier {
	case 1:
		return ratio1 // default 50
	case 2:
		return ratio2 // default 30
	case 3:
		return ratio3 // default 20
	default:
		panic("[STAKER] reward_math.gno__getTierRatio() || invalid ratio")
	}
}

// return all ratio for each tier
func listTierRatio() (uint64, uint64, uint64) {
	// basic
	// tier1 50%
	// tier2 30%
	// tier3 20%

	// since `float` type has determinisim issue, we use `int` instead
	// so instead of return 50%, we return 50
	// we'll divide by 100 later

	numTier1, numTier2, numTier3 := getNumPoolTiers()
	if numTier1 <= 0 {
		panic(ufmt.Sprintf("[STAKER] reward_math.gno__listTierRatio() || at least 1 numTier1 need(%d), [numTier2:(%d), numTier3:(%d)]", numTier1, numTier2, numTier3))
	}

	if numTier2 == 0 && numTier3 == 0 { // only tier 1 exists
		return 100, 0, 0
	} else if numTier2 == 0 && numTier3 >= 1 { // tier 1 and 3 exists ( tier2 ratio goes to tier1 )
		return 80, 0, 20
	} else if numTier2 >= 1 && numTier3 == 0 { // tier 1 and 2 exists ( tier3 ratio goes to tier1 )
		return 70, 30, 0
	} else if numTier2 >= 1 && numTier3 >= 1 { // all tiers exists
		return 50, 30, 20
	}

	panic("[STAKER] reward_math.gno__listTierRatio() || invalid tier ratio")
}

func getTiersAmount(amount uint64) (uint64, uint64, uint64) {
	tier1Ratio, tier2Ratio, tier3Ratio := listTierRatio()

	tier1Amount := (amount * tier1Ratio) / 100
	tier2Amount := (amount * tier2Ratio) / 100
	tier3Amount := (amount * tier3Ratio) / 100

	return tier1Amount, tier2Amount, tier3Amount
}

func calcAmount(avgBlockAmountX96 *u256.Uint, dur, pct uint64) (uint64, uint64) {
	durAmountX96 := new(u256.Uint).Mul(avgBlockAmountX96, u256.NewUint(dur))
	fullAmount := new(u256.Uint).Div(durAmountX96, u256.MustFromDecimal(consts.Q96)).Uint64()

	durAmountX96 = new(u256.Uint).Mul(durAmountX96, u256.NewUint(pct))
	durAmountX96 = new(u256.Uint).Div(durAmountX96, u256.NewUint(100))

	durAmount := new(u256.Uint).Div(durAmountX96, u256.MustFromDecimal(consts.Q96)).Uint64()
	return fullAmount, durAmount
}
