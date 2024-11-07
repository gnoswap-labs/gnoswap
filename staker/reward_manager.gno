package staker

type RewardManager struct {
	// 1. InternalEmissionReward
	internalReward *InternalEmissionReward
	// 2. ExternalIncentiveReward
	externalReward *ExternalIncentiveReward
}

func NewRewardManager() *RewardManager {
	return &RewardManager{
		internalReward: NewInternalEmissionReward(),
		externalReward: NewExternalIncentiveReward(),
	}
}

func (rm *RewardManager) SetInternalReward(internalReward *InternalEmissionReward) {
	rm.internalReward = internalReward
}

func (rm *RewardManager) GetInternalReward() *InternalEmissionReward {
	return rm.internalReward
}

func (rm *RewardManager) SetExternalReward(externalReward *ExternalIncentiveReward) {
	rm.externalReward = externalReward
}

func (rm *RewardManager) GetExternalReward() *ExternalIncentiveReward {
	return rm.externalReward
}
