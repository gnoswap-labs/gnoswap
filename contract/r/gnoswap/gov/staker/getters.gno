package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
	rotree "gno.land/p/nt/bptree/rotree/v0"
)

// GetTotalxGnsSupply returns total xGNS supply, including launchpad-held xGNS.
// Returns:
//   - int64: total xGNS supply, including xGNS held by launchpad projects.
func GetTotalxGnsSupply() int64 {
	return getImplementation().GetTotalxGnsSupply()
}

// GetTotalDelegated returns the total amount of GNS delegated.
// Returns:
//   - int64: total GNS amount delegated across all delegators.
func GetTotalDelegated() int64 {
	return getImplementation().GetTotalDelegated()
}

// GetTotalLockedAmount returns the total amount of GNS locked in undelegation.
// Returns:
//   - int64: total GNS amount currently locked in undelegation withdrawals.
func GetTotalLockedAmount() int64 {
	return getImplementation().GetTotalLockedAmount()
}

// GetUnDelegationLockupPeriod returns the undelegation lockup period in seconds.
// Returns:
//   - int64: configured undelegation lockup duration in seconds.
func GetUnDelegationLockupPeriod() int64 {
	return getImplementation().GetUnDelegationLockupPeriod()
}

// GetDelegations returns a read-only view of every delegation, keyed by the
// decimal string form of the delegation ID. Callers paginate it themselves
// through IterateByOffset. Reading an entry yields a clone, so the view cannot
// mutate realm state.
// Returns:
//   - *rotree.ReadOnlyTree: read-only delegation view keyed by decimal delegation ID; entry reads return clones.
func GetDelegations() *rotree.ReadOnlyTree {
	return getImplementation().GetDelegations()
}

// ExistsDelegation checks if a delegation exists.
// Parameters:
//   - delegationID: Numeric identifier of the delegation to look up.
//
// Returns:
//   - bool: true when a delegation with delegationID exists, false otherwise.
func ExistsDelegation(delegationID int64) bool {
	return getImplementation().ExistsDelegation(delegationID)
}

// GetDelegatorDelegations returns a read-only view of a delegator's delegations,
// keyed by delegatee address with that pair's delegation IDs as the value.
// Reading an entry yields a copy of the ID slice, so the view cannot mutate
// realm state. nil is returned when the delegator has no delegations.
// Parameters:
//   - delegator: Address whose delegations should be listed.
//
// Returns:
//   - *rotree.ReadOnlyTree: read-only view keyed by delegatee address, or nil when delegator has no delegations.
func GetDelegatorDelegations(delegator address) *rotree.ReadOnlyTree {
	return getImplementation().GetDelegatorDelegations(delegator)
}

// GetUserDelegationIDs returns a list of delegation IDs for a specific delegator-delegatee pair.
// Parameters:
//   - delegator: Address that supplied the delegation.
//   - delegatee: Address receiving that delegation.
//
// Returns:
//   - []int64: delegation IDs for the delegator-delegatee pair; the returned slice is independent of realm state.
func GetUserDelegationIDs(delegator address, delegatee address) []int64 {
	return cloneInt64Slice(getImplementation().GetUserDelegationIDs(delegator, delegatee))
}

// HasDelegationSnapshotsKey returns true if delegation history exists.
// Returns:
//   - bool: true when delegation history has been initialized in storage.
func HasDelegationSnapshotsKey() bool {
	return getImplementation().HasDelegationSnapshotsKey()
}

// GetTotalDelegationAmountAtSnapshot returns total delegation at a Unix
// timestamp, using the latest history entry at or before that timestamp.
// The lookup is timestamp-based rather than a block-height snapshot.
// Parameters:
//   - snapshotTime: Unix timestamp at or before which to select the latest aggregate delegation history entry.
//
// Returns:
//   - int64: aggregate delegated amount recorded at or before snapshotTime.
//   - bool: true when a qualifying history entry exists; false when no entry is available.
func GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool) {
	return getImplementation().GetTotalDelegationAmountAtSnapshot(snapshotTime)
}

// GetUserDelegationAmountAtSnapshot returns one user's delegation at a Unix
// timestamp, using that user's latest history entry at or before the timestamp.
// The bool is false when no qualifying history entry exists.
// Parameters:
//   - userAddr: Delegator address whose historical delegation is queried.
//   - snapshotTime: Unix timestamp at or before which to select the user's latest history entry.
//
// Returns:
//   - int64: user's delegated amount recorded at or before snapshotTime.
//   - bool: true when a qualifying user-history entry exists; false otherwise.
func GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool) {
	return getImplementation().GetUserDelegationAmountAtSnapshot(userAddr, snapshotTime)
}

// GetClaimableRewardByAddress returns claimable rewards for an address.
//
// Parameters:
//   - addr: Address whose emission and protocol-fee rewards are queried.
//
// Returns:
//   - int64: emission reward amount available to addr.
//   - map[string]int64: protocol-fee reward amounts keyed by token path.
//   - error: nil on success; non-nil when reward state cannot be resolved for addr.
func GetClaimableRewardByAddress(addr address) (int64, map[string]int64, error) {
	emissionReward, protocolFees, err := getImplementation().GetClaimableRewardByAddress(addr)
	if err != nil {
		return 0, nil, err
	}
	return emissionReward, cloneStringInt64Map(protocolFees), nil
}

// GetClaimableRewardByLaunchpad returns claimable launchpad rewards for an address.
//
// Parameters:
//   - addr: Address whose launchpad and protocol-fee rewards are queried.
//
// Returns:
//   - int64: emission reward amount available to addr.
//   - map[string]int64: protocol-fee reward amounts keyed by token path.
//   - error: nil on success; non-nil when reward state cannot be resolved for addr.
func GetClaimableRewardByLaunchpad(addr address) (int64, map[string]int64, error) {
	emissionReward, protocolFees, err := getImplementation().GetClaimableRewardByLaunchpad(addr)
	if err != nil {
		return 0, nil, err
	}
	return emissionReward, cloneStringInt64Map(protocolFees), nil
}

// GetClaimableRewardByRewardID returns claimable reward details by reward ID.
//
// Parameters:
//   - rewardID: Reward-state identifier whose claimable rewards are queried.
//
// Returns:
//   - int64: emission reward amount associated with rewardID.
//   - map[string]int64: protocol-fee reward amounts keyed by token path.
//   - error: nil on success; non-nil when rewardID cannot be resolved.
func GetClaimableRewardByRewardID(rewardID string) (int64, map[string]int64, error) {
	emissionReward, protocolFees, err := getImplementation().GetClaimableRewardByRewardID(rewardID)
	if err != nil {
		return 0, nil, err
	}
	return emissionReward, cloneStringInt64Map(protocolFees), nil
}

// GetLaunchpadProjectDeposit returns the deposit amount for a launchpad project.
// Parameters:
//   - projectAddr: Launchpad project address whose deposited amount is queried.
//
// Returns:
//   - int64: recorded launchpad project deposit amount.
//   - bool: true when a deposit record exists for projectAddr; false otherwise.
func GetLaunchpadProjectDeposit(projectAddr string) (int64, bool) {
	return getImplementation().GetLaunchpadProjectDeposit(projectAddr)
}

// GetDelegationWithdrawCount returns the total number of delegation withdraws for a specific delegation.
// Parameters:
//   - delegationID: Identifier of the delegation whose withdrawals are counted.
//
// Returns:
//   - int: number of withdrawal records associated with delegationID.
func GetDelegationWithdrawCount(delegationID int64) int {
	return getImplementation().GetDelegationWithdrawCount(delegationID)
}

// GetDelegationWithdraws returns a paginated list of delegation withdraws for a specific delegation.
// Parameters:
//   - delegationID: Identifier of the delegation whose withdrawals are requested.
//   - offset: Number of matching withdrawal records to skip before collecting results.
//   - count: Maximum number of withdrawal records to return.
//
// Returns:
//   - []DelegationWithdraw: requested page of withdrawal records, copied before returning.
//   - error: nil on success; non-nil when the requested delegation or page cannot be read.
func GetDelegationWithdraws(delegationID int64, offset, count int) ([]DelegationWithdraw, error) {
	withdraws, err := getImplementation().GetDelegationWithdraws(delegationID, offset, count)
	if err != nil {
		return nil, err
	}
	return cloneDelegationWithdraws(withdraws), nil
}

// GetCollectableWithdrawAmount returns the collectable withdraw amount for a specific delegation.
// Parameters:
//   - delegationID: Identifier of the delegation whose collectable amount is queried.
//
// Returns:
//   - int64: amount currently available to collect from delegationID.
func GetCollectableWithdrawAmount(delegationID int64) int64 {
	return getImplementation().GetCollectableWithdrawAmount(delegationID)
}

// GetProtocolFeeAccumulatedX128PerStake returns the accumulated protocol fee per stake (Q128) for a token path.
// Parameters:
//   - tokenPath: Registered token path whose protocol-fee accumulator is queried.
//
// Returns:
//   - *u256.Uint: accumulated protocol-fee amount per unit stake in Q128 fixed-point form.
func GetProtocolFeeAccumulatedX128PerStake(tokenPath string) *u256.Uint {
	return getImplementation().GetProtocolFeeAccumulatedX128PerStake(tokenPath).Clone()
}

// GetProtocolFeeAmount returns the protocol fee amounts for a token path.
// Parameters:
//   - tokenPath: Registered token path whose protocol fees are queried.
//
// Returns:
//   - int64: accumulated protocol-fee amount for tokenPath in token base units.
func GetProtocolFeeAmount(tokenPath string) int64 {
	return getImplementation().GetProtocolFeeAmount(tokenPath)
}

// GetProtocolFeeAccumulatedTimestamp returns the accumulated timestamp for protocol fee rewards.
// Returns:
//   - int64: Unix timestamp at which protocol-fee accumulation was last updated.
func GetProtocolFeeAccumulatedTimestamp() int64 {
	return getImplementation().GetProtocolFeeAccumulatedTimestamp()
}

// GetEmissionAccumulatedX128PerStake returns the accumulated emission per stake (Q128).
// Returns:
//   - *u256.Uint: accumulated emission reward per unit stake in Q128 fixed-point form.
func GetEmissionAccumulatedX128PerStake() *u256.Uint {
	return getImplementation().GetEmissionAccumulatedX128PerStake().Clone()
}

// GetEmissionDistributedAmount returns the total distributed emission amount.
// Returns:
//   - int64: total emission amount distributed to stakers.
func GetEmissionDistributedAmount() int64 {
	return getImplementation().GetEmissionDistributedAmount()
}

// GetEmissionAccumulatedTimestamp returns the accumulated timestamp for emission rewards.
// Returns:
//   - int64: Unix timestamp at which emission accumulation was last updated.
func GetEmissionAccumulatedTimestamp() int64 {
	return getImplementation().GetEmissionAccumulatedTimestamp()
}
