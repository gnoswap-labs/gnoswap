package gov

import (
	"gno.land/r/pool"
)

//////////////////////////
// ProposalDataSwapParameterStakingRewards

var _ ProposalData = (*ProposalDataSwapParameterStakingRewards)(nil)

type PoolStakingRewardChange struct {
	PoolID uint64
	NewStakingReward7 bigint
	NewStakingReward14 bigint
	NewStakingReward21 bigint
}

type ProposalDataSwapParameterStakingRewards struct {
	PoolStakingRewardChanges []PoolStakingRewardChange
}

func (p ProposalDataSwapParameterInflationRate) ProposalType() ProposalType {
	return ProposalTypeSwapParameterInflationRate
}

func (p ProposalDataSwapParameterInflationRate) isProposalData() {}

func (p ProposalDataSwapParameterStakingRewards) isValid() bool {
	for _, poolStakingRewardChange := range p.PoolStakingRewardChanges {
		if poolStakingRewardChange.PoolID == 0 {
			return false
		}

		if poolStakingRewardChange.NewStakingReward7 == 0 {
			return false
		}

		if poolStakingRewardChange.NewStakingReward14 == 0 {
			return false
		}

		if poolStakingRewardChange.NewStakingReward21 == 0 {
			return false
		}

		if poolStakingRewardChange.NewStakingReward7 > poolStakingRewardChange.NewStakingReward14 {
			return false
		}

		if poolStakingRewardChange.NewStakingReward14 > poolStakingRewardChange.NewStakingReward21 {
			return false
		}
	}
}

func (p ProposalDataSwapParameterStakingRewards) execute() error {
	for _, poolStakingRewardChange := range p.PoolStakingRewardChanges {
		pool.SetStakingReward(poolStakingRewardChange.PoolID, poolStakingRewardChange.NewStakingReward7, poolStakingRewardChange.NewStakingReward14, poolStakingRewardChange.NewStakingReward21)
	}
}