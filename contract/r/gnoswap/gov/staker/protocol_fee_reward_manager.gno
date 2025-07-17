package staker

import (
	"gno.land/p/demo/avl"
	u256 "gno.land/p/gnoswap/uint256"
)

type ProtocolFeeRewardManager struct {
	rewardStates *avl.Tree // address -> ProtocolFeeRewardState

	accumulatedProtocolFeeX128PerStake map[string]*u256.Uint
	protocolFeeAmounts                 map[string]int64
	accumulatedHeight                  int64
	totalStakedAmount                  int64
}

func (p *ProtocolFeeRewardManager) GetAccumulatedProtocolFeeX128PerStake(token string) *u256.Uint {
	return p.accumulatedProtocolFeeX128PerStake[token]
}

func (p *ProtocolFeeRewardManager) GetAccumulatedHeight() int64 {
	return p.accumulatedHeight
}

func (p *ProtocolFeeRewardManager) GetClaimableRewardAmounts(
	protocolFeeAmounts map[string]int64,
	address string,
	currentHeight int64,
) map[string]int64 {
	rewardStateI, ok := p.rewardStates.Get(address)
	if !ok {
		return make(map[string]int64)
	}

	rewardState := rewardStateI.(*ProtocolFeeRewardState)
	accumulatedRewardX128PerStake, _ := p.calculateAccumulatedRewardX128PerStake(protocolFeeAmounts, currentHeight)

	return rewardState.GetClaimableRewardAmounts(accumulatedRewardX128PerStake, currentHeight)
}

func (p *ProtocolFeeRewardManager) calculateAccumulatedRewardX128PerStake(
	protocolFeeAmounts map[string]int64,
	currentHeight int64,
) (map[string]*u256.Uint, map[string]int64) {
	if p.accumulatedHeight > currentHeight {
		return p.accumulatedProtocolFeeX128PerStake, p.protocolFeeAmounts
	}

	accumulatedProtocolFeesX128PerStake := make(map[string]*u256.Uint)
	changedProtocolFeeAmounts := make(map[string]int64)

	for token, protocolFeeAmount := range protocolFeeAmounts {
		previousProtocolFeeAmount, ok := p.protocolFeeAmounts[token]
		if !ok {
			previousProtocolFeeAmount = 0
		}

		protocolFeeDelta := protocolFeeAmount - previousProtocolFeeAmount
		
		if protocolFeeDelta <= 0 {
			accumulatedProtocolFeesX128PerStake[token] = p.accumulatedProtocolFeeX128PerStake[token]
			if accumulatedProtocolFeesX128PerStake[token] == nil {
				accumulatedProtocolFeesX128PerStake[token] = u256.NewUint(0)
			} 
		}

		protocolFeeDeltaX128 := u256.NewUintFromInt64(protocolFeeDelta)
		protocolFeeDeltaX128 = u256.Zero().Lsh(protocolFeeDeltaX128, 128)

		protocolFeeDeltaX128PerStake := u256.Zero()

		if p.totalStakedAmount > 0 {
			protocolFeeDeltaX128PerStake = protocolFeeDeltaX128.Div(
				protocolFeeDeltaX128,
				u256.NewUintFromInt64(p.totalStakedAmount),
			)
		}

		accumulatedProtocolFeeX128PerStake := u256.Zero()
		if p.accumulatedProtocolFeeX128PerStake[token] != nil {
			accumulatedProtocolFeeX128PerStake = p.accumulatedProtocolFeeX128PerStake[token]
		}

		accumulatedProtocolFeeX128PerStake = u256.Zero().Add(
			accumulatedProtocolFeeX128PerStake,
			protocolFeeDeltaX128PerStake,
		)

		accumulatedProtocolFeesX128PerStake[token] = accumulatedProtocolFeeX128PerStake.Clone()
		changedProtocolFeeAmounts[token] = protocolFeeAmount
	}

	return accumulatedProtocolFeesX128PerStake, changedProtocolFeeAmounts
}

func (p *ProtocolFeeRewardManager) updateAccumulatedProtocolFeeX128PerStake(
	protocolFeeAmounts map[string]int64,
	currentHeight int64,
) {
	if p.accumulatedHeight > currentHeight {
		return
	}

	accumulatedProtocolFeeX128PerStake, changedProtocolFeeAmounts := p.calculateAccumulatedRewardX128PerStake(protocolFeeAmounts, currentHeight)

	p.accumulatedProtocolFeeX128PerStake = accumulatedProtocolFeeX128PerStake
	p.protocolFeeAmounts = changedProtocolFeeAmounts
	p.accumulatedHeight = currentHeight
}

func (p *ProtocolFeeRewardManager) addStake(address string, amount int64, currentHeight int64) {
	rewardStateI, ok := p.rewardStates.Get(address)
	if !ok {
		rewardStateI = NewProtocolFeeRewardState(p.accumulatedProtocolFeeX128PerStake)
	}

	rewardState := rewardStateI.(*ProtocolFeeRewardState)
	rewardState.addStakeWithUpdateRewardDebtX128(amount, p.accumulatedProtocolFeeX128PerStake, currentHeight)

	p.rewardStates.Set(address, rewardState)

	p.totalStakedAmount = p.totalStakedAmount + amount
}

func (p *ProtocolFeeRewardManager) removeStake(address string, amount int64, currentHeight int64) {
	rewardStateI, ok := p.rewardStates.Get(address)
	if !ok {
		rewardStateI = NewProtocolFeeRewardState(p.accumulatedProtocolFeeX128PerStake)
	}

	rewardState := rewardStateI.(*ProtocolFeeRewardState)
	rewardState.removeStakeWithUpdateRewardDebtX128(amount, p.accumulatedProtocolFeeX128PerStake, currentHeight)

	p.rewardStates.Set(address, rewardState)

	p.totalStakedAmount = p.totalStakedAmount - amount
}

func (p *ProtocolFeeRewardManager) claimRewards(address string, currentHeight int64) (map[string]int64, error) {
	rewardStateI, ok := p.rewardStates.Get(address)
	if !ok {
		return make(map[string]int64), nil
	}
	
	rewardState := rewardStateI.(*ProtocolFeeRewardState)

	claimedRewards, err := rewardState.claimRewardsWithUpdateRewardDebtX128(
		p.accumulatedProtocolFeeX128PerStake,
		currentHeight,
	)
	if err != nil {
		return nil, err
	}

	p.rewardStates.Set(address, rewardState)

	return claimedRewards, nil
}

func NewProtocolFeeRewardManager() *ProtocolFeeRewardManager {
	return &ProtocolFeeRewardManager{
		rewardStates:                       avl.NewTree(),
		protocolFeeAmounts:                 make(map[string]int64),
		accumulatedProtocolFeeX128PerStake: make(map[string]*u256.Uint),
		accumulatedHeight:                  0,
		totalStakedAmount:                  0,
	}
}
