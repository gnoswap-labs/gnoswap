package gov

import (
	"gno.land/r/staker"
)

//////////////////////////
// ProposalDataStakerParameterStakingRewards

var _ ProposalData = (*ProposalDataStakerParameterStakingRewards)(nil)


type ProposalDataStakerParameterStakingRewards struct {
	StakingRewardChanges []StakingRewardChange
}

func (p ProposalDataStakerParameterInflationRate) ProposalType() ProposalType {
	return ProposalTypeStakerParameterInflationRate
}

func (p ProposalDataStakerParameterInflationRate) isProposalData() {}

func (p ProposalDataStakerParameterStakingRewards) isValid() bool {
	for _, change := range p.StakingRewardChanges {
		if change.TokenA == "" {
			return false
		}

		if change.TokenB == "" {
			return false
		}

		if change.TokenA >= change.TokenB {
			return false
		}

		if change.Fee == 0 {
			return false
		}

		if change.NewStakingReward7 == 0 {
			return false
		}

		if change.NewStakingReward14 == 0 {
			return false
		}

		if change.NewStakingReward21 == 0 {
			return false
		}

		if change.NewStakingReward7 > change.NewStakingReward14 {
			return false
		}

		if change.NewStakingReward14 > change.NewStakingReward21 {
			return false
		}
	}
}

func (p ProposalDataStakerParameterStakingRewards) execute() error {
	for _, chan := range p.StakingRewardChanges {
		err := staker.SetStakingReward(change.TokenA, change.TokenB, change.Fee, change.NewStakingReward7, change.NewStakingReward14, change.NewStakingReward21)
		if err != nil {
			return err
		}
	}

	return nil
}