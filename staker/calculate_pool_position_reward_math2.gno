package staker

import (
	"std"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v2/consts"
)

const (
	RATIO_30  = 30
	RATIO_50  = 50
	RATIO_70  = 70
	RATIO_100 = 100
)

// rewardMathComputeExternalRewardAmount2 calculates the total and payble rewards for a given
// tokenId and incentiveID.
func rewardMathComputeExternalRewardAmount2(tokenId uint64, ictvId string) (uint64, uint64) {
	currentHeight := std.GetHeight()
	_currentHeightU64 := uint64(currentHeight)

	// retrieve the external rewards associated with
	// the given token ID.
	externals, exists := validateAndGetExternals(tokenId)
	if !exists {
		return 0, 0
	}

	// calculate the start info of staking based on the latest timestamp
	// TODO: must use block height instead of timestamp
	stakedStartInfo := calculateStakedStartInfo(tokenId, ictvId, currentHeight)
	// determine the thresholds for different reward ratios.
	thresholds := calculateThresholds(stakedStartInfo.startHeight)

	external, found := findExternalByIctvId(externals, ictvId)
	if !found {
		panic("NO INCENTIVE_ID FOUND")
	}

	return calculateRewardsForExternal(
		tokenId,
		ictvId,
		external,
		_currentHeightU64,
		stakedStartInfo,
		thresholds,
	)
}

type stakedStartInfo struct {
	startHeight int64
	duration    int64
}

type thresholds struct {
	until30  uint64
	until50  uint64
	until70  uint64
	begin100 uint64
}

func validateAndGetExternals(tokenId uint64) (map[string]externalRewards, bool) {
	externals, exist := positionExternal[tokenId]
	return externals, exist
}

func calculateStakedStartInfo(tokenId uint64, incentiveId string, currentHeight int64) stakedStartInfo {
	// TODO: use block height
	_max := max(incentives[incentiveId].startTimestamp, deposits[tokenId].stakeTimestamp)
	stakedOrExternalDuration := (time.Now().Unix() - _max) / consts.BLOCK_GENERATION_INTERVAL
	stakedOrExternalStartedHeight := currentHeight - stakedOrExternalDuration

	return stakedStartInfo{
		startHeight: stakedOrExternalStartedHeight,
		duration:    stakedOrExternalDuration,
	}
}

// calculateThresholds determines the block height thresholds for different reward ratios.
func calculateThresholds(startHeight int64) thresholds {
	baseHeight := uint64(startHeight)
	return thresholds{
		until30:  baseHeight + uint64(warmUp[RATIO_50]) - 1,
		until50:  baseHeight + uint64(warmUp[RATIO_70]) - 1,
		until70:  baseHeight + uint64(warmUp[RATIO_100]) - 1,
		begin100: baseHeight + uint64(warmUp[RATIO_100]),
	}
}

// findExternalByIctvId retrieves the external reward matching the given incentive ID.
func findExternalByIctvId(externals map[string]externalRewards, ictvId string) (externalRewards, bool) {
	external, exists := externals[ictvId]
	return external, exists
}

// calculateRewardsForExternal computes the total and payable rewards for the external incentive.
func calculateRewardsForExternal(
	tokenId uint64,
	incentiveId string,
	external externalRewards,
	currentHeight uint64,
	startInfo stakedStartInfo,
	thresholds thresholds,
) (uint64, uint64) {
	// retrieve the last recoreded external reward amount
	tokenAmountX96 := external.tokenAmountX96
	lastExternalAmount := positionLastExternal[tokenId][incentiveId]
	if tokenAmountX96.Lt(lastExternalAmount) {
		panic("THIS SHOULD NOT HAPPEN_EXTERNAL #1")
	}

	// calculate the new amount to distribute since the last calculation.
	toDistributeX96 := new(u256.Uint).Sub(tokenAmountX96, lastExternalAmount)
	// get the last calculated block height for the external rewards.
	lastCalculatedHeight := uint64(positionsExternalLastCalculatedHeight[tokenId][incentiveId])

	// calculate the duration in blocks since the last calculation.
	blockDuration := currentHeight - lastCalculatedHeight
	if blockDuration == 0 {
		return 0, 0
	}

	avgExternalBlockAmountX96 := new(u256.Uint).Div(toDistributeX96, u256.NewUint(blockDuration))

	// retrieve the warm-up amounts; if not present, panic as it's an unexpected state.
	positionExternalWarmUpAmount, exist := positionsExternalWarmUpAmount[tokenId][incentiveId]
	if !exist {
		panic("THIS SHOULD NOT HAPPEN_EXTERNAL #2")
	}

	// determine the reward ratio based on the staking duration.
	// after that, compute the rewards according to the determined ratio.
	durationRatio := getRewardRatio(startInfo.duration)
	warmUpAmount := computeRewardsByRatio(
		uint64(durationRatio),
		currentHeight,
		lastCalculatedHeight,
		thresholds,
		avgExternalBlockAmountX96,
		positionExternalWarmUpAmount,
	)

	accFull := warmUpAmount.totalFull()
	accGive := warmUpAmount.totalGive()

	// update the warm-up amounr in the global state.
	// WARNING: TOO MANY SIDE EFFECTS. NEED TO FIND A BETTER WAY.
	positionsExternalWarmUpAmount[tokenId][incentiveId] = warmUpAmount

	return accFull, accGive
}

// computeRewardsByRatio calculates the rewards based in the reward ratio.
func computeRewardsByRatio(
	durationRatio uint64,
	currentHeight uint64,
	lastCalculatedHeight uint64,
	thresholds thresholds,
	avgBlockAmountX96 *u256.Uint,
	warmUpAmount warmUpAmount,
) warmUpAmount {
	switch durationRatio {
	case RATIO_100:
		// include all prev ratios.
		return computeRewardsForRatio(
			[]uint64{RATIO_30, RATIO_50, RATIO_70, RATIO_100},
			currentHeight,
			lastCalculatedHeight,
			thresholds,
			avgBlockAmountX96,
			warmUpAmount,
		)
	case RATIO_70:
		// include up to 70% ratio.
		return computeRewardsForRatio(
			[]uint64{RATIO_30, RATIO_50, RATIO_70},
			currentHeight,
			lastCalculatedHeight,
			thresholds,
			avgBlockAmountX96,
			warmUpAmount,
		)
	case RATIO_50:
		// include up to 50% ratio.
		return computeRewardsForRatio(
			[]uint64{RATIO_30, RATIO_50},
			currentHeight,
			lastCalculatedHeight,
			thresholds,
			avgBlockAmountX96,
			warmUpAmount,
		)
	case RATIO_30:
		// only calculate for 30% ratio.
		return computeRewardsForRatio(
			[]uint64{RATIO_30},
			currentHeight,
			lastCalculatedHeight,
			thresholds,
			avgBlockAmountX96,
			warmUpAmount,
		)
	default:
		// unrecognized. no need to update warm-up amount.
		return warmUpAmount
	}
}

// computeRewardForRatio calculates rewards for the given ratios.
func computeRewardsForRatio(
	ratios []uint64,
	currentHeight uint64,
	lastCalculatedHeight uint64,
	thresholds thresholds,
	avgBlockAmountX96 *u256.Uint,
	warmUpAmount warmUpAmount,
) warmUpAmount {
	durations := calculateDurations(ratios, currentHeight, lastCalculatedHeight, thresholds)

	for _, item := range durations.iter(ratios) {
		if item.duration > 0 {
			full, toGive := calcAmount(avgBlockAmountX96, item.duration, item.ratio)
			warmUpAmount.add(item.ratio, full, toGive)
		}
	}
	return warmUpAmount
}

// calculateDurations computes the duration for each reward ratio based on thresholds.
func calculateDurations(
	ratios []uint64,
	currentHeight uint64,
	lastCalculatedHeight uint64,
	thresholds thresholds,
) durationsMap {
	durations := make(durationsMap)
	heights := map[uint64]uint64{
		RATIO_30:  thresholds.until30,
		RATIO_50:  thresholds.until50,
		RATIO_70:  thresholds.until70,
		RATIO_100: thresholds.begin100,
	}

	prevHeight := lastCalculatedHeight
	for _, ratio := range ratios {
		var nextHeight uint64
		if ratio == RATIO_100 {
			nextHeight = currentHeight
		} else {
			nextHeight = min(heights[ratio], currentHeight)
		}
		duration := maxUint64(0, nextHeight-prevHeight)
		durations[ratio] = duration
		prevHeight = nextHeight
	}
	return durations
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

func (w warmUpAmount) totalFull() uint64 {
	return w.full30 + w.full50 + w.full70 + w.full100
}

func (w warmUpAmount) totalGive() uint64 {
	return w.give30 + w.give50 + w.give70 + w.full100
}

type durationsMap map[uint64]uint64

// iter returns a slice of key-value pairs sorted by the order of ratios provided.
func (d durationsMap) iter(ratios []uint64) []struct {
	ratio    uint64
	duration uint64
} {
	var result []struct {
		ratio    uint64
		duration uint64
	}
	for _, ratio := range ratios {
		duration, exists := d[ratio]
		if exists {
			result = append(result, struct {
				ratio    uint64
				duration uint64
			}{
				ratio:    ratio,
				duration: duration,
			})
		}
	}
	return result
}

func maxUint64(a, b uint64) uint64 {
	if a > b {
		return a
	}
	return b
}
