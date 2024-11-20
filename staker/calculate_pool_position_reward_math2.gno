package staker

import (
	"std"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/p/demo/ufmt"
)

// TODO: remove duplicate constants
const (
	RATIO_30  = 30
	RATIO_50  = 50
	RATIO_70  = 70
	RATIO_100 = 100
)

// RewardState encapsulates all necessary data for reward calculations.
// This structure is designed to reduce global state dependencies and
// make the data flow more explicit. It contains all contextual information
// needed to calculate rewards, allowing for more pure function implementations
// and easier testing.
type RewardState struct {
	TokenId              uint64
	CurrentHeight        uint64
	LastCalculatedHeight uint64
	IncentiveId          string
	TokenAmountX96       *u256.Uint
	LastExternalAmount   *u256.Uint
	WarmUpAmount         warmUpAmount
	ThresholdInfo        thresholds
	StartInfo            stakedStartInfo
}

type stakedStartInfo struct {
	startHeight int64
	duration    int64
}

type thresholds struct {
	startHeight uint64
	until30     uint64
	until50     uint64
	until70     uint64
	begin100    uint64
}

// RewardCalculation represents the intermediate results during the reward calculation process.
//
// It holds both the initial state and intermediate results to avoid global state mutations.
type RewardCalculation struct {
	BlockDuration    uint64
	DurationRatio    uint64
	DistributeAmount *u256.Uint
	AvgBlockAmount   *u256.Uint
	State            RewardState
	WarmUpResult     warmUpAmount
}

// rewardMathComputeExternalRewardAmount2 is the main entry point for reward calculations.
// It follows a three-step process:
//
//  1. Initialize the reward state with all necessary data
//  2. Perform the reward calculations through a pipeline of pure functions
//  3. Update the global state with the results
//
// Returns (totalFull, totalGive) representing the total and distributable rewards.
func rewardMathComputeExternalRewardAmount2(tokenId uint64, ictvId string) (uint64, uint64) {
	state, err := initializeRewardState(tokenId, ictvId)
	if err != nil {
		panic(err)
	}

	result := calculateRewards(state)
	updatePositionWarmUpAmount(result)

	positionsExternalLastCalculatedHeight[tokenId][ictvId] = int64(state.CurrentHeight)

	return result.WarmUpResult.totalFull(), result.WarmUpResult.totalGive()
}

// initializeRewardState gathers all necessary data to perform reward calculations.
// This function is separated from the main calculation logic to:
//
//  1. Ensure all required data is available before starting calculations
//  2. Handle initialization errors explicitly
//  3. Reduce complexity in the calculation functions
//
// Returns an error if required data is missing or invalid.
func initializeRewardState(tokenId uint64, ictvId string) (RewardState, error) {
	externals, exists := validateAndGetExternals(tokenId)
	if !exists {
		return RewardState{}, ufmt.Errorf("no externals found for token %d", tokenId)
	}

	external, found := findExternalByIctvId(externals, ictvId)
	if !found {
		return RewardState{}, ufmt.Errorf("no incentive found for ID %s", ictvId)
	}

	// initialize all required state in one place to ensure consistency
	currentHeight := std.GetHeight()
	startInfo := calculateStakedStartInfo(tokenId, ictvId, currentHeight)
	thresholds := calculateThresholds(startInfo.startHeight)

	return RewardState{
		TokenId:              tokenId,
		IncentiveId:          ictvId,
		CurrentHeight:        uint64(currentHeight),
		LastCalculatedHeight: uint64(positionsExternalLastCalculatedHeight[tokenId][ictvId]),
		TokenAmountX96:       external.tokenAmountX96,
		LastExternalAmount:   positionLastExternal[tokenId][ictvId],
		WarmUpAmount:         positionsExternalWarmUpAmount[tokenId][ictvId],
		ThresholdInfo:        thresholds,
		StartInfo:            startInfo,
	}, nil
}

func validateAndGetExternals(tokenId uint64) (map[string]externalRewards, bool) {
	externals, exist := positionExternal[tokenId]
	return externals, exist
}

func findExternalByIctvId(externals map[string]externalRewards, ictvId string) (externalRewards, bool) {
	external, exists := externals[ictvId]
	return external, exists
}

func calculateStakedStartInfo(tokenId uint64, incentiveId string, currentHeight int64) stakedStartInfo {
	_max := max(incentives[incentiveId].startTimestamp, deposits[tokenId].stakeTimestamp)
	stakedOrExternalDuration := (time.Now().Unix() - _max) / consts.BLOCK_GENERATION_INTERVAL
	stakedOrExternalStartedHeight := currentHeight - stakedOrExternalDuration

	return stakedStartInfo{
		startHeight: stakedOrExternalStartedHeight,
		duration:    stakedOrExternalDuration,
	}
}

func calculateThresholds(startHeight int64) thresholds {
	baseHeight := uint64(startHeight)
	return thresholds{
		startHeight: baseHeight,
		until30:     baseHeight + uint64(warmUp[RATIO_50]) - 1,
		until50:     baseHeight + uint64(warmUp[RATIO_70]) - 1,
		until70:     baseHeight + uint64(warmUp[RATIO_100]) - 1,
		begin100:    baseHeight + uint64(warmUp[RATIO_100]),
	}
}

func calculateRewards(state RewardState) RewardCalculation {
	return validateTokenAmount(state).
		calculateDistribution().
		calculateBlockDuration().
		calculateAverageAmount().
		calculateWarmUpAmount()
}

func validateTokenAmount(state RewardState) RewardCalculation {
	if state.TokenAmountX96.Lt(state.LastExternalAmount) {
		panic("THIS SHOULD NOT HAPPEN_EXTERNAL #1")
	}
	return RewardCalculation{State: state}
}

func (calc RewardCalculation) calculateDistribution() RewardCalculation {
	calc.DistributeAmount = new(u256.Uint).Sub(
		calc.State.TokenAmountX96,
		calc.State.LastExternalAmount,
	)
	return calc
}

func (calc RewardCalculation) calculateBlockDuration() RewardCalculation {
	calc.BlockDuration = calc.State.CurrentHeight - calc.State.LastCalculatedHeight
	return calc
}

func (calc RewardCalculation) calculateAverageAmount() RewardCalculation {
	if calc.BlockDuration == 0 {
		return calc
	}

	calc.AvgBlockAmount = new(u256.Uint).Div(
		calc.DistributeAmount,
		u256.NewUint(calc.BlockDuration),
	)
	return calc
}

// calculateWarmUpAmount determines the final warm-up amounts based on various ratios.
func (calc RewardCalculation) calculateWarmUpAmount() RewardCalculation {
	if calc.BlockDuration == 0 {
		return calc
	}

	if _, exist := positionsExternalWarmUpAmount[calc.State.TokenId][calc.State.IncentiveId]; !exist {
		panic("THIS SHOULD NOT HAPPEN_EXTERNAL #2")
	}

	calc.DurationRatio = uint64(getRewardRatio(calc.State.StartInfo.duration))
	calc.WarmUpResult = computeRewardsByRatio(
		calc.DurationRatio,
		calc.State.CurrentHeight,
		calc.State.LastCalculatedHeight,
		calc.State.ThresholdInfo,
		calc.AvgBlockAmount,
		calc.State.WarmUpAmount,
	)
	return calc
}

// computeRewardsByRatio calculates rewards based on different ratio thresholds.
// The implementation uses a multi-step approach:
//
//  1. Determine applicable reward ratios based on staking duration
//  2. Calculate durations for each ratio period
//  3. Compute rewards for each period
func computeRewardsByRatio(
	durationRatio uint64,
	currentHeight uint64,
	lastCalculatedHeight uint64,
	thresholds thresholds,
	avgBlockAmountX96 *u256.Uint,
	warmUpAmount warmUpAmount,
) warmUpAmount {
	ratios, count := getRatiosForDuration(durationRatio)
	durations := calculateRewardDurations(ratios, currentHeight, lastCalculatedHeight, thresholds)

	for i := uint8(0); i < count; i++ {
		ratio := ratios[i]
		if duration, exists := durations[ratio]; exists && duration > 0 {
			full, toGive := calcAmount(avgBlockAmountX96, duration, ratio)
			warmUpAmount.add(ratio, full, toGive)
		}
	}

	return warmUpAmount
}

// getRatiosForDuration returns fixed-size array of ratios and its length
func getRatiosForDuration(ratio uint64) ([4]uint64, uint8) {
	switch ratio {
	case RATIO_100:
		return [4]uint64{RATIO_30, RATIO_50, RATIO_70, RATIO_100}, 4
	case RATIO_70:
		return [4]uint64{RATIO_30, RATIO_50, RATIO_70, 0}, 3
	case RATIO_50:
		return [4]uint64{RATIO_30, RATIO_50, 0, 0}, 2
	case RATIO_30:
		return [4]uint64{RATIO_30, 0, 0, 0}, 1
	default:
		return [4]uint64{}, 0
	}
}

type durationsMap map[uint64]uint64

// calculateRewardDurations computes the duration for each reward ratio period.
func calculateRewardDurations(
	ratios [4]uint64,
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

func maxUint64(a, b uint64) uint64 {
	if a > b {
		return a
	}
	return b
}
