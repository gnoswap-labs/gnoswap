package staker

// Delegation operations

func Delegate(cur realm, to address, amount int64, referrer string) int64 {
	return getImplementation().Delegate(to, amount, referrer)
}

func Undelegate(cur realm, from address, amount int64) int64 {
	return getImplementation().Undelegate(from, amount)
}

func Redelegate(cur realm, delegatee, newDelegatee address, amount int64) int64 {
	return getImplementation().Redelegate(delegatee, newDelegatee, amount)
}

func CollectUndelegatedGns(cur realm) int64 {
	return getImplementation().CollectUndelegatedGns()
}

// Reward operations

func CollectReward(cur realm) {
	getImplementation().CollectReward()
}

func CollectRewardFromLaunchPad(cur realm, to address) {
	getImplementation().CollectRewardFromLaunchPad(to)
}

func SetAmountByProjectWallet(cur realm, addr address, amount int64, add bool) {
	getImplementation().SetAmountByProjectWallet(addr, amount, add)
}

// Getter functions

func GetTotalxGnsSupply() int64 {
	return getImplementation().GetTotalxGnsSupply()
}

func GetTotalVoteWeight() int64 {
	return getImplementation().GetTotalVoteWeight()
}

func GetTotalDelegated() int64 {
	return getImplementation().GetTotalDelegated()
}

func GetTotalLockedAmount() int64 {
	return getImplementation().GetTotalLockedAmount()
}

func GetLockedAmount() int64 {
	return getImplementation().GetLockedAmount()
}

func GetDelegationSnapshots(snapshotTime int64) (DelegationSnapshot, bool) {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.GetDelegationSnapshots(snapshotTime)
}

func GetClaimableRewardByAddress(addr address) string {
	return getImplementation().GetClaimableRewardByAddress(addr)
}

func GetClaimableRewardByLaunchpad(addr address) string {
	return getImplementation().GetClaimableRewardByLaunchpad(addr)
}

func GetClaimableRewardByRewardID(rewardID string) string {
	return getImplementation().GetClaimableRewardByRewardID(rewardID)
}

// Admin functions

func CleanStakerDelegationSnapshotByAdmin(cur realm, threshold int64) {
	getImplementation().CleanStakerDelegationSnapshotByAdmin(threshold)
}

func SetUnDelegationLockupPeriodByAdmin(cur realm, period int64) {
	getImplementation().SetUnDelegationLockupPeriodByAdmin(period)
}
