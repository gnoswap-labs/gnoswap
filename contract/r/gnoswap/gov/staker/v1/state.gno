package v1

import (
	"time"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gov/staker"
	pf "gno.land/r/gnoswap/protocol_fee"
)

// setUnDelegationLockupPeriod updates the undelegation lockup period.
// This affects all future undelegation operations.
//
// Parameters:
//   - period: new lockup period in seconds
func (g *govStakerV1) setUnDelegationLockupPeriod(period int64) {
	if err := g.store.SetUnDelegationLockupPeriod(period); err != nil {
		panic(err)
	}
}

// nextDelegationID generates and returns the next unique delegation ID.
//
// Returns:
//   - int64: next available delegation ID
func (g *govStakerV1) nextDelegationID() int64 {
	nextID, err := g.store.IncrementDelegationNextID()
	if err != nil {
		panic(err)
	}
	return nextID
}

// getDelegation retrieves a delegation by its ID.
//
// Parameters:
//   - delegationID: unique identifier of the delegation
//
// Returns:
//   - *Delegation: delegation instance or nil if not found
func (g *govStakerV1) getDelegation(delegationID int64) *staker.Delegation {
	delegation, exists := g.store.GetDelegation(delegationID)
	if !exists {
		return nil
	}
	return delegation
}

// setDelegation stores or updates a delegation in the storage tree.
//
// Parameters:
//   - delegationID: unique identifier of the delegation
//   - delegation: delegation instance to store
//
// Returns:
//   - bool: true if successfully stored
func (g *govStakerV1) setDelegation(delegationID int64, delegation *staker.Delegation) bool {
	if err := g.store.SetDelegation(delegationID, delegation); err != nil {
		return false
	}
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
func (g *govStakerV1) addDelegation(delegationID int64, delegation *staker.Delegation) bool {
	if ok := g.setDelegation(delegationID, delegation); !ok {
		return false
	}

	// Update delegation manager
	delegationManager, err := g.store.GetDelegationManager()
	if err != nil {
		return false
	}
	resolvedManager := &DelegationManagerResolver{delegationManager}
	resolvedManager.addDelegation(
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegationID,
	)
	if err := g.store.SetDelegationManager(delegationManager); err != nil {
		return false
	}

	// Update user delegations in store
	if err := g.store.AddUserDelegation(
		string(delegation.DelegateFrom()),
		string(delegation.DelegateTo()),
		delegationID,
	); err != nil {
		return false
	}

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

	// Remove from store
	if err := g.store.RemoveDelegation(delegationID); err != nil {
		return false
	}

	// Update delegation manager
	delegationManager, err := g.store.GetDelegationManager()
	if err != nil {
		return false
	}
	resolvedManager := &DelegationManagerResolver{delegationManager}
	resolvedManager.removeDelegation(
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegationID,
	)
	if err := g.store.SetDelegationManager(delegationManager); err != nil {
		return false
	}

	// Update user delegations in store
	if err := g.store.RemoveUserDelegation(
		string(delegation.DelegateFrom()),
		string(delegation.DelegateTo()),
		delegationID,
	); err != nil {
		return false
	}

	return true
}

// getUserDelegations retrieves all delegations for a specific user.
//
// Parameters:
//   - user: user's address
//
// Returns:
//   - []*Delegation: list of user's delegations
func (g *govStakerV1) getUserDelegations(user address) (delegations []*staker.Delegation) {
	delegationManager, err := g.store.GetDelegationManager()
	if err != nil {
		return delegations
	}
	resolvedManager := &DelegationManagerResolver{delegationManager}
	for _, delegationID := range resolvedManager.GetUserDelegationIDs(user) {
		if delegation := g.getDelegation(delegationID); delegation != nil {
			delegations = append(delegations, delegation)
		}
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
func (g *govStakerV1) getUserDelegationsWithDelegatee(user address, delegatee address) (delegations []*staker.Delegation) {
	delegationManager, err := g.store.GetDelegationManager()
	if err != nil {
		return delegations
	}
	resolvedManager := &DelegationManagerResolver{delegationManager}
	for _, delegationID := range resolvedManager.GetUserDelegationIDsWithDelegatee(user, delegatee) {
		if delegation := g.getDelegation(delegationID); delegation != nil {
			delegations = append(delegations, delegation)
		}
	}
	return delegations
}

// getDelegationHistory returns the current delegation history.
//
// Returns:
//   - DelegationHistory: chronological list of delegation records
func (g *govStakerV1) getDelegationHistory() DelegationHistory {
	history, err := g.store.GetDelegationHistory()
	if err != nil {
		panic(err)
	}
	// Create a new DelegationHistory to avoid realm conversion issues
	result := make(DelegationHistory, len(history))
	copy(result, history)
	return result
}

// addDelegationRecord adds a new delegation record to history and updates snapshots.
//
// Parameters:
//   - delegationRecord: delegation record to add
func (g *govStakerV1) addDelegationRecord(delegationRecord *staker.DelegationRecord) {
	// Add to history
	if err := g.store.AddDelegationRecord(delegationRecord); err != nil {
		panic(err)
	}

	// Update snapshots
	timestamp := delegationRecord.CreatedAt()
	snapshot, exists := g.store.GetDelegationSnapshot(timestamp)
	if !exists {
		snapshot = make(staker.DelegationSnapshot)
	}

	// Add record to snapshot
	if snapshot == nil {
		snapshot = make(staker.DelegationSnapshot)
	}
	resolver := NewDelegationSnapshotResolver(snapshot)
	snapshot = resolver.AddRecord(delegationRecord)

	if err := g.store.SetDelegationSnapshot(timestamp, snapshot); err != nil {
		panic(err)
	}
}

// setDelegationHistory replaces the current delegation history.
//
// Parameters:
//   - history: new delegation history to set
func (g *govStakerV1) setDelegationHistory(history DelegationHistory) {
	// Clear existing history and re-add all records
	// Note: This is inefficient but maintains compatibility
	for _, record := range history {
		if err := g.store.AddDelegationRecord(record); err != nil {
			panic(err)
		}
	}
}

// getDelegationSnapshots returns the current delegation snapshots.
//
// Returns:
//   - DelegationSnapshot: current delegation state for all delegatees
func (g *govStakerV1) getDelegationSnapshots() staker.DelegationSnapshot {
	// Get the latest snapshot
	snapshots, err := g.store.GetAllDelegationSnapshots()
	if err != nil {
		panic(err)
	}

	if snapshots.Size() == 0 {
		return make(staker.DelegationSnapshot)
	}

	// Get the most recent snapshot
	_, value := snapshots.GetByIndex(snapshots.Size() - 1)
	snapshot, ok := value.(staker.DelegationSnapshot)
	if !ok {
		panic(ufmt.Sprintf("failed to cast to DelegationSnapshot: %T", value))
	}

	return snapshot
}

// setDelegationSnapshots replaces the current delegation snapshots.
//
// Parameters:
//   - snapshot: new delegation snapshot to set
func (g *govStakerV1) setDelegationSnapshots(snapshot staker.DelegationSnapshot) {
	// Set with current timestamp
	timestamp := time.Now().Unix()
	if err := g.store.SetDelegationSnapshot(timestamp, snapshot); err != nil {
		panic(err)
	}
}

// addStakeEmissionReward adds stake to emission reward tracking for an address.
// This method updates the emission reward distribution state and adds stake for the specified address.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to add
//   - currentTimestamp: current timestamp
func (g *govStakerV1) addStakeEmissionReward(address string, amount int64, currentTimestamp int64) error {
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager, err := g.store.GetEmissionRewardManager()
	if err != nil {
		return err
	}
	resolvedManager := NewEmissionRewardManagerResolver(emissionRewardManager)

	err = resolvedManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp)
	if err != nil {
		return err
	}

	err = resolvedManager.addStake(address, amount, currentTimestamp)
	if err != nil {
		return err
	}

	return g.store.SetEmissionRewardManager(emissionRewardManager)
}

// removeStakeEmissionReward removes stake from emission reward tracking for an address.
// This method updates the emission reward distribution state and removes stake for the specified address.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (g *govStakerV1) removeStakeEmissionReward(address string, amount int64, currentTimestamp int64) error {
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager, err := g.store.GetEmissionRewardManager()
	if err != nil {
		return err
	}
	resolvedManager := NewEmissionRewardManagerResolver(emissionRewardManager)

	err = resolvedManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp)
	if err != nil {
		return err
	}

	err = resolvedManager.removeStake(address, amount, currentTimestamp)
	if err != nil {
		return err
	}

	return g.store.SetEmissionRewardManager(emissionRewardManager)
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
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager, err := g.store.GetEmissionRewardManager()
	if err != nil {
		return 0, err
	}
	resolvedManager := NewEmissionRewardManagerResolver(emissionRewardManager)

	err = resolvedManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp)
	if err != nil {
		return 0, err
	}

	amount, err := resolvedManager.claimRewards(address, currentTimestamp)
	if err != nil {
		return 0, err
	}

	if err := g.store.SetEmissionRewardManager(emissionRewardManager); err != nil {
		return 0, err
	}

	return amount, nil
}

// addStakeProtocolFeeReward adds stake to protocol fee reward tracking for an address.
// This method distributes protocol fees and updates the protocol fee reward state.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to add
//   - currentTimestamp: current timestamp
func (g *govStakerV1) addStakeProtocolFeeReward(address string, amount int64, currentTimestamp int64) error {
	pf.DistributeProtocolFee(cross)

	distributedAmounts := g.getDistributedProtocolFees()

	protocolFeeRewardManager, err := g.store.GetProtocolFeeRewardManager()
	if err != nil {
		return err
	}
	resolvedManager := &ProtocolFeeRewardManagerResolver{protocolFeeRewardManager}

	err = resolvedManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentTimestamp)
	if err != nil {
		return err
	}

	err = resolvedManager.addStake(address, amount, currentTimestamp)
	if err != nil {
		return err
	}

	return g.store.SetProtocolFeeRewardManager(protocolFeeRewardManager)
}

// removeStakeProtocolFeeReward removes stake from protocol fee reward tracking for an address.
// This method distributes protocol fees and updates the protocol fee reward state.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (g *govStakerV1) removeStakeProtocolFeeReward(address string, amount int64, currentTimestamp int64) error {
	pf.DistributeProtocolFee(cross)

	distributedAmounts := g.getDistributedProtocolFees()

	protocolFeeRewardManager, err := g.store.GetProtocolFeeRewardManager()
	if err != nil {
		return err
	}
	resolvedManager := &ProtocolFeeRewardManagerResolver{protocolFeeRewardManager}

	err = resolvedManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentTimestamp)
	if err != nil {
		return err
	}

	err = resolvedManager.removeStake(address, amount, currentTimestamp)
	if err != nil {
		return err
	}

	return g.store.SetProtocolFeeRewardManager(protocolFeeRewardManager)
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
	pf.DistributeProtocolFee(cross)

	distributedAmounts := g.getDistributedProtocolFees()

	protocolFeeRewardManager, err := g.store.GetProtocolFeeRewardManager()
	if err != nil {
		return nil, err
	}
	resolvedManager := &ProtocolFeeRewardManagerResolver{protocolFeeRewardManager}

	err = resolvedManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentTimestamp)
	if err != nil {
		return nil, err
	}

	rewards, err := resolvedManager.claimRewards(address, currentTimestamp)
	if err != nil {
		return nil, err
	}

	if err := g.store.SetProtocolFeeRewardManager(protocolFeeRewardManager); err != nil {
		return nil, err
	}

	return rewards, nil
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
	launchpadDeposits, err := g.store.GetLaunchpadProjectDeposits()
	if err != nil {
		return 0, false
	}
	resolvedDeposits := &LaunchpadProjectDepositsResolver{launchpadDeposits}
	return resolvedDeposits.getLaunchpadProjectDeposit(ownerAddress)
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
	launchpadDeposits, err := g.store.GetLaunchpadProjectDeposits()
	if err != nil {
		return false
	}
	resolvedDeposits := &LaunchpadProjectDepositsResolver{launchpadDeposits}
	resolvedDeposits.setLaunchpadProjectDeposit(ownerAddress, deposit)
	if err := g.store.SetLaunchpadProjectDeposits(launchpadDeposits); err != nil {
		return false
	}
	return true
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
