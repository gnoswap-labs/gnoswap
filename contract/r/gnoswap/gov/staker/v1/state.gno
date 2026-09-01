package staker

import (
	"errors"
	"math"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gov/staker"
	pf "gno.land/r/gnoswap/protocol_fee"
)

// setUnDelegationLockupPeriod updates the undelegation lockup period.
// This affects all future undelegation operations.
//
// Parameters:
//   - period: new lockup period in seconds
func (g *govStakerV1) setUnDelegationLockupPeriod(_ int, rlm realm, period int64) {
	if err := g.store.SetUnDelegationLockupPeriod(0, rlm, period); err != nil {
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
//   - error: nil on success, otherwise the storage write error
func (g *govStakerV1) setDelegation(_ int, rlm realm, delegationID int64, delegation *staker.Delegation) error {
	return g.store.SetDelegation(0, rlm, delegationID, delegation)
}

// addDelegation adds a new delegation to storage and updates the delegation manager.
//
// Parameters:
//   - delegationID: unique identifier of the delegation to add
//   - delegation: delegation instance to add
//
// Returns:
//   - error: nil on success, otherwise the delegation or manager storage error
func (g *govStakerV1) addDelegation(_ int, rlm realm, delegationID int64, delegation *staker.Delegation) error {
	if err := g.setDelegation(0, rlm, delegationID, delegation); err != nil {
		return err
	}

	delegationManager := g.store.GetDelegationManager()
	resolvedManager := NewDelegationManagerResolver(delegationManager)
	resolvedManager.addDelegation(
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegationID,
	)

	return g.store.SetDelegationManager(0, rlm, delegationManager)
}

// removeDelegation removes a delegation from storage and updates the delegation manager.
//
// Parameters:
//   - delegationID: unique identifier of the delegation to remove
//
// Returns:
//   - error: nil on success, otherwise an error when the delegation is absent or storage fails
func (g *govStakerV1) removeDelegation(_ int, rlm realm, delegationID int64) error {
	delegation := g.getDelegation(delegationID)
	if delegation == nil {
		return errors.New("delegation not found")
	}

	if err := g.store.RemoveDelegation(0, rlm, delegationID); err != nil {
		return err
	}

	delegationManager := g.store.GetDelegationManager()
	resolvedManager := NewDelegationManagerResolver(delegationManager)
	resolvedManager.removeDelegation(
		delegation.DelegateFrom(),
		delegation.DelegateTo(),
		delegationID,
	)

	return g.store.SetDelegationManager(0, rlm, delegationManager)
}

// getUserDelegations retrieves all delegations for a specific user.
//
// Parameters:
//   - user: user's address
//
// Returns:
//   - *bptree.BPTree: tree of user's delegations
func (g *govStakerV1) getUserDelegations(user address) *bptree.BPTree {
	delegationManager := g.store.GetDelegationManager()

	userDelegations, exists := delegationManager.GetDelegatorDelegations(user.String())
	if !exists {
		return staker.NewUserDelegationTree()
	}

	return userDelegations
}

// getUserDelegationsWithDelegatee retrieves all delegations from a user to a specific delegatee.
//
// Parameters:
//   - user: user's address
//   - delegatee: delegatee's address
//
// Returns:
//   - []int64: list of user's delegation IDs to the delegatee
func (g *govStakerV1) getUserDelegationIDsWithDelegatee(user address, delegatee address) []int64 {
	delegationManager := g.store.GetDelegationManager()

	userDelegations, exists := delegationManager.GetDelegatorDelegations(user.String())
	if !exists {
		return nil
	}

	delegateeStr := delegatee.String()
	delegationIDs := userDelegations.Get(delegateeStr)
	if delegationIDs == nil {
		return nil
	}

	ids, ok := delegationIDs.([]int64)
	if !ok {
		return nil
	}

	return ids
}

// addDelegationRecord records a delegation change in the history.
// Updates both total and user delegation histories with cumulative values.
//
// Parameters:
//   - delegateeAddr: address of the delegatee
//   - amount: amount change (positive for delegate, negative for undelegate)
//   - timestamp: timestamp of the delegation change
func (g *govStakerV1) addDelegationRecord(_ int, rlm realm, delegateeAddr address, amount int64, timestamp int64) {
	// Update total delegation history
	g.updateTotalDelegationHistory(0, rlm, amount, timestamp)

	// Update user delegation history
	g.updateUserDelegationHistory(0, rlm, delegateeAddr, amount, timestamp)
}

// updateTotalDelegationHistory updates the total delegation history with cumulative value.
//
// Parameters:
//   - amount: amount change (positive for delegate, negative for undelegate)
//   - timestamp: timestamp of the change
func (g *govStakerV1) updateTotalDelegationHistory(_ int, rlm realm, amount int64, timestamp int64) {
	history := g.store.GetTotalDelegationHistory()

	// Get current total from the most recent entry
	currentTotal := g.getLatestTotalDelegation(history)
	newTotal := gnsmath.SafeAddInt64(currentTotal, amount)

	if newTotal < 0 {
		newTotal = 0
	}

	history.Set(timestamp, newTotal)

	if err := g.store.SetTotalDelegationHistory(0, rlm, history); err != nil {
		panic(err)
	}
}

// updateUserDelegationHistory updates the user delegation history with cumulative values.
// Structure: single BPTree keyed by composite key "addrStr|paddedTimestamp" -> int64
//
// Parameters:
//   - delegateeAddr: address of the delegatee
//   - amount: amount change (positive for delegate, negative for undelegate)
//   - timestamp: timestamp of the change
func (g *govStakerV1) updateUserDelegationHistory(_ int, rlm realm, delegateeAddr address, amount int64, timestamp int64) {
	history := g.store.GetUserDelegationHistory()
	addrStr := delegateeAddr.String()

	// Get current amount from the most recent entry for this user
	currentAmount := g.getLatestUserDelegationByAddress(history, addrStr)
	newAmount := gnsmath.SafeAddInt64(currentAmount, amount)
	if newAmount < 0 {
		newAmount = 0
	}

	// Store new cumulative value under composite key
	history.Set(makeUserHistoryKey(addrStr, timestamp), newAmount)

	if err := g.store.SetUserDelegationHistory(0, rlm, history); err != nil {
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

// getLatestUserDelegationByAddress gets the latest delegation amount for a user
// from the composite-keyed user delegation history.
func (g *govStakerV1) getLatestUserDelegationByAddress(history *bptree.BPTree, addrStr string) int64 {
	lo, hi := userHistoryKeyRange(addrStr)

	latestAmount := int64(0)

	history.ReverseIterate(lo, hi, func(_ string, value any) bool {
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
func (g *govStakerV1) addStakeEmissionReward(_ int, rlm realm, address string, amount int64, currentTimestamp int64) error {
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager := g.store.GetEmissionRewardManager()
	resolvedManager := NewEmissionRewardManagerResolver(emissionRewardManager)

	if err := resolvedManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp); err != nil {
		return err
	}

	if err := resolvedManager.addStake(address, amount, currentTimestamp); err != nil {
		return err
	}

	err := g.store.SetEmissionRewardManager(0, rlm, emissionRewardManager)
	if err != nil {
		return err
	}

	// Emit the emission reward accumulation
	emitUpdateEmissionRewardAccumulation(emissionRewardManager)

	return nil
}

// removeStakeEmissionReward removes stake from emission reward tracking for an address.
// This method updates the emission reward distribution state and removes stake for the specified address.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (g *govStakerV1) removeStakeEmissionReward(_ int, rlm realm, address string, amount int64, currentTimestamp int64) error {
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager := g.store.GetEmissionRewardManager()
	resolvedManager := NewEmissionRewardManagerResolver(emissionRewardManager)

	if err := resolvedManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentTimestamp); err != nil {
		return err
	}

	if err := resolvedManager.removeStake(address, amount, currentTimestamp); err != nil {
		return err
	}

	if err := g.store.SetEmissionRewardManager(0, rlm, emissionRewardManager); err != nil {
		return err
	}

	// Emit the emission reward accumulation
	emitUpdateEmissionRewardAccumulation(emissionRewardManager)

	return nil
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
func (g *govStakerV1) claimRewardsEmissionReward(_ int, rlm realm, address string, currentTimestamp int64) (int64, error) {
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

	if err := g.store.SetEmissionRewardManager(0, rlm, emissionRewardManager); err != nil {
		return 0, err
	}

	// Emit the emission reward accumulation
	emitUpdateEmissionRewardAccumulation(emissionRewardManager)

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
	return launchpadProjectDeposits.RemoveDeposit(ownerAddress)
}

// addStakeProtocolFeeReward adds stake to protocol fee reward tracking for an address.
// This method distributes protocol fees and updates the protocol fee reward state.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to add
//   - currentTimestamp: current timestamp
func (g *govStakerV1) addStakeProtocolFeeReward(_ int, rlm realm, address string, amount int64, currentTimestamp int64) error {
	accruedAmounts := pf.ConsumeAccrualPendingProtocolFees(cross(rlm))

	protocolFeeRewardManager := g.store.GetProtocolFeeRewardManager()
	resolvedManager := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)

	if err := resolvedManager.updateAccumulatedProtocolFeeX128PerStake(accruedAmounts, currentTimestamp); err != nil {
		return err
	}

	if err := resolvedManager.addStake(address, amount, currentTimestamp); err != nil {
		return err
	}

	err := g.store.SetProtocolFeeRewardManager(0, rlm, protocolFeeRewardManager)
	if err != nil {
		return err
	}

	// Emit the protocol fee reward accumulation
	emitUpdateProtocolFeeRewardAccumulation(protocolFeeRewardManager, accruedAmounts)

	return nil
}

// removeStakeProtocolFeeReward removes stake from protocol fee reward tracking for an address.
// This method distributes protocol fees and updates the protocol fee reward state.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (g *govStakerV1) removeStakeProtocolFeeReward(_ int, rlm realm, address string, amount int64, currentTimestamp int64) error {
	accruedAmounts := pf.ConsumeAccrualPendingProtocolFees(cross(rlm))

	protocolFeeRewardManager := g.store.GetProtocolFeeRewardManager()
	resolvedManager := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)

	if err := resolvedManager.updateAccumulatedProtocolFeeX128PerStake(accruedAmounts, currentTimestamp); err != nil {
		return err
	}

	if err := resolvedManager.removeStake(address, amount, currentTimestamp); err != nil {
		return err
	}

	if err := g.store.SetProtocolFeeRewardManager(0, rlm, protocolFeeRewardManager); err != nil {
		return err
	}

	// Emit the protocol fee reward accumulation
	emitUpdateProtocolFeeRewardAccumulation(protocolFeeRewardManager, accruedAmounts)

	return nil
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
func (g *govStakerV1) claimRewardsProtocolFeeReward(_ int, rlm realm, address string, currentTimestamp int64) (map[string]int64, error) {
	// Claiming pays out of gov/staker's own balance, so the reserved fees are pulled in
	// from the protocol fee realm first. The stake-change paths need no transfer.
	pf.DistributeProtocolFee(cross(rlm))

	accruedAmounts := pf.ConsumeAccrualPendingProtocolFees(cross(rlm))

	protocolFeeRewardManager := g.store.GetProtocolFeeRewardManager()
	resolvedManager := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)

	if err := resolvedManager.updateAccumulatedProtocolFeeX128PerStake(accruedAmounts, currentTimestamp); err != nil {
		return nil, err
	}

	rewards, err := resolvedManager.claimRewards(address, currentTimestamp)
	if err != nil {
		return nil, err
	}

	if err := g.store.SetProtocolFeeRewardManager(0, rlm, protocolFeeRewardManager); err != nil {
		return nil, err
	}

	// Emit the protocol fee reward accumulation
	emitUpdateProtocolFeeRewardAccumulation(protocolFeeRewardManager, accruedAmounts)

	return rewards, nil
}

// claimAccruedProtocolFeeRewardByTokenPath processes an observed protocol fee accrual for one token.
func (g *govStakerV1) claimAccruedProtocolFeeRewardByTokenPath(address string, tokenPath string, accruedAmount int64, currentTimestamp int64) (*staker.ProtocolFeeRewardManager, int64, bool, error) {
	if accruedAmount == 0 {
		return nil, 0, false, nil
	}

	protocolFeeRewardManager := g.store.GetProtocolFeeRewardManager()
	resolvedManager := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)

	if err := resolvedManager.updateAccumulatedProtocolFeeX128PerStakeForToken(tokenPath, accruedAmount, currentTimestamp); err != nil {
		return nil, 0, false, err
	}

	reward, err := resolvedManager.claimRewardForToken(address, tokenPath, currentTimestamp)
	if err != nil {
		return nil, 0, false, err
	}

	return protocolFeeRewardManager, reward, true, nil
}

// claimRewardProtocolFeeRewardByTokenPath claims one protocol fee reward token for an address.
func (g *govStakerV1) claimRewardProtocolFeeRewardByTokenPath(_ int, rlm realm, address string, tokenPath string, currentTimestamp int64) (int64, error) {
	pf.DistributeProtocolFeeByTokenPath(cross(rlm), tokenPath)

	accruedAmount := pf.ConsumeAccrualPendingProtocolFeeByTokenPath(cross(rlm), tokenPath)
	protocolFeeRewardManager, reward, processed, err := g.claimAccruedProtocolFeeRewardByTokenPath(address, tokenPath, accruedAmount, currentTimestamp)
	if err != nil {
		return 0, err
	}
	if !processed {
		return 0, nil
	}

	if err := g.store.SetProtocolFeeRewardManager(0, rlm, protocolFeeRewardManager); err != nil {
		return 0, err
	}

	emitUpdateProtocolFeeRewardAccumulation(protocolFeeRewardManager, map[string]int64{tokenPath: accruedAmount})

	return reward, nil
}

// getAccrualPendingProtocolFees retrieves the protocol fee amounts reserved for
// gov/staker, limited to the tokens that collected a fee since the last accrual.
//
// The reserved amount is recorded when a fee reaches the protocol fee realm, before it
// is transferred out, so accrual does not depend on a transfer happening. This is the
// read-only counterpart of pf.ConsumeAccrualPendingProtocolFees: a query never advances
// accrual state.
//
// Returns:
//   - map[string]int64: accrued amounts by token path
func (g *govStakerV1) getAccrualPendingProtocolFees() map[string]int64 {
	return pf.GetAccrualPendingProtocolFees()
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
//   - error: nil on success, otherwise the storage write error
func (g *govStakerV1) setLaunchpadProjectDeposit(_ int, rlm realm, ownerAddress string, deposit int64) error {
	launchpadDeposits := g.store.GetLaunchpadProjectDeposits()
	resolvedDeposits := NewLaunchpadProjectDepositsResolver(launchpadDeposits)
	resolvedDeposits.setLaunchpadProjectDeposit(ownerAddress, deposit)

	return g.store.SetLaunchpadProjectDeposits(0, rlm, launchpadDeposits)
}

// addStakeFromLaunchpad adds stake for a launchpad project and updates reward tracking.
// This method creates a special reward ID for launchpad projects and manages their deposit tracking.
//
// Parameters:
//   - address: project wallet address
//   - amount: amount of stake to add
//   - currentTimestamp: current timestamp
func (g *govStakerV1) addStakeFromLaunchpad(_ int, rlm realm, address string, amount int64, currentTimestamp int64) error {
	launchpadRewardID := g.makeLaunchpadRewardID(address)
	err := g.addStakeEmissionReward(0, rlm, launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	err = g.addStakeProtocolFeeReward(0, rlm, launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	deposit, exists := g.getLaunchpadProjectDeposit(launchpadRewardID)
	if !exists {
		deposit = 0
	}

	deposit = gnsmath.SafeAddInt64(deposit, amount)
	if err := g.setLaunchpadProjectDeposit(0, rlm, launchpadRewardID, deposit); err != nil {
		return err
	}

	return nil
}

// removeStakeFromLaunchpad removes stake for a launchpad project and updates reward tracking.
// This method manages launchpad project deposit tracking and ensures non-negative deposits.
//
// Parameters:
//   - address: project wallet address
//   - amount: amount of stake to remove
//   - currentTimestamp: current timestamp
func (g *govStakerV1) removeStakeFromLaunchpad(_ int, rlm realm, address string, amount int64, currentTimestamp int64) error {
	launchpadRewardID := g.makeLaunchpadRewardID(address)
	err := g.removeStakeEmissionReward(0, rlm, launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	err = g.removeStakeProtocolFeeReward(0, rlm, launchpadRewardID, amount, currentTimestamp)
	if err != nil {
		return err
	}

	deposit, exists := g.getLaunchpadProjectDeposit(launchpadRewardID)
	if !exists {
		deposit = 0
	}

	deposit = gnsmath.SafeSubInt64(deposit, amount)
	if deposit < 0 {
		deposit = 0
	}

	if err := g.setLaunchpadProjectDeposit(0, rlm, launchpadRewardID, deposit); err != nil {
		return err
	}

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
