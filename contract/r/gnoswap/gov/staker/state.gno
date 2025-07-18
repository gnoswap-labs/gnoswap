package staker

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/emission"
	protocol_fee "gno.land/r/gnoswap/v1/protocol_fee"
)

// Global state variables for staker contract
var (
	// unDelegationLockupPeriod defines the time period (in seconds) that undelegated tokens must wait before collection
	unDelegationLockupPeriod int64

	// delegationCounter provides unique delegation IDs for new delegations
	delegationCounter *Counter
	// delegations stores all delegation records indexed by delegation ID
	delegations       *avl.Tree
	// delegationManager tracks user delegation relationships and provides efficient lookup
	delegationManager *DelegationManager

	// delegationHistory maintains chronological record of all delegation events for snapshot calculations
	delegationHistory   DelegationHistory
	// delegationSnapshots stores current delegation state for each delegatee
	delegationSnapshots DelegationSnapshot

	// emissionRewardManager handles distribution and tracking of GNS emission rewards to stakers
	emissionRewardManager    *EmissionRewardManager
	// protocolFeeRewardManager handles distribution and tracking of multi-token protocol fee rewards
	protocolFeeRewardManager *ProtocolFeeRewardManager

	// launchpadProjectDeposits tracks xGNS deposits for launchpad project wallets
	launchpadProjectDeposits *avl.Tree // project owner address -> deposit amount

	// emissionRewardBalance tracks the current balance of emission rewards (unused)
	emissionRewardBalance int64
	// protocolFeeBalances tracks current balances of protocol fees by token (unused)
	protocolFeeBalances   map[string]int64
)

// init initializes the global state variables with default values and empty structures
func init() {
	// Default lockup period is 7 days
	unDelegationLockupPeriod = 60 * 60 * 24 * 7 // 7 days

	// Initialize delegation tracking structures
	delegationCounter = NewCounter()
	delegations = avl.NewTree()
	delegationManager = NewDelegationManager()

	// Initialize delegation history and snapshot tracking
	delegationHistory = make(DelegationHistory, 0)
	delegationSnapshots = make(DelegationSnapshot)

	// Initialize reward management systems
	emissionRewardManager = NewEmissionRewardManager()
	protocolFeeRewardManager = NewProtocolFeeRewardManager()

	// Initialize launchpad integration
	launchpadProjectDeposits = avl.NewTree()
}

// getUnDelegationLockupPeriod returns the current undelegation lockup period in seconds.
//
// Returns:
//   - int64: lockup period in seconds
func getUnDelegationLockupPeriod() int64 {
	return unDelegationLockupPeriod
}

// setUnDelegationLockupPeriod updates the undelegation lockup period.
// This affects all future undelegation operations.
//
// Parameters:
//   - period: new lockup period in seconds
func setUnDelegationLockupPeriod(period int64) {
	unDelegationLockupPeriod = period
}

// getCurrentDelegationID returns the current delegation counter value.
//
// Returns:
//   - int64: current delegation ID counter
func getCurrentDelegationID() int64 {
	return delegationCounter.Get()
}

// nextDelegationID generates and returns the next unique delegation ID.
//
// Returns:
//   - int64: next available delegation ID
func nextDelegationID() int64 {
	return delegationCounter.next()
}

// getDelegations returns the delegation storage tree.
//
// Returns:
//   - *avl.Tree: delegation storage tree
func getDelegations() *avl.Tree {
	return delegations
}

// getDelegation retrieves a delegation by its ID.
//
// Parameters:
//   - delegationID: unique identifier of the delegation
//
// Returns:
//   - *Delegation: delegation instance or nil if not found
func getDelegation(delegationID int64) *Delegation {
	id := formatInt(delegationID)
	delegation, ok := delegations.Get(id)
	if !ok {
		return nil
	}

	return delegation.(*Delegation)
}

// setDelegation stores or updates a delegation in the storage tree.
//
// Parameters:
//   - delegationID: unique identifier of the delegation
//   - delegation: delegation instance to store
//
// Returns:
//   - bool: true if successfully stored
func setDelegation(delegationID int64, delegation *Delegation) bool {
	id := formatInt(delegationID)

	delegations.Set(id, delegation)

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
func addDelegation(delegationID int64, delegation *Delegation) bool {
	if ok := setDelegation(delegationID, delegation); !ok {
		return false
	}

	delegationManager.addDelegation(
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
func removeDelegation(delegationID int64) bool {
	delegation := getDelegation(delegationID)
	if delegation == nil {
		return false
	}

	id := formatInt(delegation.ID())
	_, ok := delegations.Remove(id)

	delegationManager.removeDelegation(
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
//   - []*Delegation: list of user's delegations
func getUserDelegations(user std.Address) []*Delegation {
	delegations := make([]*Delegation, 0)

	for _, delegationID := range delegationManager.GetUserDelegationIDs(user) {
		delegations = append(delegations, getDelegation(delegationID))
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
func getUserDelegationsWithDelegatee(user std.Address, delegatee std.Address) []*Delegation {
	delegations := make([]*Delegation, 0)

	for _, delegationID := range delegationManager.GetUserDelegationIDs(user) {
		delegations = append(delegations, getDelegation(delegationID))
	}

	return delegations
}

// getDelegationHistory returns the current delegation history.
//
// Returns:
//   - DelegationHistory: chronological list of delegation records
func getDelegationHistory() DelegationHistory {
	return delegationHistory
}

// addDelegationRecord adds a new delegation record to history and updates snapshots.
//
// Parameters:
//   - delegationRecord: delegation record to add
func addDelegationRecord(delegationRecord *DelegationRecord) {
	delegationHistory = delegationHistory.addRecord(delegationRecord)
	delegationSnapshots = delegationSnapshots.addRecord(delegationRecord)
}

// setDelegationHistory replaces the current delegation history.
//
// Parameters:
//   - history: new delegation history to set
func setDelegationHistory(history DelegationHistory) {
	delegationHistory = history
}

// getDelegationSnapshots returns the current delegation snapshots.
//
// Returns:
//   - DelegationSnapshot: current delegation state for all delegatees
func getDelegationSnapshots() DelegationSnapshot {
	return delegationSnapshots
}

// setDelegationSnapshots replaces the current delegation snapshots.
//
// Parameters:
//   - snapshot: new delegation snapshot to set
func setDelegationSnapshots(snapshot DelegationSnapshot) {
	delegationSnapshots = snapshot
}

// addStakeEmissionReward adds stake to emission reward tracking for an address.
// This method updates the emission reward distribution state and adds stake for the specified address.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to add
//   - currentHeight: current block height
func addStakeEmissionReward(address string, amount int64, currentHeight int64) {
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentHeight)
	emissionRewardManager.addStake(address, amount, currentHeight)
}

// removeStakeEmissionReward removes stake from emission reward tracking for an address.
// This method updates the emission reward distribution state and removes stake for the specified address.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentHeight: current block height
func removeStakeEmissionReward(address string, amount int64, currentHeight int64) {
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentHeight)
	emissionRewardManager.removeStake(address, amount, currentHeight)
}

// claimRewardsEmissionReward claims emission rewards for an address.
// This method updates the emission reward distribution state and processes reward claiming.
//
// Parameters:
//   - address: staker's address claiming rewards
//   - currentHeight: current block height
//
// Returns:
//   - int64: amount of emission rewards claimed
//   - error: nil on success, error if claiming fails
func claimRewardsEmissionReward(address string, currentHeight int64) (int64, error) {
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentHeight)
	return emissionRewardManager.claimRewards(address, currentHeight)
}

// addStakeProtocolFeeReward adds stake to protocol fee reward tracking for an address.
// This method distributes protocol fees and updates the protocol fee reward state.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to add
//   - currentHeight: current block height
func addStakeProtocolFeeReward(address string, amount int64, currentHeight int64) {
	protocol_fee.DistributeProtocolFee(cross)

	distributedAmounts := getDistributedProtocolFees()

	protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentHeight)
	protocolFeeRewardManager.addStake(address, amount, currentHeight)
}

// removeStakeProtocolFeeReward removes stake from protocol fee reward tracking for an address.
// This method distributes protocol fees and updates the protocol fee reward state.
//
// Parameters:
//   - address: staker's address
//   - amount: amount of stake to remove
//   - currentHeight: current block height
func removeStakeProtocolFeeReward(address string, amount int64, currentHeight int64) {
	protocol_fee.DistributeProtocolFee(cross)

	distributedAmounts := getDistributedProtocolFees()

	protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentHeight)
	protocolFeeRewardManager.removeStake(address, amount, currentHeight)
}

// claimRewardsProtocolFeeReward claims protocol fee rewards for an address.
// This method distributes protocol fees and processes reward claiming for all token types.
//
// Parameters:
//   - address: staker's address claiming rewards
//   - currentHeight: current block height
//
// Returns:
//   - map[string]int64: protocol fee rewards claimed by token
//   - error: nil on success, error if claiming fails
func claimRewardsProtocolFeeReward(address string, currentHeight int64) (map[string]int64, error) {
	protocol_fee.DistributeProtocolFee(cross)

	distributedAmounts := getDistributedProtocolFees()

	protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentHeight)
	return protocolFeeRewardManager.claimRewards(address, currentHeight)
}

// getDistributedProtocolFees retrieves the current distributed protocol fee amounts for all tokens.
// This method queries the protocol fee contract for accumulated distributions.
//
// Returns:
//   - map[string]int64: distributed amounts by token path
func getDistributedProtocolFees() map[string]int64 {
	distributedAmounts := make(map[string]int64)

	protocol_fee.GetAccuTransferToGovStaker().Iterate("", "", func(key string, value interface{}) bool {
		amount, ok := value.(uint64)
		if !ok {
			return false
		}

		distributedAmounts[key] = int64(amount)

		return false
	})

	return distributedAmounts
}

// getLaunchpadProjectDeposit retrieves the deposit amount for a launchpad project.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//
// Returns:
//   - int64: deposit amount
//   - bool: true if project exists, false otherwise
func getLaunchpadProjectDeposit(ownerAddress string) (int64, bool) {
	deposit, ok := launchpadProjectDeposits.Get(ownerAddress)
	if !ok {
		return 0, false
	}

	return deposit.(int64), true
}

// setLaunchpadProjectDeposit sets the deposit amount for a launchpad project.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//   - deposit: deposit amount to set
//
// Returns:
//   - bool: true if successfully set
func setLaunchpadProjectDeposit(ownerAddress string, deposit int64) bool {
	launchpadProjectDeposits.Set(ownerAddress, deposit)

	return true
}

// removeLaunchpadProjectDeposit removes a launchpad project deposit record.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//
// Returns:
//   - bool: true if successfully removed
func removeLaunchpadProjectDeposit(ownerAddress string) bool {
	_, ok := launchpadProjectDeposits.Remove(ownerAddress)

	return ok
}

// addStakeFromLaunchpad adds stake for a launchpad project and updates reward tracking.
// This method creates a special reward ID for launchpad projects and manages their deposit tracking.
//
// Parameters:
//   - address: project wallet address
//   - amount: amount of stake to add
//   - currentHeight: current block height
func addStakeFromLaunchpad(address string, amount int64, currentHeight int64) {
	launchpadRewardID := makeLaunchpadRewardID(address)
	addStakeEmissionReward(launchpadRewardID, amount, currentHeight)
	addStakeProtocolFeeReward(launchpadRewardID, amount, currentHeight)

	deposit, exists := getLaunchpadProjectDeposit(launchpadRewardID)
	if !exists {
		deposit = 0
	}

	deposit += amount
	setLaunchpadProjectDeposit(launchpadRewardID, deposit)
}

// removeStakeFromLaunchpad removes stake for a launchpad project and updates reward tracking.
// This method manages launchpad project deposit tracking and ensures non-negative deposits.
//
// Parameters:
//   - address: project wallet address
//   - amount: amount of stake to remove
//   - currentHeight: current block height
func removeStakeFromLaunchpad(address string, amount int64, currentHeight int64) {
	launchpadRewardID := makeLaunchpadRewardID(address)
	removeStakeEmissionReward(launchpadRewardID, amount, currentHeight)
	removeStakeProtocolFeeReward(launchpadRewardID, amount, currentHeight)

	deposit, exists := getLaunchpadProjectDeposit(launchpadRewardID)
	if !exists {
		deposit = 0
	}

	deposit -= amount
	if deposit < 0 {
		deposit = 0
	}

	setLaunchpadProjectDeposit(launchpadRewardID, deposit)
}

// makeLaunchpadRewardID creates a special reward identifier for launchpad projects.
// This ensures launchpad project rewards are tracked separately from regular user stakes.
//
// Parameters:
//   - address: project wallet address
//
// Returns:
//   - string: formatted launchpad reward ID
func makeLaunchpadRewardID(address string) string {
	return ufmt.Sprintf("launchpad:%s", address)
}
