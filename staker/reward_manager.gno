package staker

type RewardManager struct {
	internalReward *InternalEmissionReward  // Internal Reward by Emission
	externalReward *ExternalIncentiveReward // External Reward by Incentive
}

func NewRewardManager() *RewardManager {
	return &RewardManager{
		internalReward: NewInternalEmissionReward(),
		externalReward: NewExternalIncentiveReward(),
	}
}

func (rm *RewardManager) SetInternalEmissionReward(internalReward *InternalEmissionReward) {
	rm.internalReward = internalReward
}

func (rm *RewardManager) GetInternalEmissionReward() *InternalEmissionReward {
	return rm.internalReward
}

func (rm *RewardManager) SetExternalIncentiveReward(externalReward *ExternalIncentiveReward) {
	rm.externalReward = externalReward
}

func (rm *RewardManager) GetExternalIncentiveReward() *ExternalIncentiveReward {
	return rm.externalReward
}
