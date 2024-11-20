package staker

// ExternalIncentiveReward
type ExternalIncentiveReward struct {
	externalReward *ExternalCalculator
}

func NewExternalIncentiveReward() *ExternalIncentiveReward {
	return &ExternalIncentiveReward{
		externalReward: NewExternalCalculator(0),
	}
}

func (eir *ExternalIncentiveReward) SetExternalCalculator(externalReward *ExternalCalculator) {
	eir.externalReward = externalReward
}

func (eir *ExternalIncentiveReward) GetExternalCalculator() *ExternalCalculator {
	return eir.externalReward
}

func (eir *ExternalIncentiveReward) GetOrCreateExternalCalculator(currHeight int64) *ExternalCalculator {
	if eir.externalReward == nil {
		eir.externalReward = NewExternalCalculator(currHeight)
	}
	return eir.externalReward
}
