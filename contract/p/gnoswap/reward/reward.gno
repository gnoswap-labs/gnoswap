package reward

import (
	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

type rewardInfo struct {
	startHeight uint64     // height when staking started
	priceDebt   *u256.Uint // price dept per stake, Q128
	amount      uint64     // amount staked
	claimed     uint64     // amount of reward claimed so far
}

type RewardState struct {
	priceAccumulation *u256.Uint // claimable reward per stake, Q128
	totalStake        uint64     // total amount staked
	currentBalance    uint64     // current balance for reward calculation
	rewardInfo        *avl.Tree  // stakerId -> rewardInfo
}

// NewRewardState creates a new RewardState instance
func NewRewardState() *RewardState {
	return &RewardState{
		priceAccumulation: u256.Zero(),
		totalStake:        0,
		currentBalance:    0,
		rewardInfo:        avl.NewTree(),
	}
}

func (s *RewardState) RewardInfo(stakerId string) (rewardInfo, error) {
	infoI, exists := s.rewardInfo.Get(stakerId)
	if !exists {
		return rewardInfo{}, ufmt.Errorf("reward info not found for stakerId %s", stakerId)
	}

	info, ok := infoI.(*rewardInfo)
	if !ok {
		return rewardInfo{}, ufmt.Errorf("reward info not found for stakerId %s", stakerId)
	}

	return *info, nil
}

func (s *RewardState) PriceAccumulation() *u256.Uint {
	return s.priceAccumulation
}

func (s *RewardState) TotalStake() uint64 {
	return s.totalStake
}

// CalculateReward calculates the current reward for a staker
func (s *RewardState) CalculateReward(stakerId string) uint64 {
	info, err := s.RewardInfo(stakerId)
	if err != nil {
		return 0
	}

	stakerPrice := u256.Zero().Sub(s.priceAccumulation, info.priceDebt)
	reward := stakerPrice.Mul(stakerPrice, u256.NewUint(info.amount))
	reward = reward.Rsh(reward, 128)

	return reward.Uint64() - info.claimed
}
