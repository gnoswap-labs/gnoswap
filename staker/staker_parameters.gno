package staker

import (
	"gno.land/p/demo/ufmt"
	"gno.land/r/gov"
)

func Init() {
	setInflationRate(defaultInflationRate())
}

func defaultInflationRate() bigint {
	return 0 // TODO
}

func getInflationRate() bigint {
	param, ok := gov.GetParameter("inflation_rate")
	if !ok {
		panic(ufmt.Sprintf("[STAKER] staker_parameters.gno__getInflationRate() || inflation(%s) rate not set"))
	}

	return param.(bigint)
}

func setInflationRate(newRate bigint) {
	gov.SetGovParameter("inflation_rate", newRate)
}

func defaultStakingRewards() StakingRewards {
	// TODO
	return StakingRewards{
		Tier1: 100,
		Tier2: 70,
		Tier3: 50,
		Tier4: 30,
	}
}

func getStakingRewards() StakingRewards {
	param, ok := gov.GetParameter("staking_rewards")
	if !ok {
		return defaultStakingRewards()
	}

	return param.(StakingRewards)
}

func SubmitProposalParameterStakingReward(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,

	// gno does not support array of structs for parameters of external functions
	// implement it once that is supported
	newStakingReward1 uint8,
	newStakingReward2 uint8,
	newStakingReward3 uint8,
	newStakingReward4 uint8,
) uint64 {

	if newStakingReward1 == 0 {
		return false
	}

	if newStakingReward2 == 0 {
		return false
	}

	if newStakingReward3 == 0 {
		return false
	}

	if newStakingReward4 == 0 {
		return false
	}

	if newStakingReward1 < newStakingReward2 {
		return false
	}

	if newStakingReward2 < newStakingReward3 {
		return false
	}

	if newStakingReward3 < newStakingReward4 {
		return false
	}

	changes := []gov.ParameterChange{
		{
			Key: "staking_rewards",
			Value: StakingRewards{
				Tier1: newStakingReward1,
				Tier2: newStakingReward2,
				Tier3: newStakingReward3,
				Tier4: newStakingReward4,
			},
		},
	}

	return gov.SubmitProposalParameterChanges(
		title,
		summary,
		metadata,
		initialDeposit,
		changes,
	)
}
