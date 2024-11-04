package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
)

func rewardMathComputeExternalRewardAmount(tokenId uint64, incentiveId string) (uint64, uint64) {
	calculator := NewCalculator(tokenId, incentiveId)
	full, give, err := calculator.computeRewards()
	if err != nil {
		panic(err)
	}
	return full, give
}

// These ratios represent different reward levels that increase
// over time to incentivize longer staking periods.
const (
	RatioThirty  = 30
	RatioFifty   = 50
	RatioSeventy = 70
	RatioHundred = 100
)

// RewardState holds the state necessary for computing rewards
type RewardState struct {
	TokenId                  uint64
	IncentiveId              string
	CurrentHeight            int64
	StakedOrExternalDuration int64
	WarmUpAmount             warmUpAmount
	DistributionAmount       *u256.Uint
	LastCalculatedHeight     uint64
}

// TimeSpan represents a period during which a specific reward ratio applies
type TimeSpan struct {
	Start    uint64
	End      uint64
	Duration uint64
	Ratio    int
}

// RewardPeriod combines a TimeSpan with the calculated reward amount
type RewardPeriod struct {
	TimeSpan
	Amount *u256.Uint
}

// PeriodDefinition defines the start and end offsets and reward ratio
type PeriodDefinition struct {
	Ratio       int
	StartOffset uint64
	EndOffset   uint64
}

// Calculator handles reward calculations for external incentives.
//
// It maintains state neccesary for computing rewards across different staking periods
// and handles the progression through various reward rates (30%, 50%, 70%, 100%).
type Calculator struct {
	state              RewardState
	lastCalcHeight     uint64
	distributionAmount *u256.Uint
}

// NewCalculator creates a new reward calculator instance for a given token and incentive.
//
// The calculator will be used to compute rewards for the specified token's position
// in the given incentive program.
func NewCalculator(tokenId uint64, incentiveId string) *Calculator {
	state := RewardState{
		TokenId:       tokenId,
		IncentiveId:   incentiveId,
		CurrentHeight: std.GetHeight(),
	}

	return &Calculator{
		state: state,
	}
}

// calculateTimePeriods computes time spans for difference reward rates based on staking duration.
//
// It breaks down the staking period into different reward rate periods based on
// predefined warmup thresholds. Each period represents a time span where specific
// reward rate applies.
//
// The periods are calculated from the last calculated height up to the current height.
// ensuring continuous reward tracking. Periods are ordered by increasing reward rates
// and are guaranteed to be continous (no gaps between them).
func (c *Calculator) calculateTimePeriods() []TimeSpan {
	startHeight := c.lastCalcHeight
	currentHeight := uint64(c.state.CurrentHeight)

	threshold50 := uint64(warmUp[50])
	threshold70 := uint64(warmUp[70])
	threshold100 := uint64(warmUp[100])

	periodsDef := []PeriodDefinition{
		{Ratio: RatioThirty, StartOffset: 0, EndOffset: threshold50 - 1},
		{Ratio: RatioFifty, StartOffset: threshold50, EndOffset: threshold70 - 1},
		{Ratio: RatioSeventy, StartOffset: threshold70, EndOffset: threshold100 - 1},
		{Ratio: RatioHundred, StartOffset: threshold100, EndOffset: currentHeight - startHeight},
	}

	return c.computeTimeSpans(startHeight, periodsDef)
}

// computeTimeSpans converts period definitions into actual time spans.
//
// it takes a start height and period definition and creates [TimeSpan] instances
// that represent actual block height ranges for each reward rate period.
//
// This function ensures:
//   - Periods don't exceed current height
//   - Periods are continuous
//   - Periods maintain proper order of reward rates
func (c *Calculator) computeTimeSpans(startHeight uint64, periodsDef []PeriodDefinition) []TimeSpan {
	currentHeight := uint64(c.state.CurrentHeight)
	periods := make([]TimeSpan, 0, len(periodsDef))

	for _, pd := range periodsDef {
		periodStart := startHeight + pd.StartOffset
		periodEnd := c.calculatePeriodEnd(startHeight, pd.EndOffset, currentHeight)

		start := maxUint64(periodStart, c.lastCalcHeight)
		end := minUint64(periodEnd, currentHeight)

		// skip invalid periods
		if start >= end {
			continue
		}

		periods = append(periods, TimeSpan{
			Start:    start,
			End:      end,
			Duration: end - start,
			Ratio:    pd.Ratio,
		})
	}

	return periods
}

func (c *Calculator) calculatePeriodEnd(startHeight uint64, endOffset uint64, currentHeight uint64) uint64 {
	if endOffset == 0 {
		return currentHeight
	}
	return startHeight + endOffset
}

// computeRewards calculates the total rewards for a token position in an incentive program.
// It performs the complete reward calculation process:
//  1. Validates the existence of position and incentive
//  2. Determines the calculation period
//  3. Computes rewards for each period with different rates
//  4. Accumulates and stores the rewards
//  5. Returns the total rewards and immediately claimable amount
//
// Returns:
//   - full: total rewards accumulated
//   - give: immediately claimable rewards
//   - error: if position or incentive not found
func (c *Calculator) computeRewards() (uint64, uint64, error) {
	externalsMap, exists := positionExternal[c.state.TokenId]
	if !exists {
		return 0, 0, ufmt.Errorf("no externals found for token %d", c.state.TokenId)
	}

	external, exists := externalsMap[c.state.IncentiveId]
	if !exists {
		return 0, 0, ufmt.Errorf(
			"no external found for token %d and incentive %s",
			c.state.TokenId, c.state.IncentiveId,
		)
	}

	c.lastCalcHeight = uint64(positionsExternalLastCalculatedHeight[c.state.TokenId][c.state.IncentiveId])
	periods := c.calculateTimePeriods()

	c.distributionAmount = calculateDistributionExternalRewards(
		external,
		positionLastExternal[c.state.TokenId][c.state.IncentiveId],
	)

	rewardPeriods := c.calculateRewardPeriods(periods)
	finalAmount := accumulateRewards(rewardPeriods)

	c.updateWarmUpAmounts(finalAmount)

	totalFull, totalGive := c.calculateTotals(finalAmount)
	return totalFull, totalGive, nil
}

// calculateRewardPeriods converts time spans into reward periods by computing
// the actual reward amount for each period.
//
// For each time span, it:
//   - Calculates rewards per block
//   - Multiplies by the period duration
//   - Creates a [RewardPeriod] instance with both timing and reward information
func (c *Calculator) calculateRewardPeriods(periods []TimeSpan) []RewardPeriod {
	rewardPeriods := make([]RewardPeriod, 0, len(periods))

	for _, period := range periods {
		blockAmount, err := calculateBlockAmount(c.distributionAmount, period)
		if err != nil {
			panic(err)
		}

		rewardPeriod := calculatePeriodReward(blockAmount, period)
		rewardPeriods = append(rewardPeriods, rewardPeriod)
	}

	return rewardPeriods
}

// updateWarmUpAmounts stores the calculated reward amounts in the global state.
//
// This maintains the record of accumulated rewards that can be claimed later.
// TODO: should we use a more efficient data structure?
func (c *Calculator) updateWarmUpAmounts(amount warmUpAmount) {
	if positionsExternalWarmUpAmount[c.state.TokenId] == nil {
		positionsExternalWarmUpAmount[c.state.TokenId] = make(map[string]warmUpAmount)
	}
	positionsExternalWarmUpAmount[c.state.TokenId][c.state.IncentiveId] = amount
}

func (c *Calculator) calculateTotals(amount warmUpAmount) (uint64, uint64) {
	totalFull := amount.full30 + amount.full50 + amount.full70 + amount.full100
	totalGive := amount.give30 + amount.give50 + amount.give70 + amount.full100
	return totalFull, totalGive
}

// calculatePeriodReward computes the total reward amount for a specific time span.
//
// It takes the reward amount per block and multiplies it by the duration
// of the period to get the total rewards for that specific time span.
func calculatePeriodReward(blockAmount *u256.Uint, timeSpan TimeSpan) RewardPeriod {
	fullAmount := new(u256.Uint).Mul(
		blockAmount,
		new(u256.Uint).SetUint64(timeSpan.Duration),
	)

	return RewardPeriod{
		TimeSpan: timeSpan,
		Amount:   fullAmount,
	}
}

// accumulateRewards aggregates rewards from multiple periods into a single warmUpAmount.
//
// For each period, it:
//   - Adds the full amount to the appropriate total (full30, full50, etc.)
//   - Calculates the immediately claimable amount based on the ratio
//   - Tracks the remaining locked amount
//
// This creates a complete picture of available and locked rewards across all periods.
func accumulateRewards(periods []RewardPeriod) warmUpAmount {
	var total warmUpAmount

	for _, period := range periods {
		amount := period.Amount.Uint64()
		if amount == 0 {
			continue
		}

		switch period.Ratio {
		case RatioThirty:
			norm := amount * RatioThirty / 100
			total.full30 += amount
			total.give30 += norm
			total.left30 += amount - norm
		case RatioFifty:
			norm := amount * RatioFifty / 100
			total.full50 += amount
			total.give50 += norm
			total.left50 += amount - norm
		case RatioSeventy:
			norm := amount * RatioSeventy / 100
			total.full70 += amount
			total.give70 += norm
			total.left70 += amount - norm
		case RatioHundred:
			total.full100 += amount
		}
	}

	return total
}

// calculateDistributionExternalRewards computes the total amount of rewards
// to be distributed since the last calculation.
//
// This is used to determine how many rewards are available for the current calculating period.
func calculateDistributionExternalRewards(external externalRewards, lastAmount *u256.Uint) *u256.Uint {
	tokenAmount := external.tokenAmountX96
	return new(u256.Uint).Sub(tokenAmount, lastAmount)
}

func calculateBlockAmount(dst *u256.Uint, timeSpan TimeSpan) (*u256.Uint, error) {
	duration := new(u256.Uint).SetUint64(timeSpan.End - timeSpan.Start)
	if duration.IsZero() {
		return nil, ufmt.Errorf("duration is zero")
	}
	return new(u256.Uint).Div(dst, duration), nil
}

func maxUint64(a, b uint64) uint64 {
	if a > b {
		return a
	}
	return b
}

func minUint64(a, b uint64) uint64 {
	if a < b {
		return a
	}
	return b
}
