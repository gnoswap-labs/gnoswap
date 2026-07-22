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
//   - int64: delegation ID
func Delegate(cur realm, to address, amount int64, referrer string) int64 {
	return getImplementation().Delegate(0, cur, to, amount, referrer)
}

// Undelegate initiates the undelegation process for staked GNS.
//
// Parameters:
//   - from: delegatee address to undelegate from
//   - amount: amount of GNS to undelegate
//
// Returns:
//   - int64: undelegation result code
func Undelegate(cur realm, from address, amount int64) int64 {
	return getImplementation().Undelegate(0, cur, from, amount)
}

// Redelegate moves delegation from one delegatee to another.
//
// Parameters:
//   - delegatee: current delegatee address
//   - newDelegatee: new delegatee address
//   - amount: amount to redelegate
//
// Returns:
//   - int64: redelegation result code
func Redelegate(cur realm, delegatee, newDelegatee address, amount int64) int64 {
	return getImplementation().Redelegate(0, cur, delegatee, newDelegatee, amount)
}

// CollectUndelegatedGns collects GNS tokens after the undelegation lockup period.
//
// Returns:
//   - int64: amount of GNS collected
func CollectUndelegatedGns(cur realm) int64 {
	return getImplementation().CollectUndelegatedGns(0, cur)
}

// Reward operations

// CollectReward claims accumulated staking rewards.
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

// CollectRewardFromLaunchPad claims rewards from launchpad projects.
//
// Parameters:
//   - to: address to collect rewards for
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

// SetAmountByProjectWallet sets reward amount for a project wallet.
// Only callable by launchpad contract.
//
// Parameters:
//   - addr: project wallet address
//   - amount: reward amount
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
//   - threshold: timestamp threshold for cleanup
//   - target: user address whose delegation history to clean
func CleanStakerDelegationSnapshotByAdmin(cur realm, threshold int64, target address) {
	getImplementation().CleanStakerDelegationSnapshotByAdmin(0, cur, threshold, target)
}

// SetUnDelegationLockupPeriodByAdmin sets the undelegation lockup period.
// Only callable by admin.
//
// Parameters:
//   - period: lockup period in seconds
func SetUnDelegationLockupPeriodByAdmin(cur realm, period int64) {
	getImplementation().SetUnDelegationLockupPeriodByAdmin(0, cur, period)
}
