package staker

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
	return getImplementation().GetDelegationSnapshots(snapshotTime)
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
