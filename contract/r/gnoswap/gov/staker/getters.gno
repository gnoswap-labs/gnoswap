package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
)

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

// GetLockedAmount returns the total locked GNS amount.
func GetLockedAmount() int64 {
	return getImplementation().GetLockedAmount()
}

// GetUnDelegationLockupPeriod returns the undelegation lockup period in seconds.
func GetUnDelegationLockupPeriod() int64 {
	return getImplementation().GetUnDelegationLockupPeriod()
}

// GetEmissionRewardBalance returns the current emission reward balance.
func GetEmissionRewardBalance() int64 {
	return getImplementation().GetEmissionRewardBalance()
}

// GetDelegationCount returns the total number of delegations.
func GetDelegationCount() int {
	return getImplementation().GetDelegationCount()
}

// GetDelegationIDs returns a paginated list of delegation IDs.
func GetDelegationIDs(offset, count int) []int64 {
	return getImplementation().GetDelegationIDs(offset, count)
}

// ExistsDelegation checks if a delegation exists.
func ExistsDelegation(delegationID int64) bool {
	return getImplementation().ExistsDelegation(delegationID)
}

// GetDelegation returns the delegation for the given ID.
func GetDelegation(delegationID int64) (*Delegation, error) {
	delegation, err := getImplementation().GetDelegation(delegationID)
	if err != nil {
		return nil, err
	}
	return delegation.Clone(), nil
}

// GetDelegatorDelegationCount returns the number of delegations for a specific delegator.
func GetDelegatorDelegationCount(delegator address) int {
	return getImplementation().GetDelegatorDelegationCount(delegator)
}

// GetDelegatorDelegationIDs returns a paginated list of delegation IDs for a specific delegator.
func GetDelegatorDelegationIDs(delegator address, offset, count int) []int64 {
	return getImplementation().GetDelegatorDelegationIDs(delegator, offset, count)
}

// HasDelegationSnapshotsKey returns true if delegation history exists.
func HasDelegationSnapshotsKey() bool {
	return getImplementation().HasDelegationSnapshotsKey()
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
//
// Returns:
//   - int64: emission reward amount
//   - map[string]int64: protocol fee rewards by token path
func GetClaimableRewardByAddress(addr address) (int64, map[string]int64, error) {
	return getImplementation().GetClaimableRewardByAddress(addr)
}

// GetClaimableRewardByLaunchpad returns claimable launchpad rewards for an address.
//
// Returns:
//   - int64: emission reward amount
//   - map[string]int64: protocol fee rewards by token path
func GetClaimableRewardByLaunchpad(addr address) (int64, map[string]int64, error) {
	return getImplementation().GetClaimableRewardByLaunchpad(addr)
}

// GetClaimableRewardByRewardID returns claimable reward details by reward ID.
//
// Returns:
//   - int64: emission reward amount
//   - map[string]int64: protocol fee rewards by token path
func GetClaimableRewardByRewardID(rewardID string) (int64, map[string]int64, error) {
	return getImplementation().GetClaimableRewardByRewardID(rewardID)
}

// GetLaunchpadProjectDeposit returns the deposit amount for a launchpad project.
func GetLaunchpadProjectDeposit(projectAddr string) (int64, bool) {
	return getImplementation().GetLaunchpadProjectDeposit(projectAddr)
}

// GetDelegationWithdrawCount returns the total number of delegation withdraws for a specific delegation.
func GetDelegationWithdrawCount(delegationID int64) int {
	return getImplementation().GetDelegationWithdrawCount(delegationID)
}

// GetDelegationWithdraws returns a paginated list of delegation withdraws for a specific delegation.
func GetDelegationWithdraws(delegationID int64, offset, count int) ([]*DelegationWithdraw, error) {
	return getImplementation().GetDelegationWithdraws(delegationID, offset, count)
}

// GetCollectableWithdrawAmount returns the collectable withdraw amount for a specific delegation.
func GetCollectableWithdrawAmount(delegationID int64) int64 {
	return getImplementation().GetCollectableWithdrawAmount(delegationID)
}

// GetProtocolFeeAccumulatedX128PerStake returns the accumulated protocol fee per stake (Q128) for a token path.
func GetProtocolFeeAccumulatedX128PerStake(tokenPath string) *u256.Uint {
	return getImplementation().GetProtocolFeeAccumulatedX128PerStake(tokenPath)
}

// GetProtocolFeeAmounts returns the protocol fee amounts for a token path.
func GetProtocolFeeAmounts(tokenPath string) *u256.Uint {
	return getImplementation().GetProtocolFeeAmounts(tokenPath)
}

// GetProtocolFeeAccumulatedTimestamp returns the accumulated timestamp for protocol fee rewards.
func GetProtocolFeeAccumulatedTimestamp() int64 {
	return getImplementation().GetProtocolFeeAccumulatedTimestamp()
}

// GetEmissionAccumulatedX128PerStake returns the accumulated emission per stake (Q128).
func GetEmissionAccumulatedX128PerStake() *u256.Uint {
	return getImplementation().GetEmissionAccumulatedX128PerStake()
}

// GetEmissionDistributedAmount returns the total distributed emission amount.
func GetEmissionDistributedAmount() int64 {
	return getImplementation().GetEmissionDistributedAmount()
}

// GetEmissionAccumulatedTimestamp returns the accumulated timestamp for emission rewards.
func GetEmissionAccumulatedTimestamp() int64 {
	return getImplementation().GetEmissionAccumulatedTimestamp()
}
