package staker

// global state initialization
func init() {
	delegationState = NewDelegationState()
	historyState = NewHistoryState()
	rewardState = NewRewardState()
}

var (
	delegationState *DelegationState
	historyState    *HistoryState
	rewardState     *RewardState
)
