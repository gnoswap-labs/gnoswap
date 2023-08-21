package staker

import (
	"gno.land/r/gov"
)

func DefaultInflationRate() bigint {
	return 0 // TODO
}

func getInflationRate() (bigint) {
	param, ok := gov.GetParameter("inflation_rate")
	if !ok {
		panic("inflation rate not set")
	}

	return param.(bigint)
}

func setInflationRate(newRate bigint) {
	gov.SetParameter("inflation_rate", newRate)
}

func DefaultStakingRewards() (StakingRewards) {
	// TODO
	return StakingRewards{
		StakingReward7: 1,
		StakingReward14: 2,
		StakingReward21: 3,
	}
}

func getStakingRewards(token0 string, token1 string, fee bigint) (StakingRewards) {
	param, ok := gov.GetParameter("staking_rewards:" + token0 + ":" + token1 + ":" + fee)
	if !ok {
		return DefaultStakingRewards()
	}

	return param.(StakingRewards)
}

func init() {
	setInflationRate(DefaultInflationRate())
}

type StakingRewardChange struct {
	Token0 string
	Token1 string
	Fee bigint
	NewStakingReward7 bigint
	NewStakingReward14 bigint
	NewStakingReward21 bigint
}

func SubmitProposalParameterStakingReward(
	title string,
	summary string,
	metadata string,
	initialDeposit bigint,

	// gno does not support array of structs for parameters of external functions
	// implement it once that is supported
	token0 string,
	token1 string,
	fee bigint,
	newStakingReward7 bigint,
	newStakingReward14 bigint,
	newStakingReward21 bigint,
) uint64 {
	if token0 == "" {
		return false
	}

	if token1 == "" {
		return false
	}

	if token0 >= token1 {
		return false
	}

	if fee == 0 {
		return false
	}

	if newStakingReward7 == 0 {
		return false
	}

	if newStakingReward14 == 0 {
		return false
	}

	if newStakingReward21 == 0 {
		return false
	}

	if newStakingReward7 > newStakingReward14 {
		return false
	}

	if newStakingReward14 > newStakingReward21 {
		return false
	}

	changes := []gov.ParameterChange{
		{
			Key: "staking_rewards:" + token0 + ":" + token1 + ":" + string(fee),
			Value: StakingRewards{
				StakingReward7: newStakingReward7,
				StakingReward14: newStakingReward14,
				StakingReward21: newStakingReward21,
			},
		}
	}

	return gov.SubmitProposalParameterChanges(
		title,
		summary,
		metadata,
		initialDeposit,
		changes,
	)
}