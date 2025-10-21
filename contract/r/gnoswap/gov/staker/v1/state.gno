package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/emission"
	pf "gno.land/r/gnoswap/protocol_fee"
)

// getUnDelegationLockupPeriod returns the current undelegation lockup period in seconds.
//
// Returns:
//   - int64: lockup period in seconds
func (g *govStakerV1) getUnDelegationLockupPeriod() int64 {
	state := g.getState()
	return state.UnDelegationLockupPeriod()
}

// setUnDelegationLockupPeriod updates the undelegation lockup period.
// This affects all future undelegation operations.
//
// Parameters:
//   - period: new lockup period in seconds
func (g *govStakerV1) setUnDelegationLockupPeriod(period int64) {
	state := g.getState()
	state.SetUnDelegationLockupPeriod(period)
	g.setState(state)
}

// getCurrentDelegationID returns the current delegation counter value.
//
// Returns:
//   - int64: current delegation ID counter
func (g *govStakerV1) getCurrentDelegationID() int64 {
	state := g.getState()
	counter := state.DelegationCounter().(*Counter)
	return counter.Get()
}

// nextDelegationID generates and returns the next unique delegation ID.
//
// Returns:
//   - int64: next available delegation ID
func (g *govStakerV1) nextDelegationID() int64 {
	state := g.getState()
	counter := state.DelegationCounter().(*Counter)
	nextID := counter.next()
	g.setState(state)
	return nextID
}

// getDelegations returns the delegation storage tree.
//
// Returns:
//   - *avl.Tree: delegation storage tree
func (g *govStakerV1) getDelegations() *avl.Tree {
	state := g.getState()
	return state.Delegations()
}

// getDelegation retrieves a delegation by its ID.
//
// Parameters:
//   - delegationID: unique identifier of the delegation
//
// Returns:
//   - *Delegation: delegation instance or nil if not found
func (g *govStakerV1) getDelegation(delegationID int64) *Delegation {
	state := g.getState()
	delegations := state.Delegations()
	id := formatInt(delegationID)
	delegation, ok := delegations.Get(id)
	if !ok {
		return nil
	}

	if delegation, ok := delegation.(*Delegation); !ok {
		panic(ufmt.Sprintf("failed to cast delegations's element to *Delegation: %T", delegation))
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
func (g *govStakerV1) setDelegation(delegationID int64, delegation *Delegation) bool {
	state := g.getState()
	delegations := state.Delegations()
	id := formatInt(delegationID)

	delegations.Set(id, delegation)
	g.setState(state)

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
func (g *govStakerV1) addDelegation(delegationID int64, delegation *Delegation) bool {
	if ok := g.setDelegation(delegationID, delegation); !ok {
		return false
	}

	state := g.getState()
	delegationManager := state.DelegationManager().(*DelegationManager)
	delegationManager.addDelegation(
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegationID,
	)
	g.setState(state)

	return true
}

// removeDelegation removes a delegation from storage and updates the delegation manager.
//
// Parameters:
//   - delegationID: unique identifier of the delegation to remove
//
// Returns:
//   - bool: true if successfully removed
func (g *govStakerV1) removeDelegation(delegationID int64) bool {
	delegation := g.getDelegation(delegationID)
	if delegation == nil {
		return false
	}

	state := g.getState()
	delegations := state.Delegations()
	delegationManager := state.DelegationManager().(*DelegationManager)

	id := formatInt(delegation.ID())
	_, ok := delegations.Remove(id)

	delegationManager.removeDelegation(
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegationID,
	)
	g.setState(state)

	return ok
}

// getUserDelegations retrieves all delegations for a specific user.
//
// Parameters:
//   - user: user's address
//
// Returns:
//   - []*Delegation: list of user's delegations
func (g *govStakerV1) getUserDelegations(user address) (delegations []*Delegation) {
	state := g.getState()
	delegationManager := state.DelegationManager().(*DelegationManager)
	for _, delegationID := range delegationManager.GetUserDelegationIDs(user) {
		delegations = append(delegations, g.getDelegation(delegationID))
	}
	return delegations
}

// getUserDelegationsWithDelegatee retrieves all delegations from a user to a specific delegatee.
// Note: Current implementation returns all user delegations regardless of delegatee (potential bug).
//
// Parameters:
//   - user: user's address
//   - delegatee: delegatee's address (currently unused)
//
// Returns:
//   - []*Delegation: list of user's delegations to the delegatee
func (g *govStakerV1) getUserDelegationsWithDelegatee(user address, delegatee address) (delegations []*Delegation) {
	state := g.getState()
	delegationManager := state.DelegationManager().(*DelegationManager)
	for _, delegationID := range delegationManager.GetUserDelegationIDs(user) {
		delegations = append(delegations, g.getDelegation(delegationID))
	}
	return delegations
}

// getDelegationHistory returns the current delegation history.
//
// Returns:
//   - DelegationHistory: chronological list of delegation records
func (g *govStakerV1) getDelegationHistory() DelegationHistory {
	state := g.getState()
	return state.delegationHistory
}

// addDelegationRecord adds a new delegation record to history and updates snapshots.
//
// Parameters:
//   - delegationRecord: delegation record to add
func (g *govStakerV1) addDelegationRecord(delegationRecord *DelegationRecord) {
	state := g.getState()

	delegationHistory := state.delegationHistory
	delegationSnapshots := state.delegationSnapshots

	delegationHistory = delegationHistory.addRecord(delegationRecord)
	delegationSnapshots = delegationSnapshots.addRecord(delegationRecord)
	state.delegationHistory = delegationHistory
	state.delegationSnapshots = delegationSnapshots
	g.setState(state)
}

// setDelegationHistory replaces the current delegation history.
//
// Parameters:
//   - history: new delegation history to set
func (g *govStakerV1) setDelegationHistory(history DelegationHistory) {
	state := g.getState()
	state.delegationHistory = history
	g.setState(state)
}

// getDelegationSnapshots returns the current delegation snapshots.
//
// Returns:
//   - DelegationSnapshot: current delegation state for all delegatees
func (g *govStakerV1) getDelegationSnapshots() DelegationSnapshot {
	state := g.getState()
	return state.delegationSnapshots
}

// setDelegationSnapshots replaces the current delegation snapshots.
//
// Parameters:
//   - snapshot: new delegation snapshot to set
func (g *govStakerV1) setDelegationSnapshots(snapshot DelegationSnapshot) {
	state := g.getState()
	state.delegationSnapshots = snapshot
	g.setState(state)
}

// addStakeEmissionReward adds stake to emission reward tracking for an address.
// This method updates the emission reward distribution state and adds stake for the specified address.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to add
//   - currentTimestamp: current timestamp
func (g *govStakerV1) addStakeEmissionReward(address string, amount int64, currentTimestamp int64) error {
	state := g.getState()
	emissionRewardManager := state.EmissionRewardManager().(*EmissionRewardManager)

	distributedAmount := emission.GetAccuDistributedToGovStaker()

	err := emissionRewardManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp)
	if err != nil {
		return err
	}

	err = emissionRewardManager.addStake(address, amount, currentTimestamp)
	g.setState(state)
	return err
}

// removeStakeEmissionReward removes stake from emission reward tracking for an address.
// This method updates the emission reward distribution state and removes stake for the specified address.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (g *govStakerV1) removeStakeEmissionReward(address string, amount int64, currentTimestamp int64) error {
	state := g.getState()
	emissionRewardManager := state.EmissionRewardManager().(*EmissionRewardManager)

	distributedAmount := emission.GetAccuDistributedToGovStaker()

	err := emissionRewardManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp)
	if err != nil {
		return err
	}

	err = emissionRewardManager.removeStake(address, amount, currentTimestamp)
	g.setState(state)
	return err
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
func (g *govStakerV1) claimRewardsEmissionReward(address string, currentTimestamp int64) (int64, error) {
	state := g.getState()
	emissionRewardManager := state.EmissionRewardManager().(*EmissionRewardManager)

	distributedAmount := emission.GetAccuDistributedToGovStaker()

	err := emissionRewardManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp)
	if err != nil {
		return 0, err
	}

	amount, err := emissionRewardManager.claimRewards(address, currentTimestamp)
	g.setState(state)
	return amount, err
}

// addStakeProtocolFeeReward adds stake to protocol fee reward tracking for an address.
// This method distributes protocol fees and updates the protocol fee reward state.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to add
//   - currentTimestamp: current timestamp
func (g *govStakerV1) addStakeProtocolFeeReward(address string, amount int64, currentTimestamp int64) error {
	state := g.getState()
	protocolFeeRewardManager := state.ProtocolFeeRewardManager().(*ProtocolFeeRewardManager)

	pf.DistributeProtocolFee(cross)

	distributedAmounts := g.getDistributedProtocolFees()

	err := protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentTimestamp)
	if err != nil {
		return err
	}

	err = protocolFeeRewardManager.addStake(address, amount, currentTimestamp)
	g.setState(state)
	return err
}

// removeStakeProtocolFeeReward removes stake from protocol fee reward tracking for an address.
// This method distributes protocol fees and updates the protocol fee reward state.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (g *govStakerV1) removeStakeProtocolFeeReward(address string, amount int64, currentTimestamp int64) error {
	state := g.getState()
	protocolFeeRewardManager := state.ProtocolFeeRewardManager().(*ProtocolFeeRewardManager)

	pf.DistributeProtocolFee(cross)

	distributedAmounts := g.getDistributedProtocolFees()

	err := protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentTimestamp)
	if err != nil {
		return err
	}

	err = protocolFeeRewardManager.removeStake(address, amount, currentTimestamp)
	g.setState(state)
	return err
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
func (g *govStakerV1) claimRewardsProtocolFeeReward(address string, currentTimestamp int64) (map[string]int64, error) {
	state := g.getState()
	protocolFeeRewardManager := state.ProtocolFeeRewardManager().(*ProtocolFeeRewardManager)

	pf.DistributeProtocolFee(cross)

	distributedAmounts := g.getDistributedProtocolFees()

	err := protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentTimestamp)
	if err != nil {
		return nil, err
	}

	rewards, err := protocolFeeRewardManager.claimRewards(address, currentTimestamp)
	g.setState(state)
	return rewards, err
}

// getDistributedProtocolFees retrieves the current distributed protocol fee amounts for all tokens.
// This method queries the protocol fee contract for accumulated distributions.
//
// Returns:
//   - map[string]int64: distributed amounts by token path
func (g *govStakerV1) getDistributedProtocolFees() map[string]int64 {
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
func (g *govStakerV1) getLaunchpadProjectDeposit(ownerAddress string) (int64, bool) {
	state := g.getState()
	launchpadProjectDeposits := state.LaunchpadProjectDeposits()

	deposit, ok := launchpadProjectDeposits.Get(ownerAddress)
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
func (g *govStakerV1) setLaunchpadProjectDeposit(ownerAddress string, deposit int64) bool {
	state := g.getState()
	launchpadProjectDeposits := state.LaunchpadProjectDeposits()

	launchpadProjectDeposits.Set(ownerAddress, deposit)
	g.setState(state)

	return true
}

// removeLaunchpadProjectDeposit removes a launchpad project deposit record.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//
// Returns:
//   - bool: true if successfully removed
func (g *govStakerV1) removeLaunchpadProjectDeposit(ownerAddress string) bool {
	state := g.getState()
	launchpadProjectDeposits := state.LaunchpadProjectDeposits()

	_, ok := launchpadProjectDeposits.Remove(ownerAddress)
	g.setState(state)

	return ok
}

// addStakeFromLaunchpad adds stake for a launchpad project and updates reward tracking.
// This method creates a special reward ID for launchpad projects and manages their deposit tracking.
//
// Parameters:
//   - address: project wallet address
//   - amount: amount of stake to add
//   - currentTimestamp: current timestamp
func (g *govStakerV1) addStakeFromLaunchpad(address string, amount int64, currentTimestamp int64) error {
	launchpadRewardID := g.makeLaunchpadRewardID(address)
	err := g.addStakeEmissionReward(launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	err = g.addStakeProtocolFeeReward(launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	deposit, exists := g.getLaunchpadProjectDeposit(launchpadRewardID)
	if !exists {
		deposit = 0
	}

	deposit += amount
	g.setLaunchpadProjectDeposit(launchpadRewardID, deposit)

	return nil
}

// removeStakeFromLaunchpad removes stake for a launchpad project and updates reward tracking.
// This method manages launchpad project deposit tracking and ensures non-negative deposits.
//
// Parameters:
//   - address: project wallet address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (g *govStakerV1) removeStakeFromLaunchpad(address string, amount int64, currentTimestamp int64) error {
	launchpadRewardID := g.makeLaunchpadRewardID(address)
	err := g.removeStakeEmissionReward(launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	err = g.removeStakeProtocolFeeReward(launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	deposit, exists := g.getLaunchpadProjectDeposit(launchpadRewardID)
	if !exists {
		deposit = 0
	}

	deposit -= amount
	if deposit < 0 {
		deposit = 0
	}

	g.setLaunchpadProjectDeposit(launchpadRewardID, deposit)

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
func (g *govStakerV1) makeLaunchpadRewardID(address string) string {
	return ufmt.Sprintf("launchpad:%s", address)
}
