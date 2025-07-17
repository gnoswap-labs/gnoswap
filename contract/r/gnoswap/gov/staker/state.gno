package staker

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/emission"
	protocol_fee "gno.land/r/gnoswap/v1/protocol_fee"
)

var (
	unDelegationLockupPeriod int64

	delegationCounter *Counter
	delegations       *avl.Tree
	delegationManager *DelegationManager

	delegationHistory   DelegationHistory
	delegationSnapshots DelegationSnapshot

	emissionRewardManager    *EmissionRewardManager
	protocolFeeRewardManager *ProtocolFeeRewardManager

	launchpadProjectDeposits *avl.Tree // project owner address -> deposit amount

	emissionRewardBalance int64
	protocolFeeBalances   map[string]int64
)

func init() {
	unDelegationLockupPeriod = 60 * 60 * 24 * 7 // 7 days

	delegationCounter = NewCounter()
	delegations = avl.NewTree()
	delegationManager = NewDelegationManager()

	delegationHistory = make(DelegationHistory, 0)
	delegationSnapshots = make(DelegationSnapshot)

	emissionRewardManager = NewEmissionRewardManager()
	protocolFeeRewardManager = NewProtocolFeeRewardManager()

	launchpadProjectDeposits = avl.NewTree()
}

func getUnDelegationLockupPeriod() int64 {
	return unDelegationLockupPeriod
}

func setUnDelegationLockupPeriod(period int64) {
	unDelegationLockupPeriod = period
}

func getCurrentDelegationID() int64 {
	return delegationCounter.Get()
}

func nextDelegationID() int64 {
	return delegationCounter.next()
}

func getDelegations() *avl.Tree {
	return delegations
}

func getDelegation(delegationID int64) *Delegation {
	id := formatInt(delegationID)
	delegation, ok := delegations.Get(id)
	if !ok {
		return nil
	}

	return delegation.(*Delegation)
}

func setDelegation(delegationID int64, delegation *Delegation) bool {
	id := formatInt(delegationID)

	delegations.Set(id, delegation)

	return true
}

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

func getUserDelegations(user std.Address) []*Delegation {
	delegations := make([]*Delegation, 0)

	for _, delegationID := range delegationManager.GetUserDelegationIDs(user) {
		delegations = append(delegations, getDelegation(delegationID))
	}

	return delegations
}

func getUserDelegationsWithDelegatee(user std.Address, delegatee std.Address) []*Delegation {
	delegations := make([]*Delegation, 0)

	for _, delegationID := range delegationManager.GetUserDelegationIDs(user) {
		delegations = append(delegations, getDelegation(delegationID))
	}

	return delegations
}

func getDelegationHistory() DelegationHistory {
	return delegationHistory
}

func addDelegationRecord(delegationRecord *DelegationRecord) {
	delegationHistory = delegationHistory.addRecord(delegationRecord)
	delegationSnapshots = delegationSnapshots.addRecord(delegationRecord)
}

func setDelegationHistory(history DelegationHistory) {
	delegationHistory = history
}

func getDelegationSnapshots() DelegationSnapshot {
	return delegationSnapshots
}

func setDelegationSnapshots(snapshot DelegationSnapshot) {
	delegationSnapshots = snapshot
}

// emission reward state methods
func addStakeEmissionReward(address string, amount int64, currentHeight int64) {
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentHeight)
	emissionRewardManager.addStake(address, amount, currentHeight)
}

func removeStakeEmissionReward(address string, amount int64, currentHeight int64) {
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentHeight)
	emissionRewardManager.removeStake(address, amount, currentHeight)
}

func claimRewardsEmissionReward(address string, currentHeight int64) (int64, error) {
	distributedAmount := emission.GetAccuDistributedToGovStaker()

	emissionRewardManager.updateAccumulatedRewardX128PerStake(distributedAmount, currentHeight)
	return emissionRewardManager.claimRewards(address, currentHeight)
}

// protocol fee reward state methods
func addStakeProtocolFeeReward(address string, amount int64, currentHeight int64) {
	protocol_fee.DistributeProtocolFee(cross)

	distributedAmounts := getDistributedProtocolFees()

	protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentHeight)
	protocolFeeRewardManager.addStake(address, amount, currentHeight)
}

func removeStakeProtocolFeeReward(address string, amount int64, currentHeight int64) {
	protocol_fee.DistributeProtocolFee(cross)

	distributedAmounts := getDistributedProtocolFees()

	protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentHeight)
	protocolFeeRewardManager.removeStake(address, amount, currentHeight)
}

func claimRewardsProtocolFeeReward(address string, currentHeight int64) (map[string]int64, error) {
	protocol_fee.DistributeProtocolFee(cross)

	distributedAmounts := getDistributedProtocolFees()

	protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentHeight)
	return protocolFeeRewardManager.claimRewards(address, currentHeight)
}

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

func getLaunchpadProjectDeposit(ownerAddress string) (int64, bool) {
	deposit, ok := launchpadProjectDeposits.Get(ownerAddress)
	if !ok {
		return 0, false
	}

	return deposit.(int64), true
}

func setLaunchpadProjectDeposit(ownerAddress string, deposit int64) bool {
	launchpadProjectDeposits.Set(ownerAddress, deposit)

	return true
}

func removeLaunchpadProjectDeposit(ownerAddress string) bool {
	_, ok := launchpadProjectDeposits.Remove(ownerAddress)

	return ok
}

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

func makeLaunchpadRewardID(address string) string {
	return ufmt.Sprintf("launchpad:%s", address)
}
