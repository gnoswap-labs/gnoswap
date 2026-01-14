package staker

// Delegation operations

// Delegate stakes GNS tokens to a delegatee address.
//
// Parameters:
//   - to: address to delegate to
//   - amount: amount of GNS to delegate
//   - referrer: referrer address for reward tracking
//
// Returns:
//   - delegationId: delegation ID
func Delegate(cur realm, to address, amount int64, referrer string) int64 {
	return getImplementation().Delegate(to, amount, referrer)
}

// Undelegate initiates the undelegation process for staked GNS.
//
// Parameters:
//   - from: delegatee address to undelegate from
//   - amount: amount of GNS to undelegate
//
// Returns:
//   - resultCode: undelegation result code
func Undelegate(cur realm, from address, amount int64) int64 {
	return getImplementation().Undelegate(from, amount)
}

// Redelegate moves delegation from one delegatee to another.
//
// Parameters:
//   - delegatee: current delegatee address
//   - newDelegatee: new delegatee address
//   - amount: amount to redelegate
//
// Returns:
//   - resultCode: redelegation result code
func Redelegate(cur realm, delegatee, newDelegatee address, amount int64) int64 {
	return getImplementation().Redelegate(delegatee, newDelegatee, amount)
}

// CollectUndelegatedGns collects GNS tokens after the undelegation lockup period.
//
// Returns:
//   - amount: amount of GNS collected
func CollectUndelegatedGns(cur realm) int64 {
	return getImplementation().CollectUndelegatedGns()
}

// Reward operations

// CollectReward claims accumulated staking rewards.
func CollectReward(cur realm) {
	getImplementation().CollectReward()
}

// CollectRewardFromLaunchPad claims rewards from launchpad projects.
//
// Parameters:
//   - to: address to collect rewards for
func CollectRewardFromLaunchPad(cur realm, to address) {
	getImplementation().CollectRewardFromLaunchPad(to)
}

// SetAmountByProjectWallet sets reward amount for a project wallet.
// Only callable by launchpad contract.
//
// Parameters:
//   - addr: project wallet address
//   - amount: reward amount
//   - add: true to add, false to subtract
func SetAmountByProjectWallet(cur realm, addr address, amount int64, add bool) {
	getImplementation().SetAmountByProjectWallet(addr, amount, add)
}

// Admin functions

// CleanStakerDelegationSnapshotByAdmin removes old delegation snapshots.
// Only callable by admin.
//
// Parameters:
//   - threshold: timestamp threshold for cleanup
func CleanStakerDelegationSnapshotByAdmin(cur realm, threshold int64) {
	getImplementation().CleanStakerDelegationSnapshotByAdmin(threshold)
}

// SetUnDelegationLockupPeriodByAdmin sets the undelegation lockup period.
// Only callable by admin.
//
// Parameters:
//   - period: lockup period in seconds
func SetUnDelegationLockupPeriodByAdmin(cur realm, period int64) {
	getImplementation().SetUnDelegationLockupPeriodByAdmin(period)
}
