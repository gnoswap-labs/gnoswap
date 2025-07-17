package staker

import (
	"errors"

	u256 "gno.land/p/gnoswap/uint256"
)

type ProtocolFeeRewardState struct {
	rewardDebtX128     map[string]*u256.Uint
	accumulatedRewards map[string]int64
	claimedRewards     map[string]int64
	accumulatedHeight  int64
	claimedHeight      int64
	stakedAmount       int64
}

func (p *ProtocolFeeRewardState) IsClaimable(currentHeight int64) bool {
	return p.claimedHeight < currentHeight
}

func (p *ProtocolFeeRewardState) GetClaimableRewardAmounts(
	accumulatedRewardsX128PerStake map[string]*u256.Uint,
	currentHeight int64,
) map[string]int64 {
	rewardAmounts := p.calculateClaimableRewards(accumulatedRewardsX128PerStake, currentHeight)

	return rewardAmounts
}

func (p *ProtocolFeeRewardState) calculateClaimableRewards(
	accumulatedRewardsX128PerStake map[string]*u256.Uint,
	currentHeight int64,
) map[string]int64 {
	if p.accumulatedHeight >= currentHeight {
		return p.accumulatedRewards
	}

	rewardAmounts := make(map[string]int64)

	for token, accumulatedRewardX128PerStake := range accumulatedRewardsX128PerStake {
		if p.rewardDebtX128[token] == nil {
			p.rewardDebtX128[token] = u256.Zero()
		}

		rewardDebtDeltaX128 := u256.Zero().Sub(
			accumulatedRewardX128PerStake,
			p.rewardDebtX128[token],
		)
		rewardAmountX128 := u256.Zero().Mul(
			rewardDebtDeltaX128,
			u256.NewUintFromInt64(p.stakedAmount),
		)
		rewardAmount := u256.Zero().Rsh(rewardAmountX128, 128)

		rewardAmounts[token] = rewardAmount.Int64()
	}

	return rewardAmounts
}

func (p *ProtocolFeeRewardState) addStake(amount int64) {
	p.stakedAmount = p.stakedAmount + amount
}

func (p *ProtocolFeeRewardState) removeStake(amount int64) {
	p.stakedAmount = p.stakedAmount - amount
}

func (p *ProtocolFeeRewardState) claimRewards(currentHeight int64) (map[string]int64, error) {
	if !p.IsClaimable(currentHeight) {
		return nil, errors.New("not claimable")
	}

	if p.accumulatedHeight < currentHeight {
		return nil, errors.New("must update reward debt before claiming rewards")
	}

	currentClaimedRewards := map[string]int64{}

	for token, rewardAmount := range p.accumulatedRewards {
		currentClaimedRewards[token] = rewardAmount - p.claimedRewards[token]
		p.claimedRewards[token] = rewardAmount
	}

	p.claimedHeight = currentHeight

	return currentClaimedRewards, nil
}

func (p *ProtocolFeeRewardState) updateRewardDebtX128(
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
	currentHeight int64,
) {
	if p.accumulatedHeight >= currentHeight {
		return
	}

	rewardAmounts := p.calculateClaimableRewards(accumulatedProtocolFeeX128PerStake, currentHeight)
	p.rewardDebtX128 = cloneAccumulatedProtocolFeeX128PerStake(accumulatedProtocolFeeX128PerStake)

	for token, rewardAmount := range rewardAmounts {
		p.accumulatedRewards[token] = p.accumulatedRewards[token] + rewardAmount
	}

	p.accumulatedHeight = currentHeight
}

func (p *ProtocolFeeRewardState) addStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
	currentHeight int64,
) {
	p.updateRewardDebtX128(accumulatedProtocolFeeX128PerStake, currentHeight)
	p.addStake(amount)
}

func (p *ProtocolFeeRewardState) removeStakeWithUpdateRewardDebtX128(
	amount int64,
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
	currentHeight int64,
) {
	p.updateRewardDebtX128(accumulatedProtocolFeeX128PerStake, currentHeight)
	p.removeStake(amount)
}

func (p *ProtocolFeeRewardState) claimRewardsWithUpdateRewardDebtX128(
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
	currentHeight int64,
) (map[string]int64, error) {
	p.updateRewardDebtX128(accumulatedProtocolFeeX128PerStake, currentHeight)

	return p.claimRewards(currentHeight)
}

func NewProtocolFeeRewardState(
	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint,
) *ProtocolFeeRewardState {
	rewardDebtX128 := make(map[string]*u256.Uint)

	for token, accumulatedProtocolFeeX128PerStake := range accumulatedProtocolFeeX128PerStake {
		rewardDebtX128[token] = accumulatedProtocolFeeX128PerStake.Clone()
	}

	return &ProtocolFeeRewardState{
		rewardDebtX128:     rewardDebtX128,
		claimedRewards:     map[string]int64{},
		accumulatedRewards: map[string]int64{},
		stakedAmount:       0,
		accumulatedHeight:  0,
		claimedHeight:      0,
	}
}

func cloneAccumulatedProtocolFeeX128PerStake(accumulatedProtocolFeeX128PerStake map[string]*u256.Uint) map[string]*u256.Uint {
	clone := make(map[string]*u256.Uint)

	for token, item := range accumulatedProtocolFeeX128PerStake {
		clone[token] = item.Clone()
	}

	return clone
}