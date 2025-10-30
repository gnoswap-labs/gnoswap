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

// Admin functions

func CleanStakerDelegationSnapshotByAdmin(cur realm, threshold int64) {
	getImplementation().CleanStakerDelegationSnapshotByAdmin(threshold)
}

func SetUnDelegationLockupPeriodByAdmin(cur realm, period int64) {
	getImplementation().SetUnDelegationLockupPeriodByAdmin(period)
}
