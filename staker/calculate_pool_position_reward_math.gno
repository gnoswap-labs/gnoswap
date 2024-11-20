package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/consts"
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

// add updates the warmUpAmount with the calculated full and toGive amounts for a specific ratio.
func (w *warmUpAmount) add(ratio, full, toGive uint64) {
	switch ratio {
	case RATIO_30:
		w.full30 += full
		w.give30 += toGive
		w.left30 += full - toGive
	case RATIO_50:
		w.full50 += full
		w.give50 += toGive
		w.left50 += full - toGive
	case RATIO_70:
		w.full70 += full
		w.give70 += toGive
		w.left70 += full - toGive
	case RATIO_100:
		w.full100 += full
	}
}

func (w *warmUpAmount) totalFull() uint64 {
	return w.full30 + w.full50 + w.full70 + w.full100
}

func (w *warmUpAmount) totalGive() uint64 {
	return w.give30 + w.give50 + w.give70 + w.full100
}

func updatePositionWarmUpAmount(calc RewardCalculation) {
	positionsExternalWarmUpAmount[calc.State.TokenId][calc.State.IncentiveId] = calc.WarmUpResult
}

var positionsInternalWarmUpAmount = make(map[uint64]warmUpAmount)             // positionId => warmUpAmount
var positionsExternalWarmUpAmount = make(map[uint64]map[string]warmUpAmount)  // positionId => incentiveId => warmUpAmount
var positionsExternalLastCalculatedHeight = make(map[uint64]map[string]int64) // positionId => incentiveId => lastCalculatedHeight

// computeInternalWarmUpRewardAmount calculate reward amount for warm-up period
//
// input:
//   - startHeight: startHeight is the height at which warm-up rewards can be paid.
//   - rewardAmount: reward amount
//
// output:
//   - rewardAmountByWarmUp : reward amount by warm-up period
//   - penalty: penalty amount by warm-up period
func computeInternalWarmUpRewardAmount(currentHeight int64, startHeight int64, rewardAmount uint64) (uint64, uint64) {
	var rewardAmountByWarmUp uint64 = 0
	var penaltyAmountByWarmUp uint64 = 0

	// 1. calculate warm-up period by startHeight and currentHeight
	// startHeight = stakedHeight + warmUp[WarmUpFor30Ratio]
	if currentHeight < startHeight {
		// TODO:
		// After test, should be removed the log
		println("currentHeight should be greater than stakedHeight")
		return rewardAmountByWarmUp, penaltyAmountByWarmUp
	}
	// 2. Get the last calculated height
	prevCalculatedHeight := getLastCalculatedHeight()

	// 3. Calculate the reward amount by warm-up period
	warmupCalculator := NewWarmUpCalculator(startHeight, prevCalculatedHeight)
	rewardAmountByWarmUp, penaltyAmountByWarmUp = warmupCalculator.CalculateWarmUp(currentHeight, rewardAmount)

	return rewardAmountByWarmUp, penaltyAmountByWarmUp
}

func computeExternalWarmUpRewardAmount() (uint64, uint64) {
	return 0, 0
}

func computeRewardByRatio(amount uint64, ratioX96 *u256.Uint) uint64 {
	rewardAmountX96 := u256.Zero().Mul(u256.NewUint(amount), ratioX96)
	rewardAmountX := u256.Zero().Div(rewardAmountX96, _q96)
	rewardAmount := rewardAmountX.Uint64()

	return rewardAmount
}

func rewardMathComputeInternalRewardAmount(tokenId uint64) (uint64, uint64) {
	deposit := deposits[tokenId]

	// using block
	stakeHeight := deposit.stakeHeight
	currentHeight := std.GetHeight()
	_currentHeightU64 := uint64(currentHeight)
	stakedDuration := currentHeight - stakeHeight
	durationRatio := getRewardRatio(stakedDuration)

	// Distribute the accumulated rewards from the last calculation point to the current block according to each weight
	toDistribute := positionGns[tokenId] - positionLastGns[tokenId]

	until30 := uint64(stakeHeight + warmUp[50] - 1)  // 150
	until50 := uint64(stakeHeight + warmUp[70] - 1)  // 300
	until70 := uint64(stakeHeight + warmUp[100] - 1) // 900
	begin100 := uint64(stakeHeight + warmUp[100])    // 901~

	lastCalculatedHeightU64 := uint64(lastCalculatedHeight)

	toDistributeX96 := new(u256.Uint).Mul(u256.NewUint(toDistribute), _q96)
	avgGnsBlockAmountX96 := new(u256.Uint).Div(toDistributeX96, u256.NewUint(_currentHeightU64-lastCalculatedHeightU64))

	positionWarmUpAmount, exist := positionsInternalWarmUpAmount[tokenId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("calculate_pol_position_reward_math.gno__rewardMathComputeInternalRewardAmount() || positionsInternalWarmUpAmount[tokenId](%d) not found", tokenId),
		))
	}

	switch durationRatio {
	case 100:
		if lastCalculatedHeightU64 > begin100 {
			// 100%
			dur100 := _currentHeightU64 - lastCalculatedHeightU64
			full, _ := calcAmount(avgGnsBlockAmountX96, dur100, 100)
			positionWarmUpAmount.full100 += full
		} else {
			if lastCalculatedHeightU64 > until50 {
				// 100%
				dur100 := _currentHeightU64 - until70
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
				positionWarmUpAmount.full100 += full

				// 70%
				dur70 := until70 - lastCalculatedHeightU64
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive
			} else if lastCalculatedHeightU64 > until30 {
				// 100%
				dur100 := _currentHeightU64 - until70
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
				positionWarmUpAmount.full100 += full

				// 70%
				dur70 := until70 - until50
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive

				// 50%
				dur50 := until50 - lastCalculatedHeightU64
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur50, 50)
				positionWarmUpAmount.full50 += full
				positionWarmUpAmount.give50 += toGive
				positionWarmUpAmount.left50 += full - toGive
			} else {
				// 100%
				dur100 := _currentHeightU64 - until70
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
				positionWarmUpAmount.full100 += full

				// 70%
				dur70 := until70 - until50
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive

				// 50%
				dur50 := until50 - until30
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur50, 50)
				positionWarmUpAmount.full50 += full
				positionWarmUpAmount.give50 += toGive
				positionWarmUpAmount.left50 += full - toGive

				// 30%
				dur30 := until30 - lastCalculatedHeightU64
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur30, 30)
				positionWarmUpAmount.full30 += full
				positionWarmUpAmount.give30 += toGive
				positionWarmUpAmount.left30 += full - toGive
			}
		}

	case 70:
		if lastCalculatedHeightU64 > until50 {
			// 70%
			dur70 := _currentHeightU64 - lastCalculatedHeightU64
			full, toGive := calcAmount(avgGnsBlockAmountX96, dur70, 70)
			positionWarmUpAmount.full70 += full
			positionWarmUpAmount.give70 += toGive
			positionWarmUpAmount.left70 += full - toGive
		} else {
			if lastCalculatedHeightU64 > until30 {
				// 70%
				dur70 := _currentHeightU64 - until50
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive

				// 50%
				dur50 := until50 - lastCalculatedHeightU64
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur50, 50)
				positionWarmUpAmount.full50 += full
				positionWarmUpAmount.give50 += toGive
				positionWarmUpAmount.left50 += full - toGive
			} else {
				// 70%
				dur70 := _currentHeightU64 - until50
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive

				// 50%
				dur50 := until50 - until30
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur50, 50)
				positionWarmUpAmount.full50 += full
				positionWarmUpAmount.give50 += toGive
				positionWarmUpAmount.left50 += full - toGive

				// 30%
				dur30 := until30 - lastCalculatedHeightU64
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur30, 30)
				positionWarmUpAmount.full30 += full
				positionWarmUpAmount.give30 += toGive
				positionWarmUpAmount.left30 += full - toGive
			}
		}

	case 50:
		if lastCalculatedHeightU64 > until30 {
			// 50%
			dur50 := _currentHeightU64 - lastCalculatedHeightU64
			full, toGive := calcAmount(avgGnsBlockAmountX96, dur50, 50)
			positionWarmUpAmount.full50 += full
			positionWarmUpAmount.give50 += toGive
			positionWarmUpAmount.left50 += full - toGive
		} else {
			dur50 := _currentHeightU64 - until30
			full, toGive := calcAmount(avgGnsBlockAmountX96, dur50, 50)
			positionWarmUpAmount.full50 += full
			positionWarmUpAmount.give50 += toGive
			positionWarmUpAmount.left50 += full - toGive

			// 30%
			dur30 := until30 - lastCalculatedHeightU64
			full, toGive = calcAmount(avgGnsBlockAmountX96, dur30, 30)
			positionWarmUpAmount.full30 += full
			positionWarmUpAmount.give30 += toGive
			positionWarmUpAmount.left30 += full - toGive
		}

	case 30:
		dur30 := _currentHeightU64 - lastCalculatedHeightU64
		full, toGive := calcAmount(avgGnsBlockAmountX96, dur30, 30)
		positionWarmUpAmount.full30 += full
		positionWarmUpAmount.give30 += toGive
		positionWarmUpAmount.left30 += full - toGive

	default:
	}

	accuFull := uint64(0)
	accuGive := uint64(0)

	accuFull += positionWarmUpAmount.full30 + positionWarmUpAmount.full50 + positionWarmUpAmount.full70 + positionWarmUpAmount.full100
	accuGive += positionWarmUpAmount.give30 + positionWarmUpAmount.give50 + positionWarmUpAmount.give70 + positionWarmUpAmount.full100

	positionsInternalWarmUpAmount[tokenId] = positionWarmUpAmount

	return accuFull, accuGive
}

func rewardMathComputeExternalRewardAmount(tokenId uint64, incentiveId string) (uint64, uint64) {
	currentHeight := std.GetHeight()
	_currentHeightU64 := uint64(currentHeight)

	externals, exist := positionExternal[tokenId]
	if !exist {
		return 0, 0
	}

	_max := max(incentives[incentiveId].startTimestamp, deposits[tokenId].stakeTimestamp)

	stakedOrExternalDuration := (time.Now().Unix() - _max) / consts.BLOCK_GENERATION_INTERVAL

	stakedOrExternalStartedHeight := currentHeight - stakedOrExternalDuration

	until30 := uint64(stakedOrExternalStartedHeight + warmUp[50] - 1)  // 150
	until50 := uint64(stakedOrExternalStartedHeight + warmUp[70] - 1)  // 300
	until70 := uint64(stakedOrExternalStartedHeight + warmUp[100] - 1) // 900
	begin100 := uint64(stakedOrExternalStartedHeight + warmUp[100])    // 901~

	// external := externals[incentiveId]
	for _, external := range externals {
		if external.incentiveId == incentiveId {

			tokenAmountX96 := external.tokenAmountX96
			toDistributeX96 := new(u256.Uint).Sub(tokenAmountX96, positionLastExternal[tokenId][incentiveId])
			if tokenAmountX96.Lt(positionLastExternal[tokenId][incentiveId]) {
				panic(addDetailToError(
					errDataNotFound,
					ufmt.Sprintf("calculate_pool_position_reward_math.gno__rewardMathComputeExternalRewardAmount() || tokenAmountX96(%s) < positionLastExternal[tokenId][incentiveId](%s)", tokenAmountX96.ToString(), positionLastExternal[tokenId][incentiveId].ToString()),
				))
			}

			lastCalculatedHeightU64 := uint64(positionsExternalLastCalculatedHeight[tokenId][incentiveId])

			avgExternalBlockAmountX96 := new(u256.Uint).Div(toDistributeX96, u256.NewUint(_currentHeightU64-lastCalculatedHeightU64))

			positionExternalWarmUpAmount, exist := positionsExternalWarmUpAmount[tokenId][incentiveId]
			if !exist {
				panic(addDetailToError(
					errDataNotFound,
					ufmt.Sprintf("calculate_pool_position_reward_math.gno__rewardMathComputeExternalRewardAmount() || positionExternalWarmUpAmount[tokenId][incentiveId](%d, %s) not found", tokenId, incentiveId),
				))
			}

			durationRatio := getRewardRatio(stakedOrExternalDuration)

			switch durationRatio {
			case 100:
				if lastCalculatedHeightU64 > begin100 {
					// 100%
					dur100 := _currentHeightU64 - lastCalculatedHeightU64
					full, _ := calcAmount(avgExternalBlockAmountX96, dur100, 100)
					positionExternalWarmUpAmount.full100 += full
				} else {
					if lastCalculatedHeightU64 > until50 {
						// 100%
						dur100 := _currentHeightU64 - until70
						full, toGive := calcAmount(avgExternalBlockAmountX96, dur100, 100)
						positionExternalWarmUpAmount.full100 += full

						// 70%
						dur70 := until70 - lastCalculatedHeightU64
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur70, 70)
						positionExternalWarmUpAmount.full70 += full
						positionExternalWarmUpAmount.give70 += toGive
						positionExternalWarmUpAmount.left70 += full - toGive
					} else if lastCalculatedHeightU64 > until30 {
						// 100%
						dur100 := _currentHeightU64 - until70
						full, toGive := calcAmount(avgExternalBlockAmountX96, dur100, 100)
						positionExternalWarmUpAmount.full100 += full

						// 70%
						dur70 := until70 - until50
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur70, 70)
						positionExternalWarmUpAmount.full70 += full
						positionExternalWarmUpAmount.give70 += toGive
						positionExternalWarmUpAmount.left70 += full - toGive

						// 50%
						dur50 := until50 - lastCalculatedHeightU64
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur50, 50)
						positionExternalWarmUpAmount.full50 += full
						positionExternalWarmUpAmount.give50 += toGive
						positionExternalWarmUpAmount.left50 += full - toGive
					} else {
						// 100%
						dur100 := _currentHeightU64 - until70
						full, toGive := calcAmount(avgExternalBlockAmountX96, dur100, 100)
						positionExternalWarmUpAmount.full100 += full

						// 70%
						dur70 := until70 - until50
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur70, 70)
						positionExternalWarmUpAmount.full70 += full
						positionExternalWarmUpAmount.give70 += toGive
						positionExternalWarmUpAmount.left70 += full - toGive

						// 50%
						dur50 := until50 - until30
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur50, 50)
						positionExternalWarmUpAmount.full50 += full
						positionExternalWarmUpAmount.give50 += toGive
						positionExternalWarmUpAmount.left50 += full - toGive

						// 30%
						dur30 := until30 - lastCalculatedHeightU64
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur30, 30)
						positionExternalWarmUpAmount.full30 += full
						positionExternalWarmUpAmount.give30 += toGive
						positionExternalWarmUpAmount.left30 += full - toGive
					}
				}

			case 70:
				if lastCalculatedHeightU64 > until50 {
					// 70%
					dur70 := _currentHeightU64 - lastCalculatedHeightU64
					full, toGive := calcAmount(avgExternalBlockAmountX96, dur70, 70)
					positionExternalWarmUpAmount.full70 += full
					positionExternalWarmUpAmount.give70 += toGive
					positionExternalWarmUpAmount.left70 += full - toGive
				} else {
					if lastCalculatedHeightU64 > until30 {
						// 70%
						dur70 := _currentHeightU64 - until50
						full, toGive := calcAmount(avgExternalBlockAmountX96, dur70, 70)
						positionExternalWarmUpAmount.full70 += full
						positionExternalWarmUpAmount.give70 += toGive
						positionExternalWarmUpAmount.left70 += full - toGive

						// 50%
						dur50 := until50 - lastCalculatedHeightU64
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur50, 50)
						positionExternalWarmUpAmount.full50 += full
						positionExternalWarmUpAmount.give50 += toGive
						positionExternalWarmUpAmount.left50 += full - toGive
					} else {
						// 70%
						dur70 := _currentHeightU64 - until50
						full, toGive := calcAmount(avgExternalBlockAmountX96, dur70, 70)
						positionExternalWarmUpAmount.full70 += full
						positionExternalWarmUpAmount.give70 += toGive
						positionExternalWarmUpAmount.left70 += full - toGive

						// 50%
						dur50 := until50 - until30
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur50, 50)
						positionExternalWarmUpAmount.full50 += full
						positionExternalWarmUpAmount.give50 += toGive
						positionExternalWarmUpAmount.left50 += full - toGive

						// 30%
						dur30 := until30 - lastCalculatedHeightU64
						full, toGive = calcAmount(avgExternalBlockAmountX96, dur30, 30)
						positionExternalWarmUpAmount.full30 += full
						positionExternalWarmUpAmount.give30 += toGive
						positionExternalWarmUpAmount.left30 += full - toGive
					}
				}

			case 50:
				if lastCalculatedHeightU64 > until30 {
					// 50%
					dur50 := _currentHeightU64 - lastCalculatedHeightU64
					full, toGive := calcAmount(avgExternalBlockAmountX96, dur50, 50)
					positionExternalWarmUpAmount.full50 += full
					positionExternalWarmUpAmount.give50 += toGive
					positionExternalWarmUpAmount.left50 += full - toGive
				} else {
					dur50 := _currentHeightU64 - until30
					full, toGive := calcAmount(avgExternalBlockAmountX96, dur50, 50)
					positionExternalWarmUpAmount.full50 += full
					positionExternalWarmUpAmount.give50 += toGive
					positionExternalWarmUpAmount.left50 += full - toGive

					// 30%
					dur30 := until30 - lastCalculatedHeightU64
					full, toGive = calcAmount(avgExternalBlockAmountX96, dur30, 30)
					positionExternalWarmUpAmount.full30 += full
					positionExternalWarmUpAmount.give30 += toGive
					positionExternalWarmUpAmount.left30 += full - toGive
				}

			case 30:
				dur30 := _currentHeightU64 - lastCalculatedHeightU64
				full, toGive := calcAmount(avgExternalBlockAmountX96, dur30, 30)
				positionExternalWarmUpAmount.full30 += full
				positionExternalWarmUpAmount.give30 += toGive
				positionExternalWarmUpAmount.left30 += full - toGive

			}

			accuFull := uint64(0)
			accuGive := uint64(0)

			accuFull += positionExternalWarmUpAmount.full30 + positionExternalWarmUpAmount.full50 + positionExternalWarmUpAmount.full70 + positionExternalWarmUpAmount.full100
			accuGive += positionExternalWarmUpAmount.give30 + positionExternalWarmUpAmount.give50 + positionExternalWarmUpAmount.give70 + positionExternalWarmUpAmount.full100

			positionsExternalWarmUpAmount[tokenId][incentiveId] = positionExternalWarmUpAmount

			return accuFull, accuGive
		}
	}

	panic(addDetailToError(
		errDataNotFound,
		"calculate_pool_position_reward_math.gno__rewardMathComputeExternalRewardAmount() || NO INCENTIVE_ID FOUND",
	))
}
