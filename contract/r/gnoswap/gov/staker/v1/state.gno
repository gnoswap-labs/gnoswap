package v1

import (
	"math"
	"strconv"

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
	counter := g.store.GetDelegationCounter()

	return counter.Next()
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
	delegationManager := g.store.GetDelegationManager()
	resolvedManager := NewDelegationManagerResolver(delegationManager)
	resolvedManager.addDelegation(
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegationID,
	)
	if err := g.store.SetDelegationManager(delegationManager); err != nil {
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
	delegationManager := g.store.GetDelegationManager()
	resolvedManager := NewDelegationManagerResolver(delegationManager)
	resolvedManager.removeDelegation(
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegationID,
	)
	if err := g.store.SetDelegationManager(delegationManager); err != nil {
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
	delegationManager := g.store.GetDelegationManager()
	allDelegations := g.store.GetAllDelegations()
	delegations = make([]*staker.Delegation, 0)

	userDelegations, exists := delegationManager.GetDelegatorDelegations(user.String())
	if !exists {
		return delegations
	}

	userDelegations.Iterate("", "", func(delegatee string, value interface{}) bool {
		delegationIDs, ok := value.([]int64)
		if !ok {
			return false
		}

		for _, id := range delegationIDs {
			idStr := strconv.FormatInt(id, 10)
			if delegation, exists := allDelegations.Get(idStr); exists {
				if d, ok := delegation.(*staker.Delegation); ok {
					delegations = append(delegations, d)
				}
			}
		}
		return false
	})

	return delegations
}

// getUserDelegationsWithDelegatee retrieves all delegations from a user to a specific delegatee.
//
// Parameters:
//   - user: user's address
//   - delegatee: delegatee's address
//
// Returns:
//   - []*Delegation: list of user's delegations to the delegatee
func (g *govStakerV1) getUserDelegationsWithDelegatee(user address, delegatee address) (delegations []*staker.Delegation) {
	delegationManager := g.store.GetDelegationManager()
	allDelegations := g.store.GetAllDelegations()
	delegations = make([]*staker.Delegation, 0)

	// Direct access without GetDelegateeIDs wrapper to avoid redundant function call
	userDelegations, exists := delegationManager.GetDelegatorDelegations(user.String())
	if !exists {
		return delegations
	}

	delegateeStr := delegatee.String()
	if delegationIDs, exists := userDelegations.Get(delegateeStr); exists {
		if ids, ok := delegationIDs.([]int64); ok {
			for _, id := range ids {
				idStr := strconv.FormatInt(id, 10)
				if delegation, exists := allDelegations.Get(idStr); exists {
					if d, ok := delegation.(*staker.Delegation); ok {
						delegations = append(delegations, d)
					}
				}
			}
		}
	}

	return delegations
}

// addDelegationRecord records a delegation change in the history.
// Updates both total and user delegation histories with cumulative values.
//
// Parameters:
//   - delegateeAddr: address of the delegatee
//   - amount: amount change (positive for delegate, negative for undelegate)
//   - timestamp: timestamp of the delegation change
func (g *govStakerV1) addDelegationRecord(delegateeAddr address, amount int64, timestamp int64) {
	// Update total delegation history
	g.updateTotalDelegationHistory(amount, timestamp)

	// Update user delegation history
	g.updateUserDelegationHistory(delegateeAddr, amount, timestamp)
}

// updateTotalDelegationHistory updates the total delegation history with cumulative value.
//
// Parameters:
//   - amount: amount change (positive for delegate, negative for undelegate)
//   - timestamp: timestamp of the change
func (g *govStakerV1) updateTotalDelegationHistory(amount int64, timestamp int64) {
	history := g.store.GetTotalDelegationHistory()

	// Get current total from the most recent entry
	currentTotal := g.getLatestTotalDelegation(history)
	newTotal := safeAddInt64(currentTotal, amount)

	if newTotal < 0 {
		newTotal = 0
	}

	history.Set(timestamp, newTotal)

	if err := g.store.SetTotalDelegationHistory(history); err != nil {
		panic(err)
	}
}

// updateUserDelegationHistory updates the user delegation history with cumulative values.
// Structure: address -> *UintTree[timestamp -> int64]
//
// Parameters:
//   - delegateeAddr: address of the delegatee
//   - amount: amount change (positive for delegate, negative for undelegate)
//   - timestamp: timestamp of the change
func (g *govStakerV1) updateUserDelegationHistory(delegateeAddr address, amount int64, timestamp int64) {
	history := g.store.GetUserDelegationHistory()
	addrStr := delegateeAddr.String()

	// Get or create user's timestamp tree
	var userHistory *staker.UintTree

	if existingHistory, exists := history.Get(addrStr); exists {
		userHistoryInt, ok := existingHistory.(*staker.UintTree)
		if !ok {
			panic(ufmt.Sprintf("invalid user history type: %T", existingHistory))
		}

		userHistory = userHistoryInt
	} else {
		userHistory = staker.NewUintTree()
	}

	// Get current amount from the most recent entry
	currentAmount := g.getLatestUserDelegation(userHistory)
	newAmount := safeAddInt64(currentAmount, amount)
	if newAmount < 0 {
		newAmount = 0
	}

	// Store new cumulative value at this timestamp
	userHistory.Set(timestamp, newAmount)
	history.Set(addrStr, userHistory)

	if err := g.store.SetUserDelegationHistory(history); err != nil {
		panic(err)
	}
}

// getLatestTotalDelegation gets the latest total delegation amount from history.
func (g *govStakerV1) getLatestTotalDelegation(history *staker.UintTree) int64 {
	if history.Size() == 0 {
		return 0
	}

	latestTotal := int64(0)

	history.ReverseIterate(0, math.MaxInt64, func(key int64, value any) bool {
		totalInt, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("invalid total type: %T", value))
		}

		latestTotal = totalInt

		return true // stop after first (most recent) entry
	})

	return latestTotal
}

// getLatestUserDelegation gets the latest delegation amount for a user from their history.
func (g *govStakerV1) getLatestUserDelegation(userHistory *staker.UintTree) int64 {
	if userHistory.Size() == 0 {
		return 0
	}

	latestAmount := int64(0)

	userHistory.ReverseIterate(0, math.MaxInt64, func(key int64, value any) bool {
		amountInt, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("invalid amount type: %T", value))
		}

		latestAmount = amountInt

		return true // stop after first (most recent) entry
	})

	return latestAmount
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

	emissionRewardManager := g.store.GetEmissionRewardManager()
	resolvedManager := NewEmissionRewardManagerResolver(emissionRewardManager)

	if err := resolvedManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp); err != nil {
		return err
	}

	if err := resolvedManager.addStake(address, amount, currentTimestamp); err != nil {
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

	emissionRewardManager := g.store.GetEmissionRewardManager()
	resolvedManager := NewEmissionRewardManagerResolver(emissionRewardManager)

	if err := resolvedManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp); err != nil {
		return err
	}

	if err := resolvedManager.removeStake(address, amount, currentTimestamp); err != nil {
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

	emissionRewardManager := g.store.GetEmissionRewardManager()
	resolvedManager := NewEmissionRewardManagerResolver(emissionRewardManager)

	if err := resolvedManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp); err != nil {
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

// removeLaunchpadProjectDeposit removes a launchpad project deposit record.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//
// Returns:
//   - bool: true if successfully removed
func (g *govStakerV1) removeLaunchpadProjectDeposit(ownerAddress string) bool {
	launchpadProjectDeposits := g.store.GetLaunchpadProjectDeposits()

	resolver := NewLaunchpadProjectDepositsResolver(launchpadProjectDeposits)
	return resolver.RemoveDeposit(ownerAddress)
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

	protocolFeeRewardManager := g.store.GetProtocolFeeRewardManager()
	resolvedManager := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)

	if err := resolvedManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentTimestamp); err != nil {
		return err
	}

	if err := resolvedManager.addStake(address, amount, currentTimestamp); err != nil {
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

	protocolFeeRewardManager := g.store.GetProtocolFeeRewardManager()
	resolvedManager := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)

	if err := resolvedManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentTimestamp); err != nil {
		return err
	}

	if err := resolvedManager.removeStake(address, amount, currentTimestamp); err != nil {
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

	protocolFeeRewardManager := g.store.GetProtocolFeeRewardManager()
	resolvedManager := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)

	if err := resolvedManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentTimestamp); err != nil {
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
	launchpadDeposits := g.store.GetLaunchpadProjectDeposits()
	resolvedDeposits := NewLaunchpadProjectDepositsResolver(launchpadDeposits)
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
	launchpadDeposits := g.store.GetLaunchpadProjectDeposits()
	resolvedDeposits := NewLaunchpadProjectDepositsResolver(launchpadDeposits)
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

	deposit = safeAddInt64(deposit, amount)
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

	deposit = safeSubInt64(deposit, amount)
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
	return "launchpad:" + address
}
