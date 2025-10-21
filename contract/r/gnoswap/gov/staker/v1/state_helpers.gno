package v1

import (
	"gno.land/p/gno/avl"
	"gno.land/p/gno/ufmt"

	"gno.land/r/gnoswap/v1/emission"
	pf "gno.land/r/gnoswap/v1/protocol_fee"
	"gno.land/r/gnoswap/gov/staker"
)

// Type alias for clarity
type address = string

// State helper methods for govStakerV1

// getUnDelegationLockupPeriod returns the current undelegation lockup period in seconds.
//
// Returns:
//   - int64: lockup period in seconds
// XXX
func (gs *govStakerV1) getUnDelegationLockupPeriod() int64 {
	state := gs.getGovStakerState()
	return state.unDelegationLockupPeriod
}

// setUnDelegationLockupPeriod updates the undelegation lockup period.
// This affects all future undelegation operations.
//
// Parameters:
//   - period: new lockup period in seconds
func (gs *govStakerV1) setUnDelegationLockupPeriod(period int64) {
	state := gs.getGovStakerState()
	state.unDelegationLockupPeriod = period
}

// getCurrentDelegationID returns the current delegation counter value.
//
// Returns:
//   - int64: current delegation ID counter
func (gs *govStakerV1) getCurrentDelegationID() int64 {
	state := gs.getGovStakerState()
	counter := state.delegationCounter.(*Counter)
	return counter.Get()
}

// nextDelegationID generates and returns the next unique delegation ID.
//
// Returns:
//   - int64: next available delegation ID
func (gs *govStakerV1) nextDelegationID() int64 {
	state := gs.getGovStakerState()
	counter := state.delegationCounter.(*Counter)
	return counter.next()
}

// getDelegations returns the delegation storage tree.
//
// Returns:
//   - *avl.Tree: delegation storage tree
func (gs *govStakerV1) getDelegations() *avl.Tree {
	state := gs.getGovStakerState()
	return state.delegations
}

// getDelegation retrieves a delegation by its ID.
//
// Parameters:
//   - delegationID: unique identifier of the delegation
//
// Returns:
//   - *staker.Delegation: delegation instance or nil if not found
func (gs *govStakerV1) getDelegation(delegationID int64) *staker.Delegation {
	state := gs.getGovStakerState()
	id := formatInt(delegationID)
	delegation, ok := state.delegations.Get(id)
	if !ok {
		return nil
	}

	if delegation, ok := delegation.(*staker.Delegation); !ok {
		panic(ufmt.Sprintf("failed to cast delegations's element to *staker.Delegation: %T", delegation))
	} else {
		return delegation
	}
}

// setDelegation stores or updates a delegation in the storage tree.
//
// Parameters:
//   - delegationID: unique identifier of the delegation
//   - delegation: delegation instance to store
//
// Returns:
//   - bool: true if successfully stored
func (gs *govStakerV1) setDelegation(delegationID int64, delegation *staker.Delegation) bool {
	state := gs.getGovStakerState()
	id := formatInt(delegationID)

	state.delegations.Set(id, delegation)

	return true
}

// addDelegation adds a new delegation to storage and updates the delegation manager.
//
// Parameters:
//   - delegationID: unique identifier of the delegation
//   - delegation: delegation instance to add
//
// Returns:
//   - bool: true if successfully added
func (gs *govStakerV1) addDelegation(delegationID int64, delegation *staker.Delegation) bool {
	state := gs.getGovStakerState()
	if ok := gs.setDelegation(delegationID, delegation); !ok {
		return false
	}

	state.delegationManager.addDelegation(
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegationID,
	)

	return true
}

// removeDelegation removes a delegation from storage and updates the delegation manager.
//
// Parameters:
//   - delegationID: unique identifier of the delegation to remove
//
// Returns:
//   - bool: true if successfully removed
func (gs *govStakerV1) removeDelegation(delegationID int64) bool {
	state := gs.getGovStakerState()
	delegation := gs.getDelegation(delegationID)
	if delegation == nil {
		return false
	}

	id := formatInt(delegation.ID())
	_, ok := state.delegations.Remove(id)

	state.delegationManager.removeDelegation(
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegationID,
	)

	return ok
}

// getUserDelegations retrieves all delegations for a specific user.
//
// Parameters:
//   - user: user's address
//
// Returns:
//   - []*staker.Delegation: list of user's delegations
func (gs *govStakerV1) getUserDelegations(user address) (delegations []*staker.Delegation) {
	state := gs.getGovStakerState()
	for _, delegationID := range state.delegationManager.GetUserDelegationIDs(user) {
		delegations = append(delegations, gs.getDelegation(delegationID))
	}
	return
}

// getUserDelegationsWithDelegatee retrieves all delegations from a user to a specific delegatee.
// Note: Current implementation returns all user delegations regardless of delegatee (potential bug).
//
// Parameters:
//   - user: user's address
//   - delegatee: delegatee's address (currently unused)
//
// Returns:
//   - []*staker.Delegation: list of user's delegations to the delegatee
func (gs *govStakerV1) getUserDelegationsWithDelegatee(user address, delegatee address) (delegations []*staker.Delegation) {
	state := gs.getGovStakerState()
	for _, delegationID := range state.delegationManager.GetUserDelegationIDs(user) {
		delegations = append(delegations, gs.getDelegation(delegationID))
	}
	return
}

// getDelegationHistory returns the current delegation history.
//
// Returns:
//   - *avl.Tree: chronological list of delegation records
func (gs *govStakerV1) getDelegationHistory() *avl.Tree {
	state := gs.getGovStakerState()
	return state.delegationHistory
}

// addDelegationRecord adds a new delegation record to history and updates snapshots.
//
// Parameters:
//   - delegationRecord: delegation record to add
func (gs *govStakerV1) addDelegationRecord(delegationRecord *staker.DelegationRecord) {
	state := gs.getGovStakerState()
	// TODO: Implement proper history and snapshot update logic
	// state.delegationHistory = state.delegationHistory.addRecord(delegationRecord)
	// state.delegationSnapshots = state.delegationSnapshots.addRecord(delegationRecord)
}

// setDelegationHistory replaces the current delegation history.
//
// Parameters:
//   - history: new delegation history to set
func (gs *govStakerV1) setDelegationHistory(history *avl.Tree) {
	state := gs.getGovStakerState()
	state.delegationHistory = history
}

// getDelegationSnapshots returns the current delegation snapshots.
//
// Returns:
//   - *avl.Tree: current delegation state for all delegatees
func (gs *govStakerV1) getDelegationSnapshots() *avl.Tree {
	state := gs.getGovStakerState()
	return state.delegationSnapshots
}

// setDelegationSnapshots replaces the current delegation snapshots.
//
// Parameters:
//   - snapshot: new delegation snapshot to set
func (gs *govStakerV1) setDelegationSnapshots(snapshot *avl.Tree) {
	state := gs.getGovStakerState()
	state.delegationSnapshots = snapshot
}

// addStakeEmissionReward adds stake to emission reward tracking for an address.
// This method updates the emission reward distribution state and adds stake for the specified address.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to add
//   - currentTimestamp: current timestamp
func (gs *govStakerV1) addStakeEmissionReward(address string, amount int64, currentTimestamp int64) error {
	state := gs.getGovStakerState()
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	err := state.emissionRewardManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp)
	if err != nil {
		return err
	}

	return state.emissionRewardManager.addStake(address, amount, currentTimestamp)
}

// removeStakeEmissionReward removes stake from emission reward tracking for an address.
// This method updates the emission reward distribution state and removes stake for the specified address.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (gs *govStakerV1) removeStakeEmissionReward(address string, amount int64, currentTimestamp int64) error {
	state := gs.getGovStakerState()
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	err := state.emissionRewardManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp)
	if err != nil {
		return err
	}

	return state.emissionRewardManager.removeStake(address, amount, currentTimestamp)
}

// claimRewardsEmissionReward claims emission rewards for an address.
// This method updates the emission reward distribution state and processes reward claiming.
//
// Parameters:
//   - address: staker's address claiming rewards
//   - currentTimestamp: current timestamp
//
// Returns:
//   - int64: amount of emission rewards claimed
//   - error: nil on success, error if claiming fails
func (gs *govStakerV1) claimRewardsEmissionReward(address string, currentTimestamp int64) (int64, error) {
	state := gs.getGovStakerState()
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	err := state.emissionRewardManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp)
	if err != nil {
		return 0, err
	}

	return state.emissionRewardManager.claimRewards(address, currentTimestamp)
}

// addStakeProtocolFeeReward adds stake to protocol fee reward tracking for an address.
// This method distributes protocol fees and updates the protocol fee reward state.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to add
//   - currentTimestamp: current timestamp
func (gs *govStakerV1) addStakeProtocolFeeReward(address string, amount int64, currentTimestamp int64) error {
	state := gs.getGovStakerState()
	pf.DistributeProtocolFee()

	distributedAmounts := gs.getDistributedProtocolFees()

	err := state.protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentTimestamp)
	if err != nil {
		return err
	}

	return state.protocolFeeRewardManager.addStake(address, amount, currentTimestamp)
}

// removeStakeProtocolFeeReward removes stake from protocol fee reward tracking for an address.
// This method distributes protocol fees and updates the protocol fee reward state.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (gs *govStakerV1) removeStakeProtocolFeeReward(address string, amount int64, currentTimestamp int64) error {
	state := gs.getGovStakerState()
	pf.DistributeProtocolFee()

	distributedAmounts := gs.getDistributedProtocolFees()

	err := state.protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentTimestamp)
	if err != nil {
		return err
	}

	return state.protocolFeeRewardManager.removeStake(address, amount, currentTimestamp)
}

// claimRewardsProtocolFeeReward claims protocol fee rewards for an address.
// This method distributes protocol fees and processes reward claiming for all token types.
//
// Parameters:
//   - address: staker's address claiming rewards
//   - currentTimestamp: current timestamp
//
// Returns:
//   - map[string]int64: protocol fee rewards claimed by token
//   - error: nil on success, error if claiming fails
func (gs *govStakerV1) claimRewardsProtocolFeeReward(address string, currentTimestamp int64) (map[string]int64, error) {
	state := gs.getGovStakerState()
	pf.DistributeProtocolFee()

	distributedAmounts := gs.getDistributedProtocolFees()

	err := state.protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentTimestamp)
	if err != nil {
		return nil, err
	}

	return state.protocolFeeRewardManager.claimRewards(address, currentTimestamp)
}

// getDistributedProtocolFees retrieves the current distributed protocol fee amounts for all tokens.
// This method queries the protocol fee contract for accumulated distributions.
//
// Returns:
//   - map[string]int64: distributed amounts by token path
func (gs *govStakerV1) getDistributedProtocolFees() map[string]int64 {
	return pf.GetAccuTransfersToGovStaker()
}

// getLaunchpadProjectDeposit retrieves the deposit amount for a launchpad project.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//
// Returns:
//   - int64: deposit amount
//   - bool: true if project exists, false otherwise
func (gs *govStakerV1) getLaunchpadProjectDeposit(ownerAddress string) (int64, bool) {
	state := gs.getGovStakerState()
	deposit, ok := state.launchpadProjectDeposits.Get(ownerAddress)
	if !ok {
		return 0, false
	}

	amount, ok := deposit.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast deposit to int64: %T", deposit))
	}

	return amount, true
}

// setLaunchpadProjectDeposit sets the deposit amount for a launchpad project.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//   - deposit: deposit amount to set
//
// Returns:
//   - bool: true if successfully set
func (gs *govStakerV1) setLaunchpadProjectDeposit(ownerAddress string, deposit int64) bool {
	state := gs.getGovStakerState()
	state.launchpadProjectDeposits.Set(ownerAddress, deposit)

	return true
}

// removeLaunchpadProjectDeposit removes a launchpad project deposit record.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//
// Returns:
//   - bool: true if successfully removed
func (gs *govStakerV1) removeLaunchpadProjectDeposit(ownerAddress string) bool {
	state := gs.getGovStakerState()
	_, ok := state.launchpadProjectDeposits.Remove(ownerAddress)

	return ok
}

// addStakeFromLaunchpad adds stake for a launchpad project and updates reward tracking.
// This method creates a special reward ID for launchpad projects and manages their deposit tracking.
//
// Parameters:
//   - address: project wallet address
//   - amount: amount of stake to add
//   - currentTimestamp: current timestamp
func (gs *govStakerV1) addStakeFromLaunchpad(address string, amount int64, currentTimestamp int64) error {
	launchpadRewardID := gs.makeLaunchpadRewardID(address)
	err := gs.addStakeEmissionReward(launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	err = gs.addStakeProtocolFeeReward(launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	deposit, exists := gs.getLaunchpadProjectDeposit(launchpadRewardID)
	if !exists {
		deposit = 0
	}

	deposit += amount
	gs.setLaunchpadProjectDeposit(launchpadRewardID, deposit)

	return nil
}

// removeStakeFromLaunchpad removes stake for a launchpad project and updates reward tracking.
// This method manages launchpad project deposit tracking and ensures non-negative deposits.
//
// Parameters:
//   - address: project wallet address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (gs *govStakerV1) removeStakeFromLaunchpad(address string, amount int64, currentTimestamp int64) error {
	launchpadRewardID := gs.makeLaunchpadRewardID(address)
	err := gs.removeStakeEmissionReward(launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	err = gs.removeStakeProtocolFeeReward(launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	deposit, exists := gs.getLaunchpadProjectDeposit(launchpadRewardID)
	if !exists {
		deposit = 0
	}

	deposit -= amount
	if deposit < 0 {
		deposit = 0
	}

	gs.setLaunchpadProjectDeposit(launchpadRewardID, deposit)

	return nil
}

// makeLaunchpadRewardID creates a special reward identifier for launchpad projects.
// This ensures launchpad project rewards are tracked separately from regular user stakes.
//
// Parameters:
//   - address: project wallet address
//
// Returns:
//   - string: formatted launchpad reward ID
func (gs *govStakerV1) makeLaunchpadRewardID(address string) string {
	return ufmt.Sprintf("launchpad:%s", address)
}
