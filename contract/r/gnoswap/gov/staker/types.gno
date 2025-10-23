package staker

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

// Storage interface
type IGovStakerStore interface {
	HasGovStakerStateKey() bool
	GetGovStakerState() GovStakerState
	SetGovStakerState(state GovStakerState) error
}

// State interface for gov/staker state management
type GovStakerState interface {
	// Lockup configuration
	UnDelegationLockupPeriod() int64
	SetUnDelegationLockupPeriod(period int64)

	// Reward balances
	EmissionRewardBalance() int64
	SetEmissionRewardBalance(balance int64)

	// Aggregate metrics
	TotalDelegatedAmount() int64
	SetTotalDelegatedAmount(amount int64)

	TotalLockedAmount() int64
	SetTotalLockedAmount(amount int64)
}

// DelegationSnapshot represents delegations at a specific time
type DelegationSnapshot map[string]*DelegationSnapshotItem

// DelegationSnapshotItem represents a snapshot item
type DelegationSnapshotItem struct {
	Delegatee        string
	DelegatorAddress address
	DelegateGns      int64
	DelegateXgns     int64
}

// DelegationAmount returns the delegation amount in GNS
func (d *DelegationSnapshotItem) DelegationAmount() int64 {
	return d.DelegateGns
}

