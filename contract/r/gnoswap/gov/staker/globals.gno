package staker

// global state initialization
func init() {
	delegationState = newDelegationState()
	historyState = newHistoryState()
	rewardState = NewRewardState()
}

var (
	delegationState *DelegationState
	historyState    *HistoryState
	rewardState     *RewardState
)
