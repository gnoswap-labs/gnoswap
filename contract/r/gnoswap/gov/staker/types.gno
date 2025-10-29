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
	// Delegation getters
	GetTotalxGnsSupply() int64
	GetTotalVoteWeight() int64
	GetTotalDelegated() int64
	GetTotalLockedAmount() int64
	GetLockedAmount() int64
	GetDelegationSnapshots(snapshotTime int64) (DelegationSnapshot, bool)

	// Reward getters
	GetClaimableRewardByAddress(addr address) string
	GetClaimableRewardByLaunchpad(addr address) string
	GetClaimableRewardByRewardID(rewardID string) string
}

// Admin interface for administrative functions
type IGovStakerAdmin interface {
	CleanStakerDelegationSnapshotByAdmin(threshold int64)
	SetUnDelegationLockupPeriodByAdmin(period int64)
}

type IGovStakerStore interface {
	// Basic configuration
	HasUnDelegationLockupPeriodStoreKey() bool
	GetUnDelegationLockupPeriod() (int64, error)
	SetUnDelegationLockupPeriod(period int64) error

	HasEmissionRewardBalanceStoreKey() bool
	GetEmissionRewardBalance() (int64, error)
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
	GetAllDelegations() (*avl.Tree, error)

	HasDelegationCounterStoreKey() bool
	GetDelegationCounter() *Counter
	SetDelegationCounter(counter *Counter) error

	// Delegation history
	HasDelegationHistoryStoreKey() bool
	AddDelegationRecord(record *DelegationRecord) error
	GetDelegationHistory() ([]*DelegationRecord, error)
	SetDelegationHistory(history []*DelegationRecord) error

	// User delegation mapping
	HasUserDelegationsStoreKey() bool
	HasUserDelegations(user string) bool
	GetUserDelegations(user string) (map[string][]int64, error)
	SetUserDelegations(user string, delegations map[string][]int64) error
	AddUserDelegation(from, to string, delegationID int64) error
	RemoveUserDelegation(from, to string, delegationID int64) error

	// Delegation snapshots
	HasDelegationSnapshotsStoreKey() bool
	HasDelegationSnapshot(timestamp int64) bool
	SetDelegationSnapshot(timestamp int64, snapshot DelegationSnapshot) error
	GetDelegationSnapshot(timestamp int64) (DelegationSnapshot, bool)

	SetAllDelegationSnapshots(snapshots *avl.Tree) error
	GetAllDelegationSnapshots() (*avl.Tree, error)

	// Manager states
	HasEmissionRewardManagerStoreKey() bool
	GetEmissionRewardManager() (*EmissionRewardManager, error)
	SetEmissionRewardManager(manager *EmissionRewardManager) error

	HasProtocolFeeRewardManagerStoreKey() bool
	GetProtocolFeeRewardManager() (*ProtocolFeeRewardManager, error)
	SetProtocolFeeRewardManager(manager *ProtocolFeeRewardManager) error

	HasDelegationManagerStoreKey() bool
	GetDelegationManager() (*DelegationManager, error)
	SetDelegationManager(manager *DelegationManager) error

	HasLaunchpadProjectDepositsStoreKey() bool
	GetLaunchpadProjectDeposits() (*LaunchpadProjectDeposits, error)
	SetLaunchpadProjectDeposits(deposits *LaunchpadProjectDeposits) error
}
