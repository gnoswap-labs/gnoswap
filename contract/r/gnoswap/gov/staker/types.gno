package staker

import (
	"gno.land/p/nt/avl"
)

// Main interface that combines all sub-interfaces
type IGovStaker interface {
	IGovStakerDelegation
	IGovStakerReward
	IGovStakerGetter
	IGovStakerAdmin
}

// Delegation operations interface
type IGovStakerDelegation interface {
	// Main delegation operations
	Delegate(to address, amount int64, referrer string) int64
	Undelegate(from address, amount int64) int64
	Redelegate(delegatee, newDelegatee address, amount int64) int64
	CollectUndelegatedGns() int64
}

// Reward management interface
type IGovStakerReward interface {
	// Reward collection
	CollectReward()
	CollectRewardFromLaunchPad(to address)
	SetAmountByProjectWallet(addr address, amount int64, add bool)
}

// Getter interface for read operations
type IGovStakerGetter interface {
	// Store data getters
	GetUnDelegationLockupPeriod() int64
	GetEmissionRewardBalance() int64

	// Delegation getters
	GetTotalxGnsSupply() int64
	GetTotalVoteWeight() int64
	GetTotalDelegated() int64
	GetTotalLockedAmount() int64
	GetLockedAmount() int64
	GetDelegationCount() int
	GetDelegationIDs(offset, count int) []int64
	ExistsDelegation(delegationID int64) bool
	GetDelegation(delegationID int64) (*Delegation, error)
	GetDelegatorDelegationCount(delegator address) int
	GetDelegatorDelegationIDs(delegator address, offset, count int) []int64
	HasDelegationSnapshotsKey() bool
	GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool)
	GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool)

	// Reward getters
	GetClaimableRewardByAddress(addr address) (int64, map[string]int64)
	GetClaimableRewardByLaunchpad(addr address) (int64, map[string]int64)
	GetClaimableRewardByRewardID(rewardID string) (int64, map[string]int64)

	// Launchpad getters
	GetLaunchpadProjectDeposit(projectAddr string) (int64, bool)
}

// Admin interface for administrative functions
type IGovStakerAdmin interface {
	CleanStakerDelegationSnapshotByAdmin(snapshotTime int64)
	SetUnDelegationLockupPeriodByAdmin(period int64)
}

type IGovStakerStore interface {
	// Basic configuration
	HasUnDelegationLockupPeriodStoreKey() bool
	GetUnDelegationLockupPeriod() int64
	SetUnDelegationLockupPeriod(period int64) error

	HasEmissionRewardBalanceStoreKey() bool
	GetEmissionRewardBalance() int64
	SetEmissionRewardBalance(balance int64) error

	HasTotalDelegatedAmountStoreKey() bool
	GetTotalDelegatedAmount() int64
	SetTotalDelegatedAmount(amount int64) error

	HasTotalLockedAmountStoreKey() bool
	GetTotalLockedAmount() int64
	SetTotalLockedAmount(amount int64) error

	// Delegation management
	HasDelegation(id int64) bool
	GetDelegation(id int64) (*Delegation, bool)
	SetDelegation(id int64, delegation *Delegation) error
	RemoveDelegation(id int64) error

	HasDelegationsStoreKey() bool
	SetDelegations(delegations *avl.Tree) error
	GetAllDelegations() *avl.Tree

	HasDelegationCounterStoreKey() bool
	GetDelegationCounter() *Counter
	SetDelegationCounter(counter *Counter) error

	// Total delegation history (timestamp -> int64)
	HasTotalDelegationHistoryStoreKey() bool
	GetTotalDelegationHistory() *UintTree
	SetTotalDelegationHistory(history *UintTree) error

	// User delegation history (address -> *UintTree[timestamp -> int64])
	HasUserDelegationHistoryStoreKey() bool
	GetUserDelegationHistory() *avl.Tree
	SetUserDelegationHistory(history *avl.Tree) error

	// Manager states
	HasEmissionRewardManagerStoreKey() bool
	GetEmissionRewardManager() *EmissionRewardManager
	SetEmissionRewardManager(manager *EmissionRewardManager) error

	HasProtocolFeeRewardManagerStoreKey() bool
	GetProtocolFeeRewardManager() *ProtocolFeeRewardManager
	SetProtocolFeeRewardManager(manager *ProtocolFeeRewardManager) error

	HasDelegationManagerStoreKey() bool
	GetDelegationManager() *DelegationManager
	SetDelegationManager(manager *DelegationManager) error

	HasLaunchpadProjectDepositsStoreKey() bool
	GetLaunchpadProjectDeposits() *LaunchpadProjectDeposits
	SetLaunchpadProjectDeposits(deposits *LaunchpadProjectDeposits) error
}
