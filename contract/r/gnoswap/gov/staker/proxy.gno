package staker

// Delegation operations

// Delegate delegates GNS to a delegate.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - to: The address to delegate.
//   - amount: The amount of GNS.
//   - referrer: The referrer address for reward tracking.
//
// Returns:
//   - delegationId: The ID of the delegation.
func Delegate(cur realm, to address, amount int64, referrer string) int64 {
	return getImplementation().Delegate(to, amount, referrer)
}

// Undelegate undelegates xGNS from the existing delegate.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - from: The address to undelegate.
//   - amount: The amount of xGNS.
//
// Returns:
//   - tokenId: The ID of the position.
func Undelegate(cur realm, from address, amount int64) int64 {
	return getImplementation().Undelegate(from, amount)
}

// Redelegate redelegates xGNS from the existing delegate to another.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - delegatee: The address to undelegate.
//   - newDelegatee: The address to delegate.
//   - amount: The amount of xGNS.
//
// Returns:
//   - resultCode: The redelegation result code.
func Redelegate(cur realm, delegatee, newDelegatee address, amount int64) int64 {
	return getImplementation().Redelegate(delegatee, newDelegatee, amount)
}

// CollectUndelegatedGns collects the amount of the undelegated GNS.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//
// Returns:
//   - amount: The amount of GNS token collected.
func CollectUndelegatedGns(cur realm) int64 {
	return getImplementation().CollectUndelegatedGns()
}

// Reward operations

// CollectReward collects the rewards from the protocol fee contract based on the holdings of xGNS.
//
// Parameters:
//   - cur: Pass `cross` as argument.
func CollectReward(cur realm) {
	getImplementation().CollectReward()
}

// CollectRewardFromLaunchPad collects the rewards from the protocol fee contract based on the holdings of xGNS in the launchpad contract (only callable by the launchpad contract).
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - to: The address to delegate.
func CollectRewardFromLaunchPad(cur realm, to address) {
	getImplementation().CollectRewardFromLaunchPad(to)
}

// SetAmountByProjectWallet sets reward amount for a project wallet.
// Only callable by launchpad contract.
//
// Parameters:
//   - cur: Pass `cross` as argument.
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
//   - cur: Pass `cross` as argument.
//   - threshold: timestamp threshold for cleanup
func CleanStakerDelegationSnapshotByAdmin(cur realm, threshold int64) {
	getImplementation().CleanStakerDelegationSnapshotByAdmin(threshold)
}

// SetUnDelegationLockupPeriodByAdmin sets the undelegation lockup period.
// Only callable by admin.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - period: lockup period in seconds
func SetUnDelegationLockupPeriodByAdmin(cur realm, period int64) {
	getImplementation().SetUnDelegationLockupPeriodByAdmin(period)
}
