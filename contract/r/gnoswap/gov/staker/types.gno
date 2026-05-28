package staker

import (
	"gno.land/p/gnoswap/uint256"
	bptree "gno.land/p/nt/bptree/v0"
)

// Main interface that combines all sub-interfaces
type IGovStaker interface {
	IGovStakerDelegation
	IGovStakerReward
	IGovStakerGetter
	IGovStakerAdmin
}

// Delegation operations interface
//
// Mutating methods take `_ int, rlm realm` so the realm token is threaded
// from the proxy entry points down to the cross-realm token transfers and
// store writes performed inside each implementation. The `_ int` sentinel
// surfaces at every call site as a literal `0`, making the realm threading
// visible to readers.
type IGovStakerDelegation interface {
	// Main delegation operations
	Delegate(_ int, rlm realm, to address, amount int64, referrer string) int64
	Undelegate(_ int, rlm realm, from address, amount int64) int64
	Redelegate(_ int, rlm realm, delegatee, newDelegatee address, amount int64) int64
	CollectUndelegatedGns(_ int, rlm realm) int64
}

// Reward management interface
type IGovStakerReward interface {
	// Reward collection
	CollectReward(_ int, rlm realm)
	CollectRewardFromLaunchPad(_ int, rlm realm, to address)
	SetAmountByProjectWallet(_ int, rlm realm, addr address, amount int64, add bool)
}

// Getter interface for read operations
type IGovStakerGetter interface {
	// Store data getters
	GetUnDelegationLockupPeriod() int64

	// Delegation getters
	GetTotalxGnsSupply() int64
	GetTotalDelegated() int64
	GetTotalLockedAmount() int64
	GetDelegationCount() int
	GetDelegationIDs(offset, count int) []int64
	ExistsDelegation(delegationID int64) bool
	GetDelegation(delegationID int64) (*Delegation, error)
	GetDelegatorDelegateeCount(delegator address) int
	GetDelegatorDelegateeAddresses(delegator address, offset, count int) []address
	GetUserDelegationCount(delegator address, delegatee address) int
	GetUserDelegationIDs(delegator address, delegatee address) []int64
	HasDelegationSnapshotsKey() bool
	GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool)
	GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool)

	// Reward getters
	GetClaimableRewardByAddress(addr address) (int64, map[string]int64, error)
	GetClaimableRewardByLaunchpad(addr address) (int64, map[string]int64, error)
	GetClaimableRewardByRewardID(rewardID string) (int64, map[string]int64, error)

	// Launchpad getters
	GetLaunchpadProjectDeposit(projectAddr string) (int64, bool)

	// Withdraw getters
	GetDelegationWithdrawCount(delegationID int64) int
	GetDelegationWithdraws(delegationID int64, offset, count int) ([]DelegationWithdraw, error)
	GetCollectableWithdrawAmount(delegationID int64) int64

	// Protocol fee reward getters
	GetProtocolFeeAccumulatedX128PerStake(tokenPath string) *uint256.Uint
	GetProtocolFeeAmount(tokenPath string) int64
	GetProtocolFeeAccumulatedTimestamp() int64

	// Emission reward getters
	GetEmissionAccumulatedX128PerStake() *uint256.Uint
	GetEmissionDistributedAmount() int64
	GetEmissionAccumulatedTimestamp() int64
}

// Admin interface for administrative functions
type IGovStakerAdmin interface {
	CleanStakerDelegationSnapshotByAdmin(_ int, rlm realm, snapshotTime int64, target address)
	SetUnDelegationLockupPeriodByAdmin(_ int, rlm realm, period int64)
}

// IGovStakerStore mirrors the mutating-method realm-threading convention used
// by the public IGovStaker* interfaces above. Setters take `_ int, rlm realm`
// so KV-store writes execute under the proxy realm — the only address with
// write access to the shared store.
type IGovStakerStore interface {
	// Basic configuration
	HasUnDelegationLockupPeriodStoreKey() bool
	GetUnDelegationLockupPeriod() int64
	SetUnDelegationLockupPeriod(_ int, rlm realm, period int64) error

	HasTotalDelegatedAmountStoreKey() bool
	GetTotalDelegatedAmount() int64
	SetTotalDelegatedAmount(_ int, rlm realm, amount int64) error

	HasTotalLockedAmountStoreKey() bool
	GetTotalLockedAmount() int64
	SetTotalLockedAmount(_ int, rlm realm, amount int64) error

	// Delegation management
	HasDelegation(id int64) bool
	GetDelegation(id int64) (*Delegation, bool)
	SetDelegation(_ int, rlm realm, id int64, delegation *Delegation) error
	RemoveDelegation(_ int, rlm realm, id int64) error

	HasDelegationsStoreKey() bool
	SetDelegations(_ int, rlm realm, delegations *bptree.BPTree) error
	GetAllDelegations() *bptree.BPTree

	HasDelegationCounterStoreKey() bool
	GetDelegationCounter() *Counter
	SetDelegationCounter(_ int, rlm realm, counter *Counter) error

	// Total delegation history (timestamp -> int64)
	HasTotalDelegationHistoryStoreKey() bool
	GetTotalDelegationHistory() *UintTree
	SetTotalDelegationHistory(_ int, rlm realm, history *UintTree) error

	// User delegation history (address -> *UintTree[timestamp -> int64])
	HasUserDelegationHistoryStoreKey() bool
	GetUserDelegationHistory() *bptree.BPTree
	SetUserDelegationHistory(_ int, rlm realm, history *bptree.BPTree) error

	// Manager states
	HasEmissionRewardManagerStoreKey() bool
	GetEmissionRewardManager() *EmissionRewardManager
	SetEmissionRewardManager(_ int, rlm realm, manager *EmissionRewardManager) error

	HasProtocolFeeRewardManagerStoreKey() bool
	GetProtocolFeeRewardManager() *ProtocolFeeRewardManager
	SetProtocolFeeRewardManager(_ int, rlm realm, manager *ProtocolFeeRewardManager) error

	HasDelegationManagerStoreKey() bool
	GetDelegationManager() *DelegationManager
	SetDelegationManager(_ int, rlm realm, manager *DelegationManager) error

	HasLaunchpadProjectDepositsStoreKey() bool
	GetLaunchpadProjectDeposits() *LaunchpadProjectDeposits
	SetLaunchpadProjectDeposits(_ int, rlm realm, deposits *LaunchpadProjectDeposits) error
}
