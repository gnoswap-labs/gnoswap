package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// GetTotalxGnsSupply returns the total supply of xGNS tokens.
func GetTotalxGnsSupply() int64 {
	return getImplementation().GetTotalxGnsSupply()
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
	delegationIDs := getImplementation().GetDelegationIDs(offset, count)
	result := make([]int64, len(delegationIDs))
	copy(result, delegationIDs)
	return result
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

// GetDelegatorDelegateeCount returns the number of delegatees for a specific delegator.
func GetDelegatorDelegateeCount(delegator address) int {
	return getImplementation().GetDelegatorDelegateeCount(delegator)
}

// GetDelegatorDelegateeAddresses returns a paginated list of delegatee addresses for a specific delegator.
func GetDelegatorDelegateeAddresses(delegator address, offset, count int) []address {
	addresses := getImplementation().GetDelegatorDelegateeAddresses(delegator, offset, count)
	result := make([]address, len(addresses))
	copy(result, addresses)
	return result
}

// GetUserDelegationCount returns the number of delegations for a specific delegator-delegatee pair.
func GetUserDelegationCount(delegator address, delegatee address) int {
	return getImplementation().GetUserDelegationCount(delegator, delegatee)
}

// GetUserDelegationIDs returns a list of delegation IDs for a specific delegator-delegatee pair.
func GetUserDelegationIDs(delegator address, delegatee address) []int64 {
	delegationIDs := getImplementation().GetUserDelegationIDs(delegator, delegatee)
	result := make([]int64, len(delegationIDs))
	copy(result, delegationIDs)
	return result
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
	emissionReward, protocolFeeRewards, err := getImplementation().GetClaimableRewardByAddress(addr)
	if err != nil {
		return 0, nil, err
	}

	copiedRewards := make(map[string]int64, len(protocolFeeRewards))
	for tokenPath, amount := range protocolFeeRewards {
		copiedRewards[tokenPath] = amount
	}

	return emissionReward, copiedRewards, nil
}

// GetClaimableRewardByLaunchpad returns claimable launchpad rewards for an address.
//
// Returns:
//   - int64: emission reward amount
//   - map[string]int64: protocol fee rewards by token path
func GetClaimableRewardByLaunchpad(addr address) (int64, map[string]int64, error) {
	emissionReward, protocolFeeRewards, err := getImplementation().GetClaimableRewardByLaunchpad(addr)
	if err != nil {
		return 0, nil, err
	}

	copiedRewards := make(map[string]int64, len(protocolFeeRewards))
	for tokenPath, amount := range protocolFeeRewards {
		copiedRewards[tokenPath] = amount
	}

	return emissionReward, copiedRewards, nil
}

// GetClaimableRewardByRewardID returns claimable reward details by reward ID.
//
// Returns:
//   - int64: emission reward amount
//   - map[string]int64: protocol fee rewards by token path
func GetClaimableRewardByRewardID(rewardID string) (int64, map[string]int64, error) {
	emissionReward, protocolFeeRewards, err := getImplementation().GetClaimableRewardByRewardID(rewardID)
	if err != nil {
		return 0, nil, err
	}

	copiedRewards := make(map[string]int64, len(protocolFeeRewards))
	for tokenPath, amount := range protocolFeeRewards {
		copiedRewards[tokenPath] = amount
	}

	return emissionReward, copiedRewards, nil
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
	delegationWithdraws, err := getImplementation().GetDelegationWithdraws(delegationID, offset, count)
	if err != nil {
		return nil, err
	}

	result := make([]*DelegationWithdraw, 0, len(delegationWithdraws))
	for _, delegationWithdraw := range delegationWithdraws {
		if delegationWithdraw == nil {
			result = append(result, nil)
			continue
		}
		result = append(result, delegationWithdraw.Clone())
	}

	return result, nil
}

// GetCollectableWithdrawAmount returns the collectable withdraw amount for a specific delegation.
func GetCollectableWithdrawAmount(delegationID int64) int64 {
	return getImplementation().GetCollectableWithdrawAmount(delegationID)
}

// GetProtocolFeeAccumulatedX128PerStake returns the accumulated protocol fee per stake (Q128) for a token path.
func GetProtocolFeeAccumulatedX128PerStake(tokenPath string) *u256.Uint {
	return getImplementation().GetProtocolFeeAccumulatedX128PerStake(tokenPath).Clone()
}

// GetProtocolFeeAmount returns the protocol fee amounts for a token path.
func GetProtocolFeeAmount(tokenPath string) int64 {
	return getImplementation().GetProtocolFeeAmount(tokenPath)
}

// GetProtocolFeeAccumulatedTimestamp returns the accumulated timestamp for protocol fee rewards.
func GetProtocolFeeAccumulatedTimestamp() int64 {
	return getImplementation().GetProtocolFeeAccumulatedTimestamp()
}

// GetEmissionAccumulatedX128PerStake returns the accumulated emission per stake (Q128).
func GetEmissionAccumulatedX128PerStake() *u256.Uint {
	return getImplementation().GetEmissionAccumulatedX128PerStake().Clone()
}

// GetEmissionDistributedAmount returns the total distributed emission amount.
func GetEmissionDistributedAmount() int64 {
	return getImplementation().GetEmissionDistributedAmount()
}

// GetEmissionAccumulatedTimestamp returns the accumulated timestamp for emission rewards.
func GetEmissionAccumulatedTimestamp() int64 {
	return getImplementation().GetEmissionAccumulatedTimestamp()
}
