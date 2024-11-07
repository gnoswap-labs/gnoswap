package staker

import (
	"std"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	"gno.land/p/demo/ufmt"
)

// NOTE: warmUp is a map of percent to block number
// warmUp has a duration value. It applies different reward payout rates
// based on when the LP was staked by the staking position.
// warmUp has a threshold height value for rewards to be paid.
// For example,
// if the staked block height is 10, the 30% reward period
// for warmup starts at the staked block height + warmup[30].
var (
	warmUp           = make(map[int64]int64) // map[percent]block
	warmUpThresholds []int64                 // warmUpThresholds = warmUp[percent] - 1
)

const (
	WarmUpFor30Ratio  int64 = int64(30)
	WarmUpFor50Ratio  int64 = int64(50)
	WarmUpFor70Ratio  int64 = int64(70)
	WarmUpFor100Ratio int64 = int64(100)

	NumOfWarmUpSection      uint8 = 5
	IndexOfWarmUpSection0   uint8 = 0 // Section 0 is no reward duration
	IndexOfWarmUpSection30  uint8 = 1 // Section 30 is 30% reward duration
	IndexOfWarmUpSection50  uint8 = 2 // Section 50 is 50% reward duration
	IndexOfWarmUpSection70  uint8 = 3 // Section 70 is 70% reward duration
	IndexOfWarmUpSection100 uint8 = 4 // Section 100 is 100% reward duration

	DefaultRewardPayoutStartBlock30  int64 = 1   // ~ 5m
	DefaultRewardPayoutStartBlock50  int64 = 151 // 5m ~ 10m
	DefaultRewardPayoutStartBlock70  int64 = 301 // 10m ~ 30m
	DefaultRewardPayoutStartBlock100 int64 = 901 // 30m ~
)

func init() {
	// warmUp[100] = 1296001 // 30d ~
	// warmUp[70] = 432001   // 10d ~ 30d
	// warmUp[50] = 216001   // 5d ~ 10d
	// warmUp[30] = 1        // ~ 5d

	// shorter warm up period for testing
	warmUp = NewWarmUp(
		DefaultRewardPayoutStartBlock30,
		DefaultRewardPayoutStartBlock50,
		DefaultRewardPayoutStartBlock70,
		DefaultRewardPayoutStartBlock100)

	warmUpThresholds = NewWarmUpThresholds()
}

func NewWarmUp(rewardHeight30, rewardHeight50, rewardHeight70, rewardHeight100 int64) map[int64]int64 {
	return map[int64]int64{
		WarmUpFor30Ratio:  rewardHeight30,
		WarmUpFor50Ratio:  rewardHeight50,
		WarmUpFor70Ratio:  rewardHeight70,
		WarmUpFor100Ratio: rewardHeight100,
	}
}

func NewWarmUpThresholds() []int64 {
	// DifferenceBlock Between WarmUp Rearward Payout Start Block 30 and Threshold
	DifferenceBetweenWarmUpAndThreshold := GetWarmUp(WarmUpFor30Ratio)

	thresholds := make([]int64, NumOfWarmUpSection)
	thresholds[IndexOfWarmUpSection0] = 0
	thresholds[IndexOfWarmUpSection30] = GetWarmUp(WarmUpFor30Ratio) - DifferenceBetweenWarmUpAndThreshold
	thresholds[IndexOfWarmUpSection50] = GetWarmUp(WarmUpFor50Ratio) - DifferenceBetweenWarmUpAndThreshold
	thresholds[IndexOfWarmUpSection70] = GetWarmUp(WarmUpFor70Ratio) - DifferenceBetweenWarmUpAndThreshold
	thresholds[IndexOfWarmUpSection100] = GetWarmUp(WarmUpFor100Ratio) - DifferenceBetweenWarmUpAndThreshold

	return thresholds
}

func GetWarmUp(percent int64) int64 {
	value, exist := warmUp[percent]
	if !exist {
		panic(addDetailToError(
			errInvalidWarmUpPercent,
			ufmt.Sprintf("warm_up.gno__GetWarmUp() || percent(%d) must be 30, 50, 70, 100", percent),
		))
	}

	return value
}

func SetWarmUp(percent int64, block int64) {
	common.IsHalted()

	if _, exist := warmUp[percent]; !exist {
		panic(addDetailToError(
			errInvalidWarmUpPercent,
			ufmt.Sprintf("warm_up.gno__SetWarmUp() || percent(%d) must be 30, 50, 70, 100", percent),
		))
	}

	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN && caller != consts.GOV_GOVERNANCE_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf(
				"warm_up.gno__SetWarmUp() || only admin(%s) or governance(%s) can set warm up period, called from %s",
				consts.ADMIN,
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		),
		)
	}

	warmUp[percent] = block
}

var (
	WarmUpSection [NumOfWarmUpSection]int8 = [NumOfWarmUpSection]int8{0, 1, 2, 3, 4} // WarmUpSection
)

// WarmUpCalculator it helps to calculate the reward by applying the warmup period.
type WarmUpCalculator struct {
	stakeHeight    int64 // stakeHeight is the height when the staking position was created
	lastCalcHeight int64 // lastCalcHeight is the last calculated height
	currentSection int8  // currentSection is the section at the current height
	lastSection    int8  // lastSection is the section at the last calculated height
	warmUpOverFlow bool  // Check if the section at the current height is different from the section at the last calculated height
}

func NewWarmUpCalculator(stakeHeight int64, lastHeight int64) *WarmUpCalculator {
	return &WarmUpCalculator{
		stakeHeight:    stakeHeight,
		lastCalcHeight: lastHeight,
		currentSection: WarmUpSection[IndexOfWarmUpSection0],
		lastSection:    WarmUpSection[IndexOfWarmUpSection0],
	}
}

func (wc *WarmUpCalculator) CalculateWarmUp(currentHeight int64, rewardAmount uint64) (uint64, uint64) {
	reward, penalty := uint64(0), uint64(0)
	if currentHeight <= wc.stakeHeight {
		return reward, penalty
	}

	//warmUpHeight           []int64 // warmUpHeight = stakeHeight + warmUp[percent]
	//warmUpThresholdsHeight []int64 // warmUpThresholdsHeight = stakeHeight + warmUpThresholds[percent]
	//warmUpSection          []int8  // warmUpSection = {0, 1, 2, 3, 4}

	//thresholds := []int64{WarmUp30, WarmUp50, WarmUp70, WarmUp100}
	//for _, threshold := range thresholds {
	//	thresholdHeight := wc.warmUp[threshold] + wc.stakeHeight
	//	warmUpRatio := threshold
	//
	//	if currentHeight >= thresholdHeight && wc.lastCalcHeight < thresholdHeight {
	//		reward, penalty = wc.calculateWarmUpRewardAmount(currentHeight, wc.stakeHeight, rewardAmount, threshold)
	//		break
	//	}
	//}

	return reward, penalty
}

func (wc *WarmUpCalculator) findSection(height int64) int8 {
	section := wc.currentSection
	for i := 0; i < len(warmUpThresholds); i++ {
		if height >= warmUpThresholds[i] {
			section = WarmUpSection[i]
		}
	}

	return section
}
