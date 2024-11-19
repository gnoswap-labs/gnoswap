package staker

import (
	"std"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/p/demo/ufmt"
)

const (
	WarmUpFor30Ratio  int64 = int64(30)
	WarmUpFor50Ratio  int64 = int64(50)
	WarmUpFor70Ratio  int64 = int64(70)
	WarmUpFor100Ratio int64 = int64(100)

	NumOfWarmUpSection int8 = 5
	WarmUpSection0     int8 = 0 // Section 0 is no reward duration
	WarmUpSection30    int8 = 1 // Section 30 is 30% reward duration
	WarmUpSection50    int8 = 2 // Section 50 is 50% reward duration
	WarmUpSection70    int8 = 3 // Section 70 is 70% reward duration
	WarmUpSection100   int8 = 4 // Section 100 is 100% reward duration

	DefaultRewardPayoutStartBlock30  int64 = 1   // ~ 5m
	DefaultRewardPayoutStartBlock50  int64 = 151 // 5m ~ 10m
	DefaultRewardPayoutStartBlock70  int64 = 301 // 10m ~ 30m
	DefaultRewardPayoutStartBlock100 int64 = 901 // 30m ~
)

// NOTE: warmUp is a map of percent to block number
// warmUp has a duration value. It applies different reward payout rates
// based on when the LP was staked by the staking position.
// warmUp has a threshold height value for rewards to be paid.
// For example,
// if the staked block height is 10, the 30% reward period
// for warmup starts at the staked block height + warmup[30].
var (
	warmUp        = make(map[int64]int64)      // map[percent]block
	WarmUpSection = [NumOfWarmUpSection]int8{} // WarmUpSection
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

	WarmUpSection = [NumOfWarmUpSection]int8{
		WarmUpSection0,
		WarmUpSection30,
		WarmUpSection50,
		WarmUpSection70,
		WarmUpSection100}
}

func NewWarmUp(rewardHeight30, rewardHeight50, rewardHeight70, rewardHeight100 int64) map[int64]int64 {
	return map[int64]int64{
		WarmUpFor30Ratio:  rewardHeight30,
		WarmUpFor50Ratio:  rewardHeight50,
		WarmUpFor70Ratio:  rewardHeight70,
		WarmUpFor100Ratio: rewardHeight100,
	}
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

func GetWarmUpMap() map[int64]int64 {
	return warmUp
}

// WarmUpCalculator it helps to calculate the reward by applying the warmup period.
type WarmUpCalculator struct {
	startHeight    int64 // startHeight is the height at which warm-up rewards can be paid.
	lastCalcHeight int64 // lastCalcHeight is the last calculated height
	currentSection int8  // currentSection is the section at the current height
	lastSection    int8  // lastSection is the section at the last calculated height
	warmUpOverFlow bool  // Check if the section at the current height is different from the section at the last calculated height
}

func NewWarmUpCalculator(startHeight int64, lastHeight int64) *WarmUpCalculator {
	return &WarmUpCalculator{
		startHeight:    startHeight,
		lastCalcHeight: lastHeight,
		currentSection: WarmUpSection[WarmUpSection0],
		lastSection:    WarmUpSection[WarmUpSection0],
		warmUpOverFlow: false,
	}
}

func (wc *WarmUpCalculator) SetSectionOverFlow(isOverFlow bool) {
	wc.warmUpOverFlow = isOverFlow
}
func (wc *WarmUpCalculator) SetCurrentSection(section int8) {
	wc.currentSection = section
}
func (wc *WarmUpCalculator) SetLastSection(section int8) {
	wc.lastSection = section
}

func (wc *WarmUpCalculator) GetSectionOverFlow() bool {
	return wc.warmUpOverFlow
}
func (wc *WarmUpCalculator) GetCurrentSection() int8 {
	return wc.currentSection
}
func (wc *WarmUpCalculator) GetLastSection() int8 {
	return wc.lastSection
}

// normalizeHeight returns the normalizedHeight to calculate warm-up rewards.
// If the height is less than the startHeight, it returns -1.
// Otherwise, it returns the normalized height.
func (wc *WarmUpCalculator) normalizeHeight(height int64) int64 {
	if height < wc.startHeight {
		return -1
	}

	normHeight := height - (wc.startHeight - 1)
	return normHeight
}

// searchSection returns the section at the normalized height.
// Loop over the size of warmUp, updating as it goes,
// checking to see if it's above the warmUp[percent] block
func (wc *WarmUpCalculator) searchSection(normalizedHeight int64) int8 {
	section := WarmUpSection0
	warmUpMap := GetWarmUpMap()
	for percent, block := range warmUpMap {
		if normalizedHeight >= block {
			section = WarmUpSection[wc.PercentToSection(percent)]
		}
	}
	return section
}

// PercentToSection returns the section for the given percent.
func (wc *WarmUpCalculator) PercentToSection(percent int64) int8 {
	switch percent {
	case WarmUpFor30Ratio:
		return WarmUpSection30
	case WarmUpFor50Ratio:
		return WarmUpSection50
	case WarmUpFor70Ratio:
		return WarmUpSection70
	case WarmUpFor100Ratio:
		return WarmUpSection100
	default:
		return WarmUpSection0
	}
}

// GetWarmUpRewardRatio returns the reward ratio for the given section.
func (wc *WarmUpCalculator) GetWarmUpRewardRatio(section int8) int64 {
	switch section {
	case WarmUpSection30:
		return WarmUpFor30Ratio
	case WarmUpSection50:
		return WarmUpFor50Ratio
	case WarmUpSection70:
		return WarmUpFor70Ratio
	case WarmUpSection100:
		return WarmUpFor100Ratio
	default:
		return 0
	}
}

// GetWamUpHeightBy returns the warm-up height for the given section.
func (wc *WarmUpCalculator) GetWamUpHeightBy(section int8) int64 {
	switch section {
	case WarmUpSection30:
		return GetWarmUp(WarmUpFor30Ratio)
	case WarmUpSection50:
		return GetWarmUp(WarmUpFor50Ratio)
	case WarmUpSection70:
		return GetWarmUp(WarmUpFor70Ratio)
	case WarmUpSection100:
		return GetWarmUp(WarmUpFor100Ratio)
	default:
		return 0
	}
}

// compute calculates the reward and penalty for the given warmup height.
func (wc *WarmUpCalculator) compute(curHeight int64, lastHeight int64, amount uint64) (uint64, uint64) {
	reward, penalty := uint64(0), uint64(0)

	isOverFlow := wc.GetSectionOverFlow()
	if isOverFlow && wc.GetLastSection() != WarmUpSection[WarmUpSection0] {
		// amount = amount for current section + amount for last section
		// amount for current section = (currentHeight - (currentSectionStartHeight-1)) / (currentHeight - lastHeight)
		curSectionAmount := uint64((curHeight - (wc.GetWamUpHeightBy(wc.GetCurrentSection()) - 1)) / (curHeight - lastHeight))
		currRewardRatio := wc.GetWarmUpRewardRatio(wc.GetCurrentSection())
		// current section amount * reward ratio for current section / 100
		curSectionReward := curSectionAmount * uint64(currRewardRatio) / 100
		lastSectionAmount := amount - curSectionAmount
		lastRewardRatio := wc.GetWarmUpRewardRatio(wc.GetLastSection())
		// last section amount * reward ratio for last section / 100
		lastSectionReward := lastSectionAmount * uint64(lastRewardRatio) / 100

		reward = curSectionReward + lastSectionReward
		//TODO :
		// 1. after refactoring is completed, should be removed
		switch wc.GetCurrentSection() {
		case WarmUpSection30:
			warmUpReward.give30 += reward
			warmUpReward.left30 += amount - reward
		case WarmUpSection50:
			warmUpReward.give30 += lastSectionReward
			warmUpReward.left30 += lastSectionAmount - lastSectionReward
			warmUpReward.give50 += curSectionReward
			warmUpReward.left50 += curSectionAmount - curSectionReward
		case WarmUpSection70:
			warmUpReward.give50 += lastSectionReward
			warmUpReward.left50 += lastSectionAmount - lastSectionReward
			warmUpReward.give70 += curSectionReward
			warmUpReward.left70 += curSectionAmount - curSectionReward
		case WarmUpSection100:
			warmUpReward.give70 += lastSectionReward
			warmUpReward.left70 += lastSectionAmount - lastSectionReward
			warmUpReward.full100 += curSectionReward
		}
	} else {
		// warmupReward = amount * reward ratio for section / 100
		warmUpRewardRatio := wc.GetWarmUpRewardRatio(wc.GetCurrentSection())
		reward = amount * uint64(warmUpRewardRatio) / 100
		//TODO :
		// 1. after refactoring is completed, should be removed
		switch wc.GetCurrentSection() {
		case WarmUpSection30:
			warmUpReward.give30 += reward
			warmUpReward.left30 += amount - reward
		case WarmUpSection50:
			warmUpReward.give50 += reward
			warmUpReward.left50 += amount - reward
		case WarmUpSection70:
			warmUpReward.give70 += reward
			warmUpReward.left70 += amount - reward
		case WarmUpSection100:
			warmUpReward.full100 += reward
		}
	}
	penalty = amount - reward
	return reward, penalty
}

// CalculateWarmUp calculates the warm-up rewards and penalties.
func (wc *WarmUpCalculator) CalculateWarmUp(currentHeight int64, rewardAmount uint64) (uint64, uint64) {
	reward, penalty := uint64(0), uint64(0)
	// 1. Check conditions
	if currentHeight < wc.startHeight || currentHeight <= wc.lastCalcHeight {
		return reward, penalty
	}
	// 2. change unit from height to warmup height
	normCurrHeight := wc.normalizeHeight(currentHeight)
	normLastHeight := wc.normalizeHeight(wc.lastCalcHeight)
	if normLastHeight < 0 {
		normLastHeight = 0
	}
	// 3. search section
	normCurrSection := wc.searchSection(normCurrHeight)
	wc.SetCurrentSection(normCurrSection)
	normLastSection := wc.searchSection(normLastHeight)
	wc.SetLastSection(normLastSection)
	// 4. Check warmup overflow
	if normCurrSection != normLastSection && normCurrSection > normLastSection {
		wc.SetSectionOverFlow(true)
	} else {
		wc.SetSectionOverFlow(false)
	}
	// 5. compute reward and penalty
	reward, penalty = wc.compute(normCurrHeight, normLastHeight, rewardAmount)

	return reward, penalty
}
