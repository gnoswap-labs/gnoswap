package staker

// ExternalIncentiveReward ...
// External incentive reward 분배를 위한 구조체
// --- External Reward ---
// 7. 전체 Pool중 External Reward 대상 Pool을 선별
// 8. External Reward 대상 Pool에 대해서, Reward대상자를 선별
// 9. External Reward 대상자에게 Reward를 분배
type ExternalIncentiveReward struct {
	externalReward *ExternalCalculator
}

func NewExternalIncentiveReward() *ExternalIncentiveReward {
	return &ExternalIncentiveReward{}
}

func (eir *ExternalIncentiveReward) SetExternalCalculator(externalReward *ExternalCalculator) {
	eir.externalReward = externalReward
}

func (eir *ExternalIncentiveReward) GetExternalCalculator() *ExternalCalculator {
	return eir.externalReward
}
