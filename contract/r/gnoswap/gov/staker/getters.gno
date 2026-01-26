package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// GetTotalxGnsSupply returns the total supply of xGNS tokens.
//
// Returns:
//   - supply: total xGNS token supply
func GetTotalxGnsSupply() int64 {
	return getImplementation().GetTotalxGnsSupply()
}

// GetTotalDelegated returns the total amount of GNS delegated.
//
// Returns:
//   - amount: total delegated GNS amount
func GetTotalDelegated() int64 {
	return getImplementation().GetTotalDelegated()
}

// GetTotalLockedAmount returns the total amount of GNS locked in undelegation.
//
// Returns:
//   - amount: total locked GNS amount
func GetTotalLockedAmount() int64 {
	return getImplementation().GetTotalLockedAmount()
}

// GetLockedAmount returns the total locked GNS amount.
//
// Returns:
//   - amount: total locked GNS amount
func GetLockedAmount() int64 {
	return getImplementation().GetLockedAmount()
}

// GetUnDelegationLockupPeriod returns the undelegation lockup period in seconds.
//
// Returns:
//   - period: lockup period in seconds
func GetUnDelegationLockupPeriod() int64 {
	return getImplementation().GetUnDelegationLockupPeriod()
}

// GetEmissionRewardBalance returns the current emission reward balance.
//
// Returns:
//   - balance: current emission reward balance
func GetEmissionRewardBalance() int64 {
	return getImplementation().GetEmissionRewardBalance()
}

// GetDelegationCount returns the total number of delegations.
//
// Returns:
//   - count: total number of delegations
func GetDelegationCount() int {
	return getImplementation().GetDelegationCount()
}

// GetDelegationIDs returns a paginated list of delegation IDs.
//
// Parameters:
//   - offset: starting index
//   - count: number of IDs to return
//
// Returns:
//   - delegationIds: list of delegation IDs
func GetDelegationIDs(offset, count int) []int64 {
	return getImplementation().GetDelegationIDs(offset, count)
}

// ExistsDelegation checks if a delegation exists.
//
// Parameters:
//   - delegationID: ID of the delegation
//
// Returns:
//   - exists: true if delegation exists
func ExistsDelegation(delegationID int64) bool {
	return getImplementation().ExistsDelegation(delegationID)
}

// GetDelegation returns the delegation for the given ID.
//
// Parameters:
//   - delegationID: ID of the delegation
//
// Returns:
//   - delegation: delegation data or nil if not found
//   - err: error if retrieval fails
func GetDelegation(delegationID int64) (*Delegation, error) {
	delegation, err := getImplementation().GetDelegation(delegationID)
	if err != nil {
		return nil, err
	}
	return delegation.Clone(), nil
}

// GetDelegatorDelegateeCount returns the number of delegatees for a specific delegator.
//
// Parameters:
//   - delegator: delegator address
//
// Returns:
//   - count: number of delegatees
func GetDelegatorDelegateeCount(delegator address) int {
	return getImplementation().GetDelegatorDelegateeCount(delegator)
}

// GetDelegatorDelegateeAddresses returns a paginated list of delegatee addresses for a specific delegator.
//
// Parameters:
//   - delegator: delegator address
//   - offset: starting index
//   - count: number of addresses to return
//
// Returns:
//   - addresses: list of delegatee addresses
func GetDelegatorDelegateeAddresses(delegator address, offset, count int) []address {
	return getImplementation().GetDelegatorDelegateeAddresses(delegator, offset, count)
}

// GetUserDelegationCount returns the number of delegations for a specific delegator-delegatee pair.
//
// Parameters:
//   - delegator: delegator address
//   - delegatee: delegatee address
//
// Returns:
//   - count: number of delegations
func GetUserDelegationCount(delegator address, delegatee address) int {
	return getImplementation().GetUserDelegationCount(delegator, delegatee)
}

// GetUserDelegationIDs returns a list of delegation IDs for a specific delegator-delegatee pair.
//
// Parameters:
//   - delegator: delegator address
//   - delegatee: delegatee address
//
// Returns:
//   - delegationIds: list of delegation IDs
func GetUserDelegationIDs(delegator address, delegatee address) []int64 {
	return getImplementation().GetUserDelegationIDs(delegator, delegatee)
}

// HasDelegationSnapshotsKey returns true if delegation history exists.
//
// Returns:
//   - exists: true if delegation history exists
func HasDelegationSnapshotsKey() bool {
	return getImplementation().HasDelegationSnapshotsKey()
}

// GetTotalDelegationAmountAtSnapshot returns the total delegation amount at a specific snapshot time.
//
// Parameters:
//   - snapshotTime: snapshot timestamp
//
// Returns:
//   - amount: total delegation amount
//   - exists: true if snapshot exists
func GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool) {
	return getImplementation().GetTotalDelegationAmountAtSnapshot(snapshotTime)
}

// GetUserDelegationAmountAtSnapshot returns the user delegation amount at a specific snapshot time.
//
// Parameters:
//   - userAddr: user address
//   - snapshotTime: snapshot timestamp
//
// Returns:
//   - amount: user delegation amount
//   - exists: true if snapshot exists
func GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool) {
	return getImplementation().GetUserDelegationAmountAtSnapshot(userAddr, snapshotTime)
}

// GetClaimableRewardByAddress returns claimable rewards for an address.
//
// Parameters:
//   - addr: user address
//
// Returns:
//   - emissionReward: emission reward amount
//   - protocolFeeRewards: protocol fee rewards by token path
//   - err: error if retrieval fails
func GetClaimableRewardByAddress(addr address) (int64, map[string]int64, error) {
	return getImplementation().GetClaimableRewardByAddress(addr)
}

// GetClaimableRewardByLaunchpad returns claimable launchpad rewards for an address.
//
// Parameters:
//   - addr: user address
//
// Returns:
//   - emissionReward: emission reward amount
//   - protocolFeeRewards: protocol fee rewards by token path
//   - err: error if retrieval fails
func GetClaimableRewardByLaunchpad(addr address) (int64, map[string]int64, error) {
	return getImplementation().GetClaimableRewardByLaunchpad(addr)
}

// GetClaimableRewardByRewardID returns claimable reward details by reward ID.
//
// Parameters:
//   - rewardID: ID of the reward
//
// Returns:
//   - emissionReward: emission reward amount
//   - protocolFeeRewards: protocol fee rewards by token path
//   - err: error if retrieval fails
func GetClaimableRewardByRewardID(rewardID string) (int64, map[string]int64, error) {
	return getImplementation().GetClaimableRewardByRewardID(rewardID)
}

// GetLaunchpadProjectDeposit returns the deposit amount for a launchpad project.
//
// Parameters:
//   - projectAddr: project address
//
// Returns:
//   - amount: deposit amount
//   - exists: true if project exists
func GetLaunchpadProjectDeposit(projectAddr string) (int64, bool) {
	return getImplementation().GetLaunchpadProjectDeposit(projectAddr)
}

// GetDelegationWithdrawCount returns the total number of delegation withdraws for a specific delegation.
//
// Parameters:
//   - delegationID: ID of the delegation
//
// Returns:
//   - count: number of withdraws
func GetDelegationWithdrawCount(delegationID int64) int {
	return getImplementation().GetDelegationWithdrawCount(delegationID)
}

// GetDelegationWithdraws returns a paginated list of delegation withdraws for a specific delegation.
//
// Parameters:
//   - delegationID: ID of the delegation
//   - offset: starting index
//   - count: number of withdraws to return
//
// Returns:
//   - withdraws: list of delegation withdraws
//   - err: error if retrieval fails
func GetDelegationWithdraws(delegationID int64, offset, count int) ([]*DelegationWithdraw, error) {
	return getImplementation().GetDelegationWithdraws(delegationID, offset, count)
}

// GetCollectableWithdrawAmount returns the collectable withdraw amount for a specific delegation.
//
// Parameters:
//   - delegationID: ID of the delegation
//
// Returns:
//   - amount: collectable withdraw amount
func GetCollectableWithdrawAmount(delegationID int64) int64 {
	return getImplementation().GetCollectableWithdrawAmount(delegationID)
}

// GetProtocolFeeAccumulatedX128PerStake returns the accumulated protocol fee per stake (Q128) for a token path.
//
// Parameters:
//   - tokenPath: path of the token
//
// Returns:
//   - accumulatedFee: accumulated protocol fee per stake
func GetProtocolFeeAccumulatedX128PerStake(tokenPath string) *u256.Uint {
	return getImplementation().GetProtocolFeeAccumulatedX128PerStake(tokenPath).Clone()
}

// GetProtocolFeeAmount returns the protocol fee amounts for a token path.
//
// Parameters:
//   - tokenPath: path of the token
//
// Returns:
//   - amount: protocol fee amount
func GetProtocolFeeAmount(tokenPath string) int64 {
	return getImplementation().GetProtocolFeeAmount(tokenPath)
}

// GetProtocolFeeAccumulatedTimestamp returns the accumulated timestamp for protocol fee rewards.
//
// Returns:
//   - timestamp: accumulated timestamp
func GetProtocolFeeAccumulatedTimestamp() int64 {
	return getImplementation().GetProtocolFeeAccumulatedTimestamp()
}

// GetEmissionAccumulatedX128PerStake returns the accumulated emission per stake (Q128).
//
// Returns:
//   - accumulatedEmission: accumulated emission per stake
func GetEmissionAccumulatedX128PerStake() *u256.Uint {
	return getImplementation().GetEmissionAccumulatedX128PerStake().Clone()
}

// GetEmissionDistributedAmount returns the total distributed emission amount.
//
// Returns:
//   - amount: total distributed emission amount
func GetEmissionDistributedAmount() int64 {
	return getImplementation().GetEmissionDistributedAmount()
}

// GetEmissionAccumulatedTimestamp returns the accumulated timestamp for emission rewards.
//
// Returns:
//   - timestamp: accumulated timestamp
func GetEmissionAccumulatedTimestamp() int64 {
	return getImplementation().GetEmissionAccumulatedTimestamp()
}
