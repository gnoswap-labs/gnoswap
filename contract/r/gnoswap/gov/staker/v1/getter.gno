package v1

import (
	"math"
	"strconv"
	"time"

	"gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/gov/xgns"
	"gno.land/r/gnoswap/protocol_fee"
)

// GetTotalxGnsSupply returns the total amount of xGNS supply.
func (gs *govStakerV1) GetTotalxGnsSupply() int64 {
	return xgns.TotalSupply()
}

// GetTotalVoteWeight returns the total amount of xGNS used for voting.
func (gs *govStakerV1) GetTotalVoteWeight() int64 {
	return xgns.VotingSupply()
}

// GetTotalDelegated returns the total amount of xGNS delegated.
func (gs *govStakerV1) GetTotalDelegated() int64 {
	return gs.store.GetTotalDelegatedAmount()
}

// GetTotalLockedAmount returns the total amount of locked GNS.
func (gs *govStakerV1) GetTotalLockedAmount() int64 {
	return gs.store.GetTotalLockedAmount()
}

// GetLockedAmount returns total locked GNS amount.
// This returns the same value as GetTotalLockedAmount() from the store.
func (gs *govStakerV1) GetLockedAmount() int64 {
	return gs.store.GetTotalLockedAmount()
}

// GetUnDelegationLockupPeriod returns the undelegation lockup period in seconds.
func (gs *govStakerV1) GetUnDelegationLockupPeriod() int64 {
	return gs.store.GetUnDelegationLockupPeriod()
}

// GetEmissionRewardBalance returns the current emission reward balance.
func (gs *govStakerV1) GetEmissionRewardBalance() int64 {
	return gs.store.GetEmissionRewardBalance()
}

// GetDelegationCount returns the total number of delegations.
func (gs *govStakerV1) GetDelegationCount() int {
	delegations := gs.store.GetAllDelegations()
	return delegations.Size()
}

// GetDelegationIDs returns a paginated list of delegation IDs.
func (gs *govStakerV1) GetDelegationIDs(offset, count int) []int64 {
	delegations := gs.store.GetAllDelegations()

	ids := make([]int64, 0)

	delegations.IterateByOffset(offset, count, func(key string, _ any) bool {
		delegationID, err := strconv.ParseInt(key, 10, 64)
		if err != nil {
			return false
		}

		ids = append(ids, delegationID)
		return false
	})

	return ids
}

// ExistsDelegation checks if a delegation exists.
func (gs *govStakerV1) ExistsDelegation(delegationID int64) bool {
	return gs.store.HasDelegation(delegationID)
}

// GetDelegation returns the delegation for the given ID.
func (gs *govStakerV1) GetDelegation(delegationID int64) (*staker.Delegation, error) {
	delegation, exists := gs.store.GetDelegation(delegationID)
	if !exists {
		return nil, ufmt.Errorf("delegation not found: %d", delegationID)
	}
	return delegation, nil
}

// GetDelegatorDelegateeCount returns the number of delegatees for a specific delegator.
func (gs *govStakerV1) GetDelegatorDelegateeCount(delegator address) int {
	delegationManager := gs.store.GetDelegationManager()
	delegatorTree, exists := delegationManager.GetDelegatorDelegations(delegator.String())
	if !exists {
		return 0
	}

	return delegatorTree.Size()
}

// GetDelegatorDelegateeAddresses returns a paginated list of delegatee addresses for a specific delegator.
func (gs *govStakerV1) GetDelegatorDelegateeAddresses(delegator address, offset, count int) []address {
	delegationManager := gs.store.GetDelegationManager()
	delegatorTree, exists := delegationManager.GetDelegatorDelegations(delegator.String())
	if !exists {
		return []address{}
	}

	delegateeAddresses := make([]address, 0)

	delegatorTree.IterateByOffset(offset, count, func(delegatee string, _ any) bool {
		delegateeAddresses = append(delegateeAddresses, address(delegatee))
		return false
	})

	return delegateeAddresses
}

// GetUserDelegationCount returns the number of delegations for a specific delegator-delegatee pair.
func (gs *govStakerV1) GetUserDelegationCount(delegator address, delegatee address) int {
	delegationManager := gs.store.GetDelegationManager()
	delegationIDs, exists := delegationManager.GetDelegationIDs(delegator.String(), delegatee.String())
	if !exists {
		return 0
	}
	return len(delegationIDs)
}

// GetUserDelegationIDs returns a paginated list of delegation IDs for a specific delegator and delegatee.
func (gs *govStakerV1) GetUserDelegationIDs(delegator address, delegatee address) []int64 {
	delegationManager := gs.store.GetDelegationManager()

	delegationIDs, exists := delegationManager.GetDelegationIDs(delegator.String(), delegatee.String())
	if !exists {
		return []int64{}
	}

	return delegationIDs
}

// HasDelegationSnapshotsKey returns true if delegation history exists.
func (gs *govStakerV1) HasDelegationSnapshotsKey() bool {
	return gs.store.HasTotalDelegationHistoryStoreKey()
}

// GetTotalDelegationAmountAtSnapshot returns the total delegation amount at a specific snapshot time.
// Uses ReverseIterate to find the most recent entry at or before the snapshot time.
//
// Parameters:
//   - snapshotTime: timestamp to retrieve the snapshot for
//
// Returns:
//   - int64: total delegation amount at the specified time
//   - bool: true if snapshot was exists, false otherwise
func (gs *govStakerV1) GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool) {
	history := gs.store.GetTotalDelegationHistory()
	if history.Size() == 0 {
		return 0, false
	}

	toTimestamp := snapshotTime
	if toTimestamp < math.MaxInt64 {
		toTimestamp = toTimestamp + 1
	}

	var (
		totalAmount int64
		exists      bool
	)

	// ReverseIterate from 0 to snapshotTime to find the most recent entry at or before snapshotTime
	history.ReverseIterate(0, toTimestamp, func(key int64, value any) bool {
		amountInt, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("invalid amount type: %T", value))
		}

		totalAmount = amountInt
		exists = true

		return true // stop after first (most recent) entry
	})

	return totalAmount, exists
}

// GetUserDelegationAmountAtSnapshot returns the delegation amount for a specific user at a specific snapshot time.
// Structure: address -> *UintTree[timestamp -> int64]
// Uses ReverseIterate to find the most recent entry at or before the snapshot time.
//
// Parameters:
//   - userAddr: address of the user to get delegation amount for
//   - snapshotTime: timestamp to retrieve the snapshot for
//
// Returns:
//   - int64: user delegation amount at the specified time
//   - bool: true if snapshot was exists, false otherwise
func (gs *govStakerV1) GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool) {
	history := gs.store.GetUserDelegationHistory()

	// Get user's history tree
	userHistoryRaw, userHistoryExists := history.Get(userAddr.String())
	if !userHistoryExists {
		return 0, false
	}

	userHistory := userHistoryRaw.(*staker.UintTree)
	if userHistory.Size() == 0 {
		return 0, false
	}

	toTimestamp := snapshotTime
	if toTimestamp < math.MaxInt64 {
		toTimestamp = toTimestamp + 1
	}

	var (
		userAmount int64
		exists     bool
	)

	// ReverseIterate from 0 to snapshotTime to find the most recent entry at or before snapshotTime
	userHistory.ReverseIterate(0, toTimestamp, func(key int64, value any) bool {
		amountInt, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("invalid amount type: %T", value))
		}

		userAmount = amountInt
		exists = true

		return true // stop after first (most recent) entry
	})

	return userAmount, exists
}

// GetClaimableRewardByAddress returns claimable reward for address.
//
// Returns:
//   - int64: emission reward amount
//   - map[string]int64: protocol fee rewards by token path
func (gs *govStakerV1) GetClaimableRewardByAddress(addr address) (int64, map[string]int64, error) {
	return gs.GetClaimableRewardByRewardID(addr.String())
}

// GetClaimableRewardByLaunchpad returns claimable reward for launchpad.
//
// Returns:
//   - int64: emission reward amount
//   - map[string]int64: protocol fee rewards by token path
func (gs *govStakerV1) GetClaimableRewardByLaunchpad(addr address) (int64, map[string]int64, error) {
	return gs.GetClaimableRewardByRewardID(gs.makeLaunchpadRewardID(addr.String()))
}

// GetClaimableRewardByRewardID returns claimable reward by ID.
//
// Returns:
//   - int64: emission reward amount
//   - map[string]int64: protocol fee rewards by token path
func (gs *govStakerV1) GetClaimableRewardByRewardID(rewardID string) (int64, map[string]int64, error) {
	emission.MintAndDistributeGns(cross)
	protocol_fee.DistributeProtocolFee(cross)

	emissionDistributedAmount := emission.GetAccuDistributedToGovStaker()
	emissionRewardManager := gs.store.GetEmissionRewardManager()
	emissionResolver := NewEmissionRewardManagerResolver(emissionRewardManager)
	emissionReward, err := emissionResolver.GetClaimableRewardAmount(emissionDistributedAmount, rewardID, time.Now().Unix())
	if err != nil {
		return 0, make(map[string]int64), err
	}

	protocolFeeDistributedAmounts := gs.getDistributedProtocolFees()
	protocolFeeRewardManager := gs.store.GetProtocolFeeRewardManager()
	protocolFeeResolver := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)
	protocolFeeRewards, err := protocolFeeResolver.GetClaimableRewardAmounts(protocolFeeDistributedAmounts, rewardID, time.Now().Unix())
	if err != nil {
		return 0, make(map[string]int64), err
	}

	return emissionReward, protocolFeeRewards, nil
}

// GetLaunchpadProjectDeposit returns the deposit amount for a launchpad project.
func (gs *govStakerV1) GetLaunchpadProjectDeposit(projectAddr string) (int64, bool) {
	launchpadDeposits := gs.store.GetLaunchpadProjectDeposits()
	resolvedDeposits := NewLaunchpadProjectDepositsResolver(launchpadDeposits)
	return resolvedDeposits.getLaunchpadProjectDeposit(gs.makeLaunchpadRewardID(projectAddr))
}

// GetDelegationWithdrawCount returns the total number of delegation withdraws for a specific delegation.
func (gs *govStakerV1) GetDelegationWithdrawCount(delegationID int64) int {
	delegation, exists := gs.store.GetDelegation(delegationID)
	if !exists {
		return 0
	}
	return len(delegation.Withdraws())
}

// GetDelegationWithdraws returns a paginated list of delegation withdraws for a specific delegation.
func (gs *govStakerV1) GetDelegationWithdraws(delegationID int64, offset, count int) ([]*staker.DelegationWithdraw, error) {
	delegation, exists := gs.store.GetDelegation(delegationID)
	if !exists {
		return []*staker.DelegationWithdraw{}, nil
	}

	withdraws := delegation.Withdraws()
	size := len(withdraws)
	if offset >= size {
		return []*staker.DelegationWithdraw{}, nil
	}

	end := offset + count
	if end > size {
		end = size
	}

	return withdraws[offset:end], nil
}

// GetCollectableWithdrawAmount returns the collectable withdraw amount for a specific delegation.
func (gs *govStakerV1) GetCollectableWithdrawAmount(delegationID int64) int64 {
	delegation, exists := gs.store.GetDelegation(delegationID)
	if !exists {
		return 0
	}

	totalAmount := int64(0)
	for _, withdraw := range delegation.Withdraws() {
		totalAmount += safeSubInt64(withdraw.UnDelegateAmount(), withdraw.CollectedAmount())
	}

	return totalAmount
}

// GetProtocolFeeAccumulatedX128PerStake returns the accumulated protocol fee per stake (Q128) for a token path.
func (gs *govStakerV1) GetProtocolFeeAccumulatedX128PerStake(tokenPath string) *uint256.Uint {
	protocolFeeRewardManager := gs.store.GetProtocolFeeRewardManager()
	accumulatedFee := protocolFeeRewardManager.GetAccumulatedProtocolFeeX128PerStake(tokenPath)
	if accumulatedFee == nil {
		return uint256.NewUint(0)
	}

	return accumulatedFee
}

// GetProtocolFeeAmount returns the protocol fee amounts for a token path.
func (gs *govStakerV1) GetProtocolFeeAmount(tokenPath string) int64 {
	protocolFeeRewardManager := gs.store.GetProtocolFeeRewardManager()
	return protocolFeeRewardManager.GetProtocolFeeAmount(tokenPath)
}

// GetProtocolFeeAccumulatedTimestamp returns the accumulated timestamp for protocol fee rewards.
func (gs *govStakerV1) GetProtocolFeeAccumulatedTimestamp() int64 {
	protocolFeeRewardManager := gs.store.GetProtocolFeeRewardManager()
	return protocolFeeRewardManager.GetAccumulatedTimestamp()
}

// GetEmissionAccumulatedX128PerStake returns the accumulated emission per stake (Q128).
func (gs *govStakerV1) GetEmissionAccumulatedX128PerStake() *uint256.Uint {
	emissionRewardManager := gs.store.GetEmissionRewardManager()
	return emissionRewardManager.GetAccumulatedRewardX128PerStake()
}

// GetEmissionDistributedAmount returns the total distributed emission amount.
func (gs *govStakerV1) GetEmissionDistributedAmount() int64 {
	emissionRewardManager := gs.store.GetEmissionRewardManager()
	return emissionRewardManager.GetDistributedAmount()
}

// GetEmissionAccumulatedTimestamp returns the accumulated timestamp for emission rewards.
func (gs *govStakerV1) GetEmissionAccumulatedTimestamp() int64 {
	emissionRewardManager := gs.store.GetEmissionRewardManager()
	return emissionRewardManager.GetAccumulatedTimestamp()
}
