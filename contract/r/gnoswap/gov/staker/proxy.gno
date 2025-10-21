package staker

// Delegation operations

func Delegate(to address, amount int64, referrer string) int64 {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.Delegate(to, amount, referrer)
}

func Undelegate(from address, amount int64) int64 {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.Undelegate(from, amount)
}

func Redelegate(delegatee, newDelegatee address, amount int64) int64 {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.Redelegate(delegatee, newDelegatee, amount)
}

func CollectUndelegatedGns() int64 {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.CollectUndelegatedGns()
}

// Reward operations

func CollectReward() {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	impl.CollectReward()
}

func CollectRewardFromLaunchPad(to address) {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	impl.CollectRewardFromLaunchPad(to)
}

func SetAmountByProjectWallet(addr address, amount int64, add bool) {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	impl.SetAmountByProjectWallet(addr, amount, add)
}

// Getter functions

func GetTotalxGnsSupply() int64 {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.GetTotalxGnsSupply()
}

func GetTotalVoteWeight() int64 {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.GetTotalVoteWeight()
}

func GetTotalDelegated() int64 {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.GetTotalDelegated()
}

func GetTotalLockedAmount() int64 {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.GetTotalLockedAmount()
}

func GetLockedAmount() int64 {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.GetLockedAmount()
}

// func GetDelegationSnapshots(snapshotTime int64) (DelegationSnapshot, bool) {
// 	impl := getImplementation()
// 	if impl == nil {
// 		panic("gov/staker: implementation not initialized")
// 	}
// 	return impl.GetDelegationSnapshots(snapshotTime)
// }

func GetClaimableRewardByAddress(addr address) string {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.GetClaimableRewardByAddress(addr)
}

func GetClaimableRewardByLaunchpad(addr address) string {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.GetClaimableRewardByLaunchpad(addr)
}

func GetClaimableRewardByRewardID(rewardID string) string {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.GetClaimableRewardByRewardID(rewardID)
}

// Admin functions

func CleanStakerDelegationSnapshotByAdmin(threshold int64) {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	impl.CleanStakerDelegationSnapshotByAdmin(threshold)
}

func SetUnDelegationLockupPeriodByAdmin(period int64) {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	impl.SetUnDelegationLockupPeriodByAdmin(period)
}
