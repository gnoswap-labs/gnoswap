package staker

// Delegation operations

// Delegate delegates GNS to a delegate.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - to: delegatee address that receives voting power
//   - amount: positive GNS amount to delegate and convert to xGNS voting power
//   - referrer: optional referral identifier to register for reward tracking
//
// Returns:
//   - delegatedAmount: The amount of GNS delegated and mirrored as xGNS.
//
// Halt check: reverts while the GovStaker halt scope is active.
func Delegate(cur realm, to address, amount int64, referrer string) int64 {
	return getImplementation().Delegate(0, cur, to, amount, referrer)
}

// Undelegate undelegates xGNS from the existing delegate.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - from: delegatee address from which the caller removes delegation
//   - amount: positive xGNS amount to move into undelegation lockup
//
// Returns:
//   - amount: The amount of GNS moved into undelegation lockup.
//
// Halt check: reverts while the Withdraw halt scope is active.
func Undelegate(cur realm, from address, amount int64) int64 {
	return getImplementation().Undelegate(0, cur, from, amount)
}

// Redelegate redelegates xGNS from the existing delegate to another.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - delegatee: current delegatee address whose voting power is reduced
//   - newDelegatee: destination address that receives the redelegated voting power
//   - amount: positive xGNS amount to move without a user-facing lockup
//
// Returns:
//   - redelegatedAmount: The amount moved from the current delegatee to the new delegatee.
//
// Halt check: reverts while the GovStaker halt scope is active.
func Redelegate(cur realm, delegatee, newDelegatee address, amount int64) int64 {
	return getImplementation().Redelegate(0, cur, delegatee, newDelegatee, amount)
}

// CollectUndelegatedGns collects the amount of the undelegated GNS.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//
// Returns:
//   - amount: GNS amount released to the caller after eligible undelegation withdrawals are collected
//
// Halt check: reverts while the Withdraw halt scope is active.
func CollectUndelegatedGns(cur realm) int64 {
	return getImplementation().CollectUndelegatedGns(0, cur)
}

// Reward operations

// CollectReward claims the caller's GNS emission reward and all known
// protocol-fee token rewards.
//
// The all-token path folds and settles every known token. It is not a
// single-current-xGNS-balance formula.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//
// Halt check: reverts while the Withdraw halt scope is active.
func CollectReward(cur realm) {
	getImplementation().CollectReward(0, cur)
}

// CollectEmissionReward claims the caller's accumulated GNS emission reward.
//
// The call is subject to the withdrawal halt and transfers GNS when a reward
// is available.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//
// Halt check: reverts while the Withdraw halt scope is active.
func CollectEmissionReward(cur realm) {
	getImplementation().CollectEmissionReward(0, cur)
}

// CollectProtocolFeeReward claims accumulated protocol-fee rewards for one
// registered token path. Folding and settlement are bounded per call; any
// remaining buckets or stake events are collected by a later call.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - tokenPath: registered token path whose accumulated protocol-fee reward is claimed
//
// Halt check: reverts while the Withdraw halt scope is active.
func CollectProtocolFeeReward(cur realm, tokenPath string) {
	getImplementation().CollectProtocolFeeReward(0, cur, tokenPath)
}

// CollectRewardFromLaunchPad claims both GNS emission and protocol-fee rewards
// for a registered launchpad project wallet. Only the launchpad contract may
// call this entry point.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - to: registered launchpad project wallet that receives both reward streams
//
// Halt check: reverts while the Withdraw halt scope is active.
func CollectRewardFromLaunchPad(cur realm, to address) {
	getImplementation().CollectRewardFromLaunchPad(0, cur, to)
}

// CollectEmissionRewardFromLaunchPad claims only accumulated GNS emission
// rewards for a registered launchpad project wallet.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - to: registered launchpad project wallet whose emission reward is claimed
//
// Halt check: reverts while the Withdraw halt scope is active.
func CollectEmissionRewardFromLaunchPad(cur realm, to address) {
	getImplementation().CollectEmissionRewardFromLaunchPad(0, cur, to)
}

// CollectProtocolFeeRewardFromLaunchPad claims one token path of accumulated
// protocol-fee rewards for a registered launchpad project wallet.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - to: registered launchpad project wallet whose protocol-fee reward is claimed
//   - tokenPath: registered token path whose accumulated protocol-fee reward is claimed
//
// Halt check: reverts while the Withdraw halt scope is active.
func CollectProtocolFeeRewardFromLaunchPad(cur realm, to address, tokenPath string) {
	getImplementation().CollectProtocolFeeRewardFromLaunchPad(0, cur, to, tokenPath)
}

// SetAmountByProjectWallet adjusts launchpad-backed stake and xGNS accounting for a project wallet.
// Only callable by launchpad contract.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - addr: registered project wallet whose launchpad-backed stake is adjusted
//   - amount: stake amount delta passed to the launchpad reward accounting
//   - add: true to add stake and mint xGNS; false to remove stake and burn xGNS
//
// Halt check: reverts while the GovStaker halt scope is active when add is true, or while the Withdraw halt scope is active when add is false.
func SetAmountByProjectWallet(cur realm, addr address, amount int64, add bool) {
	getImplementation().SetAmountByProjectWallet(0, cur, addr, amount, add)
}

// Admin functions

// CleanStakerDelegationSnapshotByAdmin removes old delegation snapshots for the
// total history and the user history of a single target address.
// Only callable by admin.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - threshold: Unix timestamp cutoff for removing eligible old delegation history
//   - target: user address whose delegation history to clean
//
// Halt check: reverts while the GovStaker halt scope is active.
func CleanStakerDelegationSnapshotByAdmin(cur realm, threshold int64, target address) {
	getImplementation().CleanStakerDelegationSnapshotByAdmin(0, cur, threshold, target)
}

// SetUnDelegationLockupPeriodByAdmin sets the undelegation lockup period.
// Only callable by admin.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - period: non-negative undelegation lockup duration in seconds
//
// Halt check: reverts while the GovStaker halt scope is active.
func SetUnDelegationLockupPeriodByAdmin(cur realm, period int64) {
	getImplementation().SetUnDelegationLockupPeriodByAdmin(0, cur, period)
}
