package staker

import (
	"std"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v2/consts"
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
	_currentHeightU64 := uint64(currentHeight)
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

	toDistributeX96 := new(u256.Uint).Mul(u256.NewUint(toDistribute), _q96)
	avgGnsBlockAmountX96 := new(u256.Uint).Div(toDistributeX96, u256.NewUint(_currentHeightU64-lastCalculatedHeightU64))
	println(" > REWARD__INTERNAL_toDistribute:", toDistribute)
	println(" > REWARD__INTERNAL__currentHeightU64-lastCalculatedHeightU64):", _currentHeightU64-lastCalculatedHeightU64)
	println(" > REWARD__INTERNAL_avgGnsBlockAmountX96:", avgGnsBlockAmountX96.ToString())

	positionWarmUpAmount, exist := positionsInternalWarmUpAmount[tokenId]
	if !exist {
		panic("THIS SHOULD NOT HAPPEN")
	}
	println(" > REWARD__INTERNAL_BEFORE_positionWarmUpAmount.full100", positionWarmUpAmount.full100)
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
			dur100 := _currentHeightU64 - lastCalculatedHeightU64
			println("  > REWARD__INTERNAL_DUR100", dur100)
			full, _ := calcAmount(avgGnsBlockAmountX96, dur100, 100)
			// println("  > REWARD__INTERNAL_AMOUNT100", amount)
			positionWarmUpAmount.full100 += full
			// gnsAmountToGive += amount // UPDATE EACH PERIOD
			// println("  > REWARD__INTERNAL_100%", gnsAmountToGive)
		} else {
			if lastCalculatedHeightU64 > until50 {
				println(" > REWARD__INTERNAL_REWARD 100% AND 70%")
				// 100%
				dur100 := _currentHeightU64 - until70
				println("  > REWARD__INTERNAL_DUR100", dur100)
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
				positionWarmUpAmount.full100 += full
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
				dur100 := _currentHeightU64 - until70
				println("  > REWARD__INTERNAL_DUR100", dur100)
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
				positionWarmUpAmount.full100 += full
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
				dur100 := _currentHeightU64 - until70
				println("  > REWARD__INTERNAL_DUR100", dur100)
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
				positionWarmUpAmount.full100 += full
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
			dur70 := _currentHeightU64 - lastCalculatedHeightU64
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
				dur70 := _currentHeightU64 - until50
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
				dur70 := _currentHeightU64 - until50
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
			dur50 := _currentHeightU64 - lastCalculatedHeightU64
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
			dur50 := _currentHeightU64 - until30
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
		dur30 := _currentHeightU64 - lastCalculatedHeightU64
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

	accuFull := uint64(0)
	accuGive := uint64(0)

	accuFull += positionWarmUpAmount.full30 + positionWarmUpAmount.full50 + positionWarmUpAmount.full70 + positionWarmUpAmount.full100
	accuGive += positionWarmUpAmount.give30 + positionWarmUpAmount.give50 + positionWarmUpAmount.give70 + positionWarmUpAmount.full100

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
	_currentHeightU64 := uint64(currentHeight)

	externals, exist := positionExternal[tokenId]
	if !exist {
		return 0, 0
	}

	_max := max(incentives[incentiveId].startTimestamp, deposits[tokenId].stakeTimestamp)
	println("  > REWARD__EXTERNAL_incentives[incentiveId].startTimestamp:", incentives[incentiveId].startTimestamp)
	println("  > REWARD__EXTERNAL_deposits[tokenId].stakeTimestamp:", deposits[tokenId].stakeTimestamp)
	println("  > REWARD__EXTERNAL_max:", _max)

	stakedOrExternalDuration := (time.Now().Unix() - _max) / consts.BLOCK_GENERATION_INTERVAL
	println("  > REWARD__EXTERNAL_time.Now().Unix():", time.Now().Unix())
	println("  > REWARD__EXTERNAL_consts.BLOCK_GENERATION_INTERVAL:", consts.BLOCK_GENERATION_INTERVAL)
	println("  > REWARD__EXTERNAL_stakedOrExternalDuration:", stakedOrExternalDuration)

	stakedOrExternalStartedHeight := currentHeight - stakedOrExternalDuration
	println("  > REWARD__EXTERNAL_height:", currentHeight)
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

			avgExternalBlockAmountX96 := new(u256.Uint).Div(toDistributeX96, u256.NewUint(_currentHeightU64-lastCalculatedHeightU64))
			println("   > REWARD__EXTERNAL_toDistirbuteX96:", toDistributeX96.ToString())
			println("   > REWARD__EXTERNAL__currentHeightU64-lastCalculatedHeightU64):", _currentHeightU64-lastCalculatedHeightU64)
			println("   > REWARD__EXTERNAL_avgExternalBlockAmountX96:", avgExternalBlockAmountX96.ToString())

			positionExternalWarmUpAmount, exist := positionsExternalWarmUpAmount[tokenId][incentiveId]
			if !exist {
				println("tokenId:", tokenId)
				println("incentiveId:", incentiveId)
				panic("THIS SHOULD NOT HAPPEN_EXTERNAL #2")
			}

			println("   > REWARD__EXTERNAL_BEFORE_positionExternalWarmUpAmount.full100", positionExternalWarmUpAmount.full100)
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
					dur100 := _currentHeightU64 - lastCalculatedHeightU64
					println("  > REWARD__EXTERNAL_DUR100", dur100)
					full, _ := calcAmount(avgExternalBlockAmountX96, dur100, 100)
					positionExternalWarmUpAmount.full100 += full
					// gnsAmountToGive += amount // UPDATE EACH PERIOD
				} else {
					if lastCalculatedHeightU64 > until50 {
						println(" > REWARD__EXTERNAL_REWARD 100% AND 70%")
						// 100%
						dur100 := _currentHeightU64 - until70
						println("  > REWARD__EXTERNAL_DUR100", dur100)
						full, toGive := calcAmount(avgExternalBlockAmountX96, dur100, 100)
						positionExternalWarmUpAmount.full100 += full
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
						dur100 := _currentHeightU64 - until70
						println("  > REWARD__EXTERNAL_DUR100", dur100)
						full, toGive := calcAmount(avgExternalBlockAmountX96, dur100, 100)
						positionExternalWarmUpAmount.full100 += full
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
						dur100 := _currentHeightU64 - until70
						println("  > REWARD__EXTERNAL_DUR100", dur100)
						full, toGive := calcAmount(avgExternalBlockAmountX96, dur100, 100)
						positionExternalWarmUpAmount.full100 += full
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
					dur70 := _currentHeightU64 - lastCalculatedHeightU64
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
						dur70 := _currentHeightU64 - until50
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
						dur70 := _currentHeightU64 - until50
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
					dur50 := _currentHeightU64 - lastCalculatedHeightU64
					println("  > REWARD__EXTERNAL_DUR50", dur50)
					full, toGive := calcAmount(avgExternalBlockAmountX96, dur50, 50)
					positionExternalWarmUpAmount.full50 += full
					positionExternalWarmUpAmount.give50 += toGive
					positionExternalWarmUpAmount.left50 += full - toGive
					// gnsAmountToGive += amount // UPDATE EACH PERIOD
				} else {
					println(" > REWARD__EXTERNAL_REWAD 50% AND 30%")
					dur50 := _currentHeightU64 - until30
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
				dur30 := _currentHeightU64 - lastCalculatedHeightU64
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

			accuFull := uint64(0)
			accuGive := uint64(0)

			accuFull += positionExternalWarmUpAmount.full30 + positionExternalWarmUpAmount.full50 + positionExternalWarmUpAmount.full70 + positionExternalWarmUpAmount.full100
			accuGive += positionExternalWarmUpAmount.give30 + positionExternalWarmUpAmount.give50 + positionExternalWarmUpAmount.give70 + positionExternalWarmUpAmount.full100

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
