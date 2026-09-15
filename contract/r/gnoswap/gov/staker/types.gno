package staker

import (
	"gno.land/p/gnoswap/uint256/v1"
	rotree "gno.land/p/nt/bptree/rotree/v0"
	bptree "gno.land/p/nt/bptree/v0"
)

// Main interface that combines all sub-interfaces
type IGovStaker interface {
	IGovStakerDelegation
	IGovStakerReward
	IGovStakerGetter
	IGovStakerAdmin
	Render(path string) string
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
	// Delegate moves GNS into delegation and assigns the corresponding xGNS voting power.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded implementation call
	//   - rlm: propagated current realm context validated before token transfers and state updates
	//   - to: address that receives the delegated voting power
	//   - amount: positive GNS amount to delegate
	//   - referrer: optional referral identifier associated with the delegation
	//
	// Returns:
	//   - int64: amount delegated and represented as xGNS
	Delegate(_ int, rlm realm, to address, amount int64, referrer string) int64
	// Undelegate removes voting power from an existing delegatee and starts the
	// undelegation lockup for the returned GNS.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded implementation call
	//   - rlm: propagated current realm context validated before token and state updates
	//   - from: delegatee address from which the caller removes delegation
	//   - amount: positive xGNS amount to undelegate
	//
	// Returns:
	//   - int64: amount moved from active delegation into undelegation lockup
	Undelegate(_ int, rlm realm, from address, amount int64) int64
	// Redelegate moves voting power from one delegatee to another without a
	// user-facing undelegation lockup.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded implementation call
	//   - rlm: propagated current realm context validated before token and state updates
	//   - delegatee: current delegatee address whose delegation is reduced
	//   - newDelegatee: destination address that receives the redelegated amount
	//   - amount: positive xGNS amount to move between delegatees
	//
	// Returns:
	//   - int64: amount moved from the current delegatee to the new delegatee
	Redelegate(_ int, rlm realm, delegatee, newDelegatee address, amount int64) int64
	// CollectUndelegatedGns releases GNS whose undelegation lockup has expired.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded implementation call
	//   - rlm: propagated current realm context validated before token and state updates
	//
	// Returns:
	//   - int64: amount of unlocked GNS collected by the caller
	CollectUndelegatedGns(_ int, rlm realm) int64
}

// Reward management interface
type IGovStakerReward interface {
	// Reward collection
	// CollectReward settles the caller's GNS emission and all known protocol-fee
	// token rewards.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded implementation call
	//   - rlm: propagated current realm context validated before reward transfers and state updates
	CollectReward(_ int, rlm realm)
	// CollectEmissionReward settles only the caller's accumulated GNS emission reward.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded implementation call
	//   - rlm: propagated current realm context validated before reward transfer and state updates
	CollectEmissionReward(_ int, rlm realm)
	// CollectProtocolFeeReward settles one registered protocol-fee token reward
	// for the caller.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded implementation call
	//   - rlm: propagated current realm context validated before reward transfer and state updates
	//   - tokenPath: registered token path whose accumulated reward is settled
	CollectProtocolFeeReward(_ int, rlm realm, tokenPath string)
	// CollectRewardFromLaunchPad settles both reward streams for a registered
	// launchpad project wallet.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded implementation call
	//   - rlm: propagated current realm context validated before launchpad authorization and reward transfers
	//   - to: registered launchpad project wallet that receives the rewards
	CollectRewardFromLaunchPad(_ int, rlm realm, to address)
	// CollectEmissionRewardFromLaunchPad settles only the emission reward for a
	// registered launchpad project wallet.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded implementation call
	//   - rlm: propagated current realm context validated before launchpad authorization and reward transfer
	//   - to: registered launchpad project wallet that receives the emission reward
	CollectEmissionRewardFromLaunchPad(_ int, rlm realm, to address)
	// CollectProtocolFeeRewardFromLaunchPad settles one protocol-fee token reward
	// for a registered launchpad project wallet.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded implementation call
	//   - rlm: propagated current realm context validated before launchpad authorization and reward transfer
	//   - to: registered launchpad project wallet that receives the token reward
	//   - tokenPath: registered token path whose accumulated reward is settled
	CollectProtocolFeeRewardFromLaunchPad(_ int, rlm realm, to address, tokenPath string)
	// SetAmountByProjectWallet adjusts the launchpad-backed stake amount and
	// corresponding xGNS balance for a project wallet.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded implementation call
	//   - rlm: propagated current realm context validated before launchpad authorization and state updates
	//   - addr: project wallet address whose launchpad-backed stake is adjusted
	//   - amount: stake amount delta passed to the launchpad reward accounting
	//   - add: true to add stake and mint xGNS; false to remove stake and burn xGNS
	SetAmountByProjectWallet(_ int, rlm realm, addr address, amount int64, add bool)
}

// Getter interface for read operations
type IGovStakerGetter interface {
	// Store data getters
	// GetUnDelegationLockupPeriod returns the configured undelegation cooldown.
	//
	// Returns:
	//   - int64: undelegation lockup duration in seconds
	GetUnDelegationLockupPeriod() int64

	// Delegation getters
	// GetTotalxGnsSupply returns total xGNS supply, including xGNS held by the
	// launchpad.
	//
	// Returns:
	//   - int64: total xGNS supply used as the governance quorum base
	GetTotalxGnsSupply() int64
	// GetTotalDelegated returns the amount currently delegated for governance
	// voting power.
	//
	// Returns:
	//   - int64: total active delegated xGNS amount
	GetTotalDelegated() int64
	// GetTotalLockedAmount returns GNS held by the staker for active delegations
	// and not-yet-collected undelegations.
	//
	// Returns:
	//   - int64: total GNS principal held for active delegations plus uncollected undelegations, in base units
	GetTotalLockedAmount() int64
	// GetDelegations returns a read-only tree of all delegations keyed by their
	// decimal-string IDs.
	//
	// Returns:
	//   - *rotree.ReadOnlyTree: read-only delegation index whose entries are cloned for callers
	GetDelegations() *rotree.ReadOnlyTree
	// ExistsDelegation checks whether a delegation record exists.
	//
	// Parameters:
	//   - delegationID: unique delegation identifier to look up
	//
	// Returns:
	//   - bool: true when delegationID has a stored record; false otherwise
	ExistsDelegation(delegationID int64) bool
	// GetDelegatorDelegations returns a read-only tree for one delegator, keyed
	// by delegatee address.
	//
	// Parameters:
	//   - delegator: address whose delegatee mappings are requested
	//
	// Returns:
	//   - *rotree.ReadOnlyTree: delegatee-to-delegation-ID tree, or nil when the delegator has no delegations
	GetDelegatorDelegations(delegator address) *rotree.ReadOnlyTree
	// GetUserDelegationIDs returns delegation IDs for one delegator-delegatee
	// pair.
	//
	// Parameters:
	//   - delegator: address that owns the delegation
	//   - delegatee: address receiving the delegation
	//
	// Returns:
	//   - []int64: stored delegation IDs for the pair, or an empty list when none exist
	GetUserDelegationIDs(delegator address, delegatee address) []int64
	// HasDelegationSnapshotsKey reports whether total delegation history has
	// been initialized in storage.
	//
	// Returns:
	//   - bool: true when the total delegation history store key exists; false otherwise
	HasDelegationSnapshotsKey() bool
	// GetTotalDelegationAmountAtSnapshot finds the latest total delegation
	// history value at or before a Unix timestamp.
	//
	// Parameters:
	//   - snapshotTime: Unix timestamp at which to resolve historical total delegation
	//
	// Returns:
	//   - int64: total delegated amount from the latest qualifying history entry
	//   - bool: true when a qualifying history entry exists; false when history has no such entry
	GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool)
	// GetUserDelegationAmountAtSnapshot finds a delegatee's latest delegated
	// amount at or before a Unix timestamp. The address is the delegatee and
	// voting-power holder, not the delegator who supplied the GNS.
	//
	// Parameters:
	//   - userAddr: delegatee/voting-power holder whose delegation history is searched
	//   - snapshotTime: Unix timestamp at which to resolve the delegatee's historical delegation
	//
	// Returns:
	//   - int64: delegatee's delegated amount from the latest qualifying history entry
	//   - bool: true when a qualifying delegatee-history entry exists; false otherwise
	GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool)

	// Reward getters
	// GetClaimableRewardByAddress computes current claimable emission and
	// protocol-fee rewards for an address reward ID.
	//
	// Parameters:
	//   - addr: staker address whose reward ID is queried
	//
	// Returns:
	//   - int64: claimable GNS emission reward amount
	//   - map[string]int64: claimable protocol-fee amounts keyed by token path
	//   - error: nil when both reward streams are computed; otherwise the reward-accounting error
	GetClaimableRewardByAddress(addr address) (int64, map[string]int64, error)
	// GetClaimableRewardByLaunchpad computes rewards for a launchpad project
	// wallet's launchpad-specific reward ID.
	//
	// Parameters:
	//   - addr: registered launchpad project wallet address
	//
	// Returns:
	//   - int64: claimable GNS emission reward amount
	//   - map[string]int64: claimable protocol-fee amounts keyed by token path
	//   - error: nil when both reward streams are computed; otherwise the reward-accounting error
	GetClaimableRewardByLaunchpad(addr address) (int64, map[string]int64, error)
	// GetClaimableRewardByRewardID computes current rewards for an explicit
	// reward identifier.
	//
	// Parameters:
	//   - rewardID: staker or launchpad reward-state identifier
	//
	// Returns:
	//   - int64: claimable GNS emission reward amount
	//   - map[string]int64: claimable protocol-fee amounts keyed by token path
	//   - error: nil when both reward streams are computed; otherwise the reward-accounting error
	GetClaimableRewardByRewardID(rewardID string) (int64, map[string]int64, error)

	// Launchpad getters
	// GetLaunchpadProjectDeposit returns a project's recorded launchpad deposit.
	//
	// Parameters:
	//   - projectAddr: project address identifier used to derive the launchpad reward key
	//
	// Returns:
	//   - int64: stored project deposit amount
	//   - bool: true when a deposit record exists for projectAddr; false otherwise
	GetLaunchpadProjectDeposit(projectAddr string) (int64, bool)

	// Withdraw getters
	// GetDelegationWithdrawCount returns the number of pending withdrawal
	// records attached to a delegation.
	//
	// Parameters:
	//   - delegationID: delegation whose withdrawal list is counted
	//
	// Returns:
	//   - int: number of withdrawal records, or 0 when the delegation is absent
	GetDelegationWithdrawCount(delegationID int64) int
	// GetDelegationWithdraws returns a slice of a delegation's withdrawal list.
	//
	// Parameters:
	//   - delegationID: delegation whose withdrawals are requested
	//   - offset: non-negative zero-based starting index in the withdrawal list
	//   - count: non-negative maximum number of withdrawals to include
	//
	// Returns:
	//   - []DelegationWithdraw: withdrawals in the requested range, or an empty slice when the delegation or range is absent
	//   - error: nil when the lookup completes; an unknown delegation yields an empty slice
	GetDelegationWithdraws(delegationID int64, offset, count int) ([]DelegationWithdraw, error)
	// GetCollectableWithdrawAmount sums all withdrawal amounts currently
	// collectable for a delegation.
	//
	// Parameters:
	//   - delegationID: delegation whose expired withdrawals are summed
	//
	// Returns:
	//   - int64: total GNS amount collectable now, or 0 when none is collectable
	GetCollectableWithdrawAmount(delegationID int64) int64

	// Protocol fee reward getters
	// GetProtocolFeeAccumulatedX128PerStake returns the per-stake protocol-fee
	// accumulator for a token path, scaled by 2^128.
	//
	// Parameters:
	//   - tokenPath: registered token path whose accumulator is queried
	//
	// Returns:
	//   - *uint256.Uint: Q128-scaled accumulated fee per stake, zero when the token has no folded fee
	GetProtocolFeeAccumulatedX128PerStake(tokenPath string) *uint256.Uint
	// GetProtocolFeeAmount returns the total protocol fee folded for a token
	// path.
	//
	// Parameters:
	//   - tokenPath: registered token path whose folded fee amount is queried
	//
	// Returns:
	//   - int64: total folded protocol-fee amount, or 0 when the token has no accumulator
	GetProtocolFeeAmount(tokenPath string) int64
	// GetProtocolFeeAccumulatedTimestamp returns the last timestamp at which
	// protocol-fee accrual state advanced.
	//
	// Returns:
	//   - int64: Unix timestamp of the latest protocol-fee accumulation update
	GetProtocolFeeAccumulatedTimestamp() int64

	// Emission reward getters
	// GetEmissionAccumulatedX128PerStake returns the accumulated GNS emission
	// reward per stake, scaled by 2^128.
	//
	// Returns:
	//   - *uint256.Uint: Q128-scaled accumulated emission per stake
	GetEmissionAccumulatedX128PerStake() *uint256.Uint
	// GetEmissionDistributedAmount returns the total GNS emission distributed
	// through the staker reward manager.
	//
	// Returns:
	//   - int64: cumulative distributed GNS emission amount
	GetEmissionDistributedAmount() int64
	// GetEmissionAccumulatedTimestamp returns the last timestamp at which
	// emission reward accrual state advanced.
	//
	// Returns:
	//   - int64: Unix timestamp of the latest emission accumulation update
	GetEmissionAccumulatedTimestamp() int64
}

// Admin interface for administrative functions
type IGovStakerAdmin interface {
	// CleanStakerDelegationSnapshotByAdmin removes delegation-history entries
	// older than a validated timestamp cutoff.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded implementation call
	//   - rlm: propagated current realm context validated before administrative state updates
	//   - snapshotTime: Unix timestamp cutoff before which eligible history entries are removed
	//   - target: address whose user delegation history is cleaned
	CleanStakerDelegationSnapshotByAdmin(_ int, rlm realm, snapshotTime int64, target address)
	// SetUnDelegationLockupPeriodByAdmin updates the duration used by future
	// undelegation withdrawals.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded implementation call
	//   - rlm: propagated current realm context validated before the administrative store write
	//   - period: non-negative undelegation lockup duration in seconds
	SetUnDelegationLockupPeriodByAdmin(_ int, rlm realm, period int64)
}

// IGovStakerStore mirrors the mutating-method realm-threading convention used
// by the public IGovStaker* interfaces above. Setters take `_ int, rlm realm`
// so KV-store writes execute under the proxy realm — the only address with
// write access to the shared store.
type IGovStakerStore interface {
	// Basic configuration
	// HasUnDelegationLockupPeriodStoreKey reports whether the lockup duration is initialized.
	//
	// Returns:
	//   - bool: true when the undelegation lockup period store key exists
	HasUnDelegationLockupPeriodStoreKey() bool
	// GetUnDelegationLockupPeriod returns the persisted undelegation lockup duration.
	//
	// Returns:
	//   - int64: configured lockup duration in seconds
	GetUnDelegationLockupPeriod() int64
	// SetUnDelegationLockupPeriod persists the undelegation lockup duration.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
	//   - rlm: propagated current realm context required by the KV store
	//   - period: lockup duration in seconds
	//
	// Returns:
	//   - error: nil when stored; otherwise the KV-store error, including a spoofed realm context
	SetUnDelegationLockupPeriod(_ int, rlm realm, period int64) error

	// HasTotalDelegatedAmountStoreKey reports whether total active delegation is initialized.
	//
	// Returns:
	//   - bool: true when the total delegated amount store key exists
	HasTotalDelegatedAmountStoreKey() bool
	// GetTotalDelegatedAmount returns the persisted total active delegation amount.
	//
	// Returns:
	//   - int64: total delegated xGNS amount
	GetTotalDelegatedAmount() int64
	// SetTotalDelegatedAmount persists the total active delegation amount.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
	//   - rlm: propagated current realm context required by the KV store
	//   - amount: total active delegated xGNS amount to store
	//
	// Returns:
	//   - error: nil when stored; otherwise the KV-store error, including a spoofed realm context
	SetTotalDelegatedAmount(_ int, rlm realm, amount int64) error

	// HasTotalLockedAmountStoreKey reports whether total locked GNS is initialized.
	//
	// Returns:
	//   - bool: true when the total locked amount store key exists
	HasTotalLockedAmountStoreKey() bool
	// GetTotalLockedAmount returns the persisted total GNS held by the staker.
	//
	// Returns:
	//   - int64: total locked GNS amount
	GetTotalLockedAmount() int64
	// SetTotalLockedAmount persists the total locked GNS amount.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
	//   - rlm: propagated current realm context required by the KV store
	//   - amount: total locked GNS amount to store
	//
	// Returns:
	//   - error: nil when stored; otherwise the KV-store error, including a spoofed realm context
	SetTotalLockedAmount(_ int, rlm realm, amount int64) error

	// Delegation management
	// HasDelegation reports whether a delegation record exists for an ID.
	//
	// Parameters:
	//   - id: delegation identifier to look up
	//
	// Returns:
	//   - bool: true when a delegation is stored under id; false otherwise
	HasDelegation(id int64) bool
	// GetDelegation retrieves one delegation record.
	//
	// Parameters:
	//   - id: delegation identifier to look up
	//
	// Returns:
	//   - *Delegation: stored delegation pointer, or nil when id is absent
	//   - bool: true when a delegation record exists and has the expected type; false otherwise
	GetDelegation(id int64) (*Delegation, bool)
	// SetDelegation stores a delegation under its identifier.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
	//   - rlm: propagated current realm context required by the KV store
	//   - id: delegation identifier used as the storage key
	//   - delegation: delegation record to store
	//
	// Returns:
	//   - error: nil when stored; otherwise the KV-store error, including a spoofed realm context
	SetDelegation(_ int, rlm realm, id int64, delegation *Delegation) error
	// RemoveDelegation deletes a delegation record and its storage entry.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
	//   - rlm: propagated current realm context required by the KV store
	//   - id: delegation identifier to remove
	//
	// Returns:
	//   - error: nil when the store write succeeds; otherwise the KV-store error, including a spoofed realm context
	RemoveDelegation(_ int, rlm realm, id int64) error

	// HasDelegationsStoreKey reports whether the all-delegations tree is initialized.
	//
	// Returns:
	//   - bool: true when the delegations store key exists
	HasDelegationsStoreKey() bool
	// SetDelegations replaces the persisted all-delegations tree.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
	//   - rlm: propagated current realm context required by the KV store
	//   - delegations: BPTree containing delegation records keyed by delegation ID
	//
	// Returns:
	//   - error: nil when stored; otherwise the KV-store error, including a spoofed realm context
	SetDelegations(_ int, rlm realm, delegations *bptree.BPTree) error
	// GetAllDelegations returns the persisted tree containing every delegation.
	//
	// Returns:
	//   - *bptree.BPTree: all-delegations tree keyed by decimal-string delegation ID
	GetAllDelegations() *bptree.BPTree

	// HasDelegationCounterStoreKey reports whether the next-delegation-ID counter is initialized.
	//
	// Returns:
	//   - bool: true when the delegation counter store key exists
	HasDelegationCounterStoreKey() bool
	// GetDelegationCounter returns the persisted counter used to allocate delegation IDs.
	//
	// Returns:
	//   - *Counter: mutable delegation-ID counter
	GetDelegationCounter() *Counter
	// SetDelegationCounter persists the delegation-ID counter.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
	//   - rlm: propagated current realm context required by the KV store
	//   - counter: delegation-ID counter to store
	//
	// Returns:
	//   - error: nil when stored; otherwise the KV-store error, including a spoofed realm context
	SetDelegationCounter(_ int, rlm realm, counter *Counter) error

	// Total delegation history (timestamp -> int64)
	// HasTotalDelegationHistoryStoreKey reports whether cumulative total delegation history is initialized.
	//
	// Returns:
	//   - bool: true when the total-delegation-history store key exists
	HasTotalDelegationHistoryStoreKey() bool
	// GetTotalDelegationHistory returns timestamp-keyed cumulative total delegation history.
	//
	// Returns:
	//   - *UintTree: total delegation history tree mapping Unix timestamps to int64 amounts
	GetTotalDelegationHistory() *UintTree
	// SetTotalDelegationHistory persists timestamp-keyed cumulative total delegation history.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
	//   - rlm: propagated current realm context required by the KV store
	//   - history: timestamp-to-total-delegation tree to store
	//
	// Returns:
	//   - error: nil when stored; otherwise the KV-store error, including a spoofed realm context
	SetTotalDelegationHistory(_ int, rlm realm, history *UintTree) error

	// User delegation history (address -> *UintTree[timestamp -> int64])
	// HasUserDelegationHistoryStoreKey reports whether per-user delegation history is initialized.
	//
	// Returns:
	//   - bool: true when the user-delegation-history store key exists
	HasUserDelegationHistoryStoreKey() bool
	// GetUserDelegationHistory returns the composite-keyed per-user delegation history tree.
	//
	// Returns:
	//   - *bptree.BPTree: history tree keyed by address and timestamp
	GetUserDelegationHistory() *bptree.BPTree
	// SetUserDelegationHistory persists the composite-keyed per-user delegation history tree.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
	//   - rlm: propagated current realm context required by the KV store
	//   - history: address-and-timestamp delegation history tree to store
	//
	// Returns:
	//   - error: nil when stored; otherwise the KV-store error, including a spoofed realm context
	SetUserDelegationHistory(_ int, rlm realm, history *bptree.BPTree) error

	// Manager states
	// HasEmissionRewardManagerStoreKey reports whether the emission reward manager is initialized.
	//
	// Returns:
	//   - bool: true when the emission reward manager store key exists
	HasEmissionRewardManagerStoreKey() bool
	// GetEmissionRewardManager returns the persisted emission reward manager.
	//
	// Returns:
	//   - *EmissionRewardManager: emission reward accounting manager
	GetEmissionRewardManager() *EmissionRewardManager
	// SetEmissionRewardManager persists the emission reward manager.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
	//   - rlm: propagated current realm context required by the KV store
	//   - manager: emission reward manager state to store
	//
	// Returns:
	//   - error: nil when stored; otherwise the KV-store error, including a spoofed realm context
	SetEmissionRewardManager(_ int, rlm realm, manager *EmissionRewardManager) error

	// HasProtocolFeeRewardManagerStoreKey reports whether protocol-fee reward state is initialized.
	//
	// Returns:
	//   - bool: true when the protocol-fee reward manager store key exists
	HasProtocolFeeRewardManagerStoreKey() bool
	// GetProtocolFeeRewardManager returns the persisted protocol-fee reward manager.
	//
	// Returns:
	//   - *ProtocolFeeRewardManager: protocol-fee reward accounting manager
	GetProtocolFeeRewardManager() *ProtocolFeeRewardManager
	// SetProtocolFeeRewardManager persists the protocol-fee reward manager.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
	//   - rlm: propagated current realm context required by the KV store
	//   - manager: protocol-fee reward manager state to store
	//
	// Returns:
	//   - error: nil when stored; otherwise the KV-store error, including a spoofed realm context
	SetProtocolFeeRewardManager(_ int, rlm realm, manager *ProtocolFeeRewardManager) error

	// HasDelegationManagerStoreKey reports whether delegation-manager state is initialized.
	//
	// Returns:
	//   - bool: true when the delegation manager store key exists
	HasDelegationManagerStoreKey() bool
	// GetDelegationManager returns the persisted delegation manager.
	//
	// Returns:
	//   - *DelegationManager: delegation-to-address index manager
	GetDelegationManager() *DelegationManager
	// SetDelegationManager persists the delegation manager.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
	//   - rlm: propagated current realm context required by the KV store
	//   - manager: delegation manager state to store
	//
	// Returns:
	//   - error: nil when stored; otherwise the KV-store error, including a spoofed realm context
	SetDelegationManager(_ int, rlm realm, manager *DelegationManager) error

	// HasLaunchpadProjectDepositsStoreKey reports whether launchpad project deposits are initialized.
	//
	// Returns:
	//   - bool: true when the launchpad-project-deposits store key exists
	HasLaunchpadProjectDepositsStoreKey() bool
	// GetLaunchpadProjectDeposits returns the persisted launchpad project deposit state.
	//
	// Returns:
	//   - *LaunchpadProjectDeposits: project-address-to-deposit state
	GetLaunchpadProjectDeposits() *LaunchpadProjectDeposits
	// SetLaunchpadProjectDeposits persists launchpad project deposit state.
	//
	// Parameters:
	//   - _: leading realm-call discriminator; callers pass 0 for the forwarded store write
	//   - rlm: propagated current realm context required by the KV store
	//   - deposits: launchpad project deposit state to store
	//
	// Returns:
	//   - error: nil when stored; otherwise the KV-store error, including a spoofed realm context
	SetLaunchpadProjectDeposits(_ int, rlm realm, deposits *LaunchpadProjectDeposits) error
}
