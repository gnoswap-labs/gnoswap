package launchpad

import (
	u256 "gno.land/p/gnoswap/uint256"
)

type Tier struct {
	id                  string // '{projectId}:duration' // duartion == 30, 90, 180
	collectWaitDuration uint64 // block

	tierAmount             uint64
	tierAmountPerBlockX128 *u256.Uint

	userCollectedAmount uint64 // total collected amount by user
	calculatedAmount    uint64 // total calculated amount

	totalDepositAmount  uint64 // accumulated deposit amount
	actualDepositAmount uint64 // actual deposit amount

	totalParticipant  uint64 // accumulated participant
	actualParticipant uint64 // actual participant

	started TimeInfo // first deposit height
	ended   TimeInfo

	reward Reward
}

func (t Tier) ID() string                      { return t.id }
func (t Tier) SetID(v string)                  { t.id = v }
func (t Tier) CollectWaitDuration() uint64     { return t.collectWaitDuration }
func (t Tier) SetCollectWaitDuration(v uint64) { t.collectWaitDuration = v }

func (t Tier) TierAmount() uint64                     { return t.tierAmount }
func (t Tier) SetTierAmount(v uint64)                 { t.tierAmount = v }
func (t Tier) TierAmountPerBlockX128() *u256.Uint     { return t.tierAmountPerBlockX128 }
func (t Tier) SetTierAmountPerBlockX128(v *u256.Uint) { t.tierAmountPerBlockX128 = v }

func (t Tier) UserCollectedAmount() uint64     { return t.userCollectedAmount }
func (t Tier) SetUserCollectedAmount(v uint64) { t.userCollectedAmount = v }
func (t Tier) CalculatedAmount() uint64        { return t.calculatedAmount }
func (t Tier) SetCalculatedAmount(v uint64)    { t.calculatedAmount = v }

func (t Tier) TotalDepositAmount() uint64      { return t.totalDepositAmount }
func (t Tier) SetTotalDepositAmount(v uint64)  { t.totalDepositAmount = v }
func (t Tier) ActualDepositAmount() uint64     { return t.actualDepositAmount }
func (t Tier) SetActualDepositAmount(v uint64) { t.actualDepositAmount = v }

func (t Tier) TotalParticipant() uint64      { return t.totalParticipant }
func (t Tier) SetTotalParticipant(v uint64)  { t.totalParticipant = v }
func (t Tier) ActualParticipant() uint64     { return t.actualParticipant }
func (t Tier) SetActualParticipant(v uint64) { t.actualParticipant = v }

func (t Tier) Started() TimeInfo     { return t.started }
func (t Tier) SetStarted(v TimeInfo) { t.started = v }
func (t Tier) Ended() TimeInfo       { return t.ended }
func (t Tier) SetEnded(v TimeInfo)   { t.ended = v }

func (t Tier) Reward() Reward     { return t.reward }
func (t Tier) SetReward(v Reward) { t.reward = v }

// NewTier creates a new tier instance
func NewTier(
	id string,
	collectWaitDuration uint64,
	tierAmount uint64,
	tierAmountPerBlockX128 *u256.Uint,
	started, ended TimeInfo,
	totalDepositAmount, actualDepositAmount uint64,
	totalParticipant, actualParticipant uint64,
	userCollectedAmount, calculatedAmount uint64,
	reward Reward,
) *Tier {
	return &Tier{
		id:                     id,
		collectWaitDuration:    collectWaitDuration,
		tierAmount:             tierAmount,
		tierAmountPerBlockX128: tierAmountPerBlockX128,
		started:                started,
		ended:                  ended,
		totalDepositAmount:     totalDepositAmount,
		actualDepositAmount:    actualDepositAmount,
		totalParticipant:       totalParticipant,
		actualParticipant:      actualParticipant,
		userCollectedAmount:    userCollectedAmount,
		calculatedAmount:       calculatedAmount,
		reward:                 reward,
	}
}

func (t *Tier) Activated(currentHeight uint64) bool {
	return t.started.Height() <= currentHeight && currentHeight < t.ended.Height()
}

func (t *Tier) IsFirstDeposit() bool {
	return t.totalParticipant == 0
}

// update state
func (t *Tier) UpdateStarted(height, time uint64) error {
	t.started = NewTimeInfo(height, time)
	t.reward.SetLastHeight(height)
	return nil
}

func (t *Tier) IsEnded(currentHeight uint64) bool {
	return t.ended.isEnded(currentHeight)
}

func (t *Tier) LeftReward() uint64 {
	return t.tierAmount - t.userCollectedAmount
}

func CreateTier(
	projectId string,
	duration uint64,
	amount uint64,
	startHeight uint64,
	startTime uint64,
	collectWaitDuration uint64,
	avgBlockTimeMs uint64,
	rewardStates *RewardStates,
) (Tier, error) {
	tierId := createId(projectId, formatUint64(duration))

	tierStart := NewTimeInfo(startHeight, startTime)

	durationSecond := duration * TIMESTAMP_DAY
	endTime := startTime + durationSecond
	durationHeight, err := estimateTimeToHeight(avgBlockTimeMs, durationSecond)
	if err != nil {
		return Tier{}, err
	}
	endHeight := startHeight + durationHeight

	tierEnded := NewTimeInfo(endHeight, endTime)
	rewardPerBlockX128 := CalculateTierRewardRate(amount, durationHeight)
	reward := NewReward(u256.Zero(), startHeight, endHeight)

	tier := Tier{
		id:                     tierId,
		collectWaitDuration:    collectWaitDuration,
		tierAmount:             amount,
		tierAmountPerBlockX128: rewardPerBlockX128,
		started:                tierStart,
		ended:                  tierEnded,
		reward:                 *reward,
	}

	rewardState := NewRewardState(tier.tierAmountPerBlockX128, startHeight, endHeight)
	rewardStates.Set(projectId, formatUint64(duration), rewardState)

	// projectTiersWithoutDeposit[tierId] = true

	return tier, nil
}
