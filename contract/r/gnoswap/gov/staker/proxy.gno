package staker

import (
	"std"
)

// Delegation operations

func Delegate(to std.Address, amount int64, referrer string) int64 {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.Delegate(to.String(), amount, referrer)
}

func Undelegate(from std.Address, amount int64) int64 {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.Undelegate(from.String(), amount)
}

func Redelegate(delegatee, newDelegatee std.Address, amount int64) int64 {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.Redelegate(delegatee.String(), newDelegatee.String(), amount)
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

func CollectRewardFromLaunchPad(to std.Address) {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	impl.CollectRewardFromLaunchPad(to.String())
}

func SetAmountByProjectWallet(addr std.Address, amount int64, add bool) {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	impl.SetAmountByProjectWallet(addr.String(), amount, add)
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

func GetDelegationSnapshots(snapshotTime int64) (DelegationSnapshot, bool) {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.GetDelegationSnapshots(snapshotTime)
}

func GetClaimableRewardByAddress(addr std.Address) string {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.GetClaimableRewardByAddress(addr.String())
}

func GetClaimableRewardByLaunchpad(addr std.Address) string {
	impl := getImplementation()
	if impl == nil {
		panic("gov/staker: implementation not initialized")
	}
	return impl.GetClaimableRewardByLaunchpad(addr.String())
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
