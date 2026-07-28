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
//   - delegatedAmount: The amount of GNS delegated and mirrored as xGNS.
func Delegate(cur realm, to address, amount int64, referrer string) int64 {
	return getImplementation().Delegate(0, cur, to, amount, referrer)
}

// Undelegate undelegates xGNS from the existing delegate.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - from: The address to undelegate.
//   - amount: The amount of xGNS.
//
// Returns:
//   - amount: The amount of GNS moved into undelegation lockup.
func Undelegate(cur realm, from address, amount int64) int64 {
	return getImplementation().Undelegate(0, cur, from, amount)
}

// Redelegate redelegates xGNS from the existing delegate to another.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - delegatee: The current delegatee address.
//   - newDelegatee: The new delegatee address.
//   - amount: The amount of xGNS.
//
// Returns:
//   - redelegatedAmount: The amount moved from the current delegatee to the new delegatee.
func Redelegate(cur realm, delegatee, newDelegatee address, amount int64) int64 {
	return getImplementation().Redelegate(0, cur, delegatee, newDelegatee, amount)
}

// CollectUndelegatedGns collects the amount of the undelegated GNS.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//
// Returns:
//   - amount: The amount of GNS token collected.
func CollectUndelegatedGns(cur realm) int64 {
	return getImplementation().CollectUndelegatedGns(0, cur)
}

// Reward operations

// CollectReward collects the rewards from the protocol fee contract based on the holdings of xGNS.
//
// Parameters:
//   - cur: Pass `cross` as argument.
func CollectReward(cur realm) {
	getImplementation().CollectReward(0, cur)
}

// CollectEmissionReward claims accumulated GNS emission rewards.
func CollectEmissionReward(cur realm) {
	getImplementation().CollectEmissionReward(0, cur)
}

// CollectProtocolFeeReward claims accumulated protocol fee rewards for the provided token path.
func CollectProtocolFeeReward(cur realm, tokenPath string) {
	getImplementation().CollectProtocolFeeReward(0, cur, tokenPath)
}

// CollectRewardFromLaunchPad collects the rewards from the protocol fee contract based on the holdings of xGNS in the launchpad contract (only callable by the launchpad contract).
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - to: The recipient project wallet address.
func CollectRewardFromLaunchPad(cur realm, to address) {
	getImplementation().CollectRewardFromLaunchPad(0, cur, to)
}

// CollectEmissionRewardFromLaunchPad claims accumulated launchpad emission rewards.
//
// Parameters:
//   - to: address to collect rewards for
func CollectEmissionRewardFromLaunchPad(cur realm, to address) {
	getImplementation().CollectEmissionRewardFromLaunchPad(0, cur, to)
}

// CollectProtocolFeeRewardFromLaunchPad claims accumulated launchpad protocol fee rewards for the provided token path.
//
// Parameters:
//   - to: address to collect rewards for
//   - tokenPath: token path to collect
func CollectProtocolFeeRewardFromLaunchPad(cur realm, to address, tokenPath string) {
	getImplementation().CollectProtocolFeeRewardFromLaunchPad(0, cur, to, tokenPath)
}

// SetAmountByProjectWallet adjusts launchpad-backed stake and xGNS accounting for a project wallet.
// Only callable by launchpad contract.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - addr: project wallet address
//   - amount: stake amount delta to add or remove
//   - add: true to add, false to subtract
func SetAmountByProjectWallet(cur realm, addr address, amount int64, add bool) {
	getImplementation().SetAmountByProjectWallet(0, cur, addr, amount, add)
}

// Admin functions

// CleanStakerDelegationSnapshotByAdmin removes old delegation snapshots for the
// total history and the user history of a single target address.
// Only callable by admin.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - threshold: timestamp threshold for cleanup
//   - target: user address whose delegation history to clean
func CleanStakerDelegationSnapshotByAdmin(cur realm, threshold int64, target address) {
	getImplementation().CleanStakerDelegationSnapshotByAdmin(0, cur, threshold, target)
}

// SetUnDelegationLockupPeriodByAdmin sets the undelegation lockup period.
// Only callable by admin.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - period: lockup period in seconds
func SetUnDelegationLockupPeriodByAdmin(cur realm, period int64) {
	getImplementation().SetUnDelegationLockupPeriodByAdmin(0, cur, period)
}
