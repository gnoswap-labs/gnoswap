package staker

// GetTotalxGnsSupply returns the total supply of xGNS tokens.
func GetTotalxGnsSupply() int64 {
	return getImplementation().GetTotalxGnsSupply()
}

// GetTotalVoteWeight returns the total voting weight in the system.
func GetTotalVoteWeight() int64 {
	return getImplementation().GetTotalVoteWeight()
}

// GetTotalDelegated returns the total amount of GNS delegated.
func GetTotalDelegated() int64 {
	return getImplementation().GetTotalDelegated()
}

// GetTotalLockedAmount returns the total amount of GNS locked in undelegation.
func GetTotalLockedAmount() int64 {
	return getImplementation().GetTotalLockedAmount()
}

// GetLockedAmount returns the caller's locked GNS amount.
func GetLockedAmount() int64 {
	return getImplementation().GetLockedAmount()
}

// GetTotalDelegationAmountAtSnapshot returns the total delegation amount at a specific snapshot time.
func GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool) {
	return getImplementation().GetTotalDelegationAmountAtSnapshot(snapshotTime)
}

// GetUserDelegationAmountAtSnapshot returns the user delegation amount at a specific snapshot time.
func GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool) {
	return getImplementation().GetUserDelegationAmountAtSnapshot(userAddr, snapshotTime)
}

// GetClaimableRewardByAddress returns claimable rewards for an address.
func GetClaimableRewardByAddress(addr address) string {
	return getImplementation().GetClaimableRewardByAddress(addr)
}

// GetClaimableRewardByLaunchpad returns claimable launchpad rewards for an address.
func GetClaimableRewardByLaunchpad(addr address) string {
	return getImplementation().GetClaimableRewardByLaunchpad(addr)
}

// GetClaimableRewardByRewardID returns claimable reward details by reward ID.
func GetClaimableRewardByRewardID(rewardID string) string {
	return getImplementation().GetClaimableRewardByRewardID(rewardID)
}
