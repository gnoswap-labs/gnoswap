package protocol_fee

import bptree "gno.land/p/nt/bptree/v0"

type IProtocolFee interface {
	IProtocolFeeManager
	IProtocolFeeGetter
	Render(path string) string
}

type IProtocolFeeManager interface {
	// Mutating methods take `_ int, rlm realm` so a leading integer discriminator
	// (callers pass 0) and the current protocol_fee realm context are threaded
	// from proxy entry points down to cross-realm token transfers and store writes
	// performed inside each implementation. The discriminator is explicit at every
	// call site, making the realm threading visible to readers.
	// DistributeProtocolFee distributes all reserved protocol fees to DevOps and
	// GovStaker according to the configured allocation percentages.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context; implementation validates it as current
	DistributeProtocolFee(_ int, rlm realm)

	// DistributeProtocolFeeByTokenPath distributes the reserved fee for one token path.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context; implementation validates it as current
	//   - tokenPath: token contract path whose reserved fee should be distributed
	DistributeProtocolFeeByTokenPath(_ int, rlm realm, tokenPath string)

	// SetDevOpsPct updates the DevOps share; the GovStaker share becomes 10000 minus pct.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context; implementation validates it as current
	//   - pct: DevOps allocation in basis-point units, from 0 through 10000 inclusive
	SetDevOpsPct(_ int, rlm realm, pct int64)

	// SetGovStakerPct updates the GovStaker share; the DevOps share becomes 10000 minus pct.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context; implementation validates it as current
	//   - pct: GovStaker allocation in basis-point units, from 0 through 10000 inclusive
	SetGovStakerPct(_ int, rlm realm, pct int64)

	// AddToProtocolFee records and pulls an approved fee from an authorized protocol caller.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context; implementation rejects a non-current value
	//   - tokenPath: token contract path from which the approved fee is pulled
	//   - amount: non-negative fee amount in token base units; zero is a successful no-op
	//
	// Returns:
	//   - err: nil after accounting and transfer succeed; an error when realm validation, halt checks, or storage/transfer operations fail
	AddToProtocolFee(_ int, rlm realm, tokenPath string, amount int64) error

	// AdvanceAccrualEpoch closes the current epoch and selects the next epoch for new fees.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context; implementation validates it as current
	//
	// Returns:
	//   - epoch: newly stored non-negative accrual epoch
	AdvanceAccrualEpoch(_ int, rlm realm) int64

	// ConsumeAccrualBuckets removes pending buckets for one token in epoch order.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context; implementation validates it as current
	//   - tokenPath: token contract path whose pending GovStaker buckets are consumed
	//   - limit: maximum number of oldest buckets; zero or negative consumes all pending buckets
	//
	// Returns:
	//   - epochs: consumed epoch numbers in ascending order
	//   - amounts: fee amounts corresponding positionally to epochs, in token base units
	ConsumeAccrualBuckets(_ int, rlm realm, tokenPath string, limit int) ([]int64, []int64)
}

type IProtocolFeeGetter interface {
	// GetDevOpsPct returns the configured DevOps allocation.
	//
	// Returns:
	//   - pct: DevOps fee allocation in basis-point units, from 0 through 10000
	GetDevOpsPct() int64

	// GetGovStakerPct returns the configured GovStaker allocation.
	//
	// Returns:
	//   - pct: GovStaker fee allocation in basis-point units, from 0 through 10000
	GetGovStakerPct() int64

	// GetReservedTokens returns token paths whose collected fees await distribution.
	//
	// Returns:
	//   - tokenPaths: token contract paths in the reserved-token index
	GetReservedTokens() []string

	// GetAccuTransfersToGovStaker returns cumulative allocations assigned to GovStaker.
	//
	// Returns:
	//   - transfers: map from token contract path to cumulative allocated amount in base units
	GetAccuTransfersToGovStaker() map[string]int64

	// GetAccuTransfersToDevOps returns cumulative allocations assigned to DevOps.
	//
	// Returns:
	//   - transfers: map from token contract path to cumulative allocated amount in base units
	GetAccuTransfersToDevOps() map[string]int64

	// GetAccuTransferToGovStakerByTokenPath returns the GovStaker allocation for one token.
	//
	// Parameters:
	//   - path: token contract path whose cumulative GovStaker allocation is queried
	//
	// Returns:
	//   - amount: cumulative GovStaker allocation for path in token base units, or zero if absent
	GetAccuTransferToGovStakerByTokenPath(path string) int64

	// GetAccuTransferToDevOpsByTokenPath returns the DevOps allocation for one token.
	//
	// Parameters:
	//   - path: token contract path whose cumulative DevOps allocation is queried
	//
	// Returns:
	//   - amount: cumulative DevOps allocation for path in token base units, or zero if absent
	GetAccuTransferToDevOpsByTokenPath(path string) int64

	// GetActualDistributedToGovStaker returns cumulative amounts transferred to GovStaker.
	//
	// Returns:
	//   - transfers: map from token contract path to cumulative amount actually transferred in base units
	GetActualDistributedToGovStaker() map[string]int64

	// GetActualDistributedToDevOps returns cumulative amounts transferred to DevOps.
	//
	// Returns:
	//   - transfers: map from token contract path to cumulative amount actually transferred in base units
	GetActualDistributedToDevOps() map[string]int64

	// GetActualDistributedToGovStakerByTokenPath returns the completed GovStaker transfer for one token.
	//
	// Parameters:
	//   - path: token contract path whose completed GovStaker transfer is queried
	//
	// Returns:
	//   - amount: cumulative GovStaker amount actually transferred for path in base units, or zero if absent
	GetActualDistributedToGovStakerByTokenPath(path string) int64

	// GetActualDistributedToDevOpsByTokenPath returns the completed DevOps transfer for one token.
	//
	// Parameters:
	//   - path: token contract path whose completed DevOps transfer is queried
	//
	// Returns:
	//   - amount: cumulative DevOps amount actually transferred for path in base units, or zero if absent
	GetActualDistributedToDevOpsByTokenPath(path string) int64

	// GetAccrualEpoch returns the epoch assigned to newly collected GovStaker fees.
	//
	// Returns:
	//   - epoch: current non-negative accrual epoch
	GetAccrualEpoch() int64

	// GetAccrualPendingTokens returns token paths that still have pending accrual buckets.
	//
	// Returns:
	//   - tokenPaths: token contract paths with at least one pending GovStaker accrual bucket
	GetAccrualPendingTokens() []string

	// GetAccrualBuckets reads pending token buckets without removing them.
	//
	// Parameters:
	//   - tokenPath: token contract path whose GovStaker accrual buckets are queried
	//   - limit: maximum number of oldest buckets; zero or negative returns all pending buckets
	//
	// Returns:
	//   - epochs: selected accrual epoch numbers in ascending order
	//   - amounts: fee amounts corresponding positionally to epochs, in token base units
	GetAccrualBuckets(tokenPath string, limit int) ([]int64, []int64)
}

type IProtocolFeeStore interface {
	// HasDevOpsPctStoreKey reports whether the persisted DevOps percentage key exists.
	//
	// Returns:
	//   - exists: true when the DevOps percentage key is present in the KV store
	HasDevOpsPctStoreKey() bool

	// InitializeDevOpsPct creates the DevOps percentage key with its default value.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//
	// Returns:
	//   - err: nil when initialization succeeds; an error for invalid realm context or KV-store failure
	InitializeDevOpsPct(_ int, rlm realm) error

	// GetDevOpsPct reads the persisted DevOps percentage.
	//
	// Returns:
	//   - pct: stored DevOps allocation in basis-point units
	GetDevOpsPct() int64

	// SetDevOpsPct persists a new DevOps percentage.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//   - pct: DevOps allocation in basis-point units
	//
	// Returns:
	//   - err: nil when the value is stored; an error for invalid realm context or KV-store failure
	SetDevOpsPct(_ int, rlm realm, pct int64) error

	// HasAccuToGovStakerStoreKey reports whether the GovStaker allocation tree key exists.
	//
	// Returns:
	//   - exists: true when the cumulative GovStaker allocation tree is present in the KV store
	HasAccuToGovStakerStoreKey() bool

	// InitializeAccuToGovStaker creates the cumulative GovStaker allocation tree.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//
	// Returns:
	//   - err: nil when initialization succeeds; an error for invalid realm context or KV-store failure
	InitializeAccuToGovStaker(_ int, rlm realm) error

	// GetAccuToGovStaker returns the tree of cumulative GovStaker allocations by token.
	//
	// Returns:
	//   - tree: persistent BPTree keyed by token path with int64 allocation values
	GetAccuToGovStaker() *bptree.BPTree

	// GetAccuToGovStakerItem reads one token's cumulative GovStaker allocation.
	//
	// Parameters:
	//   - tokenPath: token contract path used as the allocation-tree key
	//
	// Returns:
	//   - amount: stored allocation in token base units, or zero when tokenPath is absent
	//   - exists: true when tokenPath has a stored allocation; false when absent
	GetAccuToGovStakerItem(tokenPath string) (int64, bool)

	// SetAccuToGovStakerItem stores one token's cumulative GovStaker allocation.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//   - tokenPath: token contract path used as the allocation-tree key
	//   - amount: cumulative GovStaker allocation in token base units to store
	//
	// Returns:
	//   - err: nil when the value is stored; an error for invalid realm context, missing tree, or KV-store failure
	SetAccuToGovStakerItem(_ int, rlm realm, tokenPath string, amount int64) error

	// HasAccuToDevOpsStoreKey reports whether the DevOps allocation tree key exists.
	//
	// Returns:
	//   - exists: true when the cumulative DevOps allocation tree is present in the KV store
	HasAccuToDevOpsStoreKey() bool

	// InitializeAccuToDevOps creates the cumulative DevOps allocation tree.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//
	// Returns:
	//   - err: nil when initialization succeeds; an error for invalid realm context or KV-store failure
	InitializeAccuToDevOps(_ int, rlm realm) error

	// GetAccuToDevOps returns the tree of cumulative DevOps allocations by token.
	//
	// Returns:
	//   - tree: persistent BPTree keyed by token path with int64 allocation values
	GetAccuToDevOps() *bptree.BPTree

	// GetAccuToDevOpsItem reads one token's cumulative DevOps allocation.
	//
	// Parameters:
	//   - tokenPath: token contract path used as the allocation-tree key
	//
	// Returns:
	//   - amount: stored allocation in token base units, or zero when tokenPath is absent
	//   - exists: true when tokenPath has a stored allocation; false when absent
	GetAccuToDevOpsItem(tokenPath string) (int64, bool)

	// SetAccuToDevOpsItem stores one token's cumulative DevOps allocation.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//   - tokenPath: token contract path used as the allocation-tree key
	//   - amount: cumulative DevOps allocation in token base units to store
	//
	// Returns:
	//   - err: nil when the value is stored; an error for invalid realm context, missing tree, or KV-store failure
	SetAccuToDevOpsItem(_ int, rlm realm, tokenPath string, amount int64) error

	// HasDistributedToGovStakerHistoryStoreKey reports whether the GovStaker history tree key exists.
	//
	// Returns:
	//   - exists: true when the cumulative GovStaker distribution-history tree is present
	HasDistributedToGovStakerHistoryStoreKey() bool

	// InitializeDistributedToGovStakerHistory creates the GovStaker distribution-history tree.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//
	// Returns:
	//   - err: nil when initialization succeeds; an error for invalid realm context or KV-store failure
	InitializeDistributedToGovStakerHistory(_ int, rlm realm) error

	// GetDistributedToGovStakerHistory returns cumulative actual GovStaker transfers by token.
	//
	// Returns:
	//   - tree: persistent BPTree keyed by token path with int64 transferred amounts
	GetDistributedToGovStakerHistory() *bptree.BPTree

	// GetDistributedToGovStakerHistoryItem reads one token's actual GovStaker transfer.
	//
	// Parameters:
	//   - tokenPath: token contract path used as the history-tree key
	//
	// Returns:
	//   - amount: stored transferred amount in token base units, or zero when tokenPath is absent
	//   - exists: true when tokenPath has a stored history amount; false when absent
	GetDistributedToGovStakerHistoryItem(tokenPath string) (int64, bool)

	// SetDistributedToGovStakerHistoryItem stores one token's actual GovStaker transfer.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//   - tokenPath: token contract path used as the history-tree key
	//   - amount: cumulative amount actually transferred to GovStaker in token base units
	//
	// Returns:
	//   - err: nil when the value is stored; an error for invalid realm context, missing tree, or KV-store failure
	SetDistributedToGovStakerHistoryItem(_ int, rlm realm, tokenPath string, amount int64) error

	// HasDistributedToDevOpsHistoryStoreKey reports whether the DevOps history tree key exists.
	//
	// Returns:
	//   - exists: true when the cumulative DevOps distribution-history tree is present
	HasDistributedToDevOpsHistoryStoreKey() bool

	// InitializeDistributedToDevOpsHistory creates the DevOps distribution-history tree.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//
	// Returns:
	//   - err: nil when initialization succeeds; an error for invalid realm context or KV-store failure
	InitializeDistributedToDevOpsHistory(_ int, rlm realm) error

	// GetDistributedToDevOpsHistory returns cumulative actual DevOps transfers by token.
	//
	// Returns:
	//   - tree: persistent BPTree keyed by token path with int64 transferred amounts
	GetDistributedToDevOpsHistory() *bptree.BPTree

	// GetDistributedToDevOpsHistoryItem reads one token's actual DevOps transfer.
	//
	// Parameters:
	//   - tokenPath: token contract path used as the history-tree key
	//
	// Returns:
	//   - amount: stored transferred amount in token base units, or zero when tokenPath is absent
	//   - exists: true when tokenPath has a stored history amount; false when absent
	GetDistributedToDevOpsHistoryItem(tokenPath string) (int64, bool)

	// SetDistributedToDevOpsHistoryItem stores one token's actual DevOps transfer.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//   - tokenPath: token contract path used as the history-tree key
	//   - amount: cumulative amount actually transferred to DevOps in token base units
	//
	// Returns:
	//   - err: nil when the value is stored; an error for invalid realm context, missing tree, or KV-store failure
	SetDistributedToDevOpsHistoryItem(_ int, rlm realm, tokenPath string, amount int64) error

	// HasReservedTokensStoreKey reports whether the reserved-token index key exists.
	//
	// Returns:
	//   - exists: true when the reserved-token index is present in the KV store
	HasReservedTokensStoreKey() bool

	// InitializeReservedTokens creates the empty reserved-token index.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//
	// Returns:
	//   - err: nil when initialization succeeds; an error for invalid realm context or KV-store failure
	InitializeReservedTokens(_ int, rlm realm) error

	// GetReservedTokens returns token paths currently marked as awaiting distribution.
	//
	// Returns:
	//   - tokenPaths: keys in the reserved-token index
	GetReservedTokens() []string

	// HasReservedToken reports whether tokenPath is in the reserved-token index.
	//
	// Parameters:
	//   - tokenPath: token contract path to look up in the reserved-token index
	//
	// Returns:
	//   - exists: true when tokenPath is reserved for distribution
	HasReservedToken(tokenPath string) bool

	// AddReservedToken marks tokenPath as awaiting fee distribution.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//   - tokenPath: token contract path to add to the reserved-token index
	//
	// Returns:
	//   - err: nil when added or already present; an error for invalid realm context or KV-store failure
	AddReservedToken(_ int, rlm realm, tokenPath string) error

	// RemoveReservedToken removes tokenPath from the reserved-token index when present.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//   - tokenPath: token contract path to remove from the reserved-token index
	//
	// Returns:
	//   - err: nil when removed or already absent; an error for invalid realm context or KV-store failure
	RemoveReservedToken(_ int, rlm realm, tokenPath string) error

	// HasAccrualEpochStoreKey reports whether the accrual-epoch key exists.
	//
	// Returns:
	//   - exists: true when the current accrual epoch is present in the KV store
	HasAccrualEpochStoreKey() bool

	// InitializeAccrualEpoch creates the accrual-epoch key with epoch zero.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//
	// Returns:
	//   - err: nil when initialization succeeds; an error for invalid realm context or KV-store failure
	InitializeAccrualEpoch(_ int, rlm realm) error

	// GetAccrualEpoch reads the epoch currently assigned to newly collected fees.
	//
	// Returns:
	//   - epoch: current non-negative accrual epoch
	GetAccrualEpoch() int64

	// SetAccrualEpoch persists a new current accrual epoch.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//   - accrualEpoch: epoch number to store for subsequently collected fees
	//
	// Returns:
	//   - err: nil when the epoch is stored; an error for invalid realm context or KV-store failure
	SetAccrualEpoch(_ int, rlm realm, accrualEpoch int64) error

	// HasAccrualBucketsStoreKey reports whether the accrual-buckets tree key exists.
	//
	// Returns:
	//   - exists: true when the per-token accrual-bucket tree is present
	HasAccrualBucketsStoreKey() bool

	// InitializeAccrualBuckets creates the empty per-token accrual-bucket tree.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//
	// Returns:
	//   - err: nil when initialization succeeds; an error for invalid realm context or KV-store failure
	InitializeAccrualBuckets(_ int, rlm realm) error

	// GetAccrualBuckets reads the oldest pending buckets for one token without removing them.
	//
	// Parameters:
	//   - tokenPath: token contract path whose accrual buckets are queried
	//   - limit: maximum number of oldest buckets; zero or negative returns all pending buckets
	//
	// Returns:
	//   - epochs: selected accrual epoch numbers in ascending order
	//   - amounts: bucket amounts corresponding positionally to epochs, in token base units
	GetAccrualBuckets(tokenPath string, limit int) ([]int64, []int64)

	// AddAccrualBucket adds amount to one token's bucket for an accrual epoch.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//   - tokenPath: token contract path whose accrual bucket is updated
	//   - epoch: accrual epoch receiving the fee amount
	//   - amount: fee amount in token base units to add to that epoch bucket
	//
	// Returns:
	//   - err: nil when the bucket is stored; an error for invalid realm context or KV-store failure
	AddAccrualBucket(_ int, rlm realm, tokenPath string, epoch int64, amount int64) error

	// RemoveAccrualBuckets removes specified epoch buckets for one token.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//   - tokenPath: token contract path whose buckets are removed
	//   - epochs: accrual epoch numbers to remove; an empty result removes no buckets
	//
	// Returns:
	//   - err: nil when removal succeeds; an error for invalid realm context or KV-store failure
	RemoveAccrualBuckets(_ int, rlm realm, tokenPath string, epochs []int64) error

	// HasAccrualPendingTokensStoreKey reports whether the pending-token index key exists.
	//
	// Returns:
	//   - exists: true when the index of tokens with pending buckets is present
	HasAccrualPendingTokensStoreKey() bool

	// InitializeAccrualPendingTokens creates the empty pending-token index.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//
	// Returns:
	//   - err: nil when initialization succeeds; an error for invalid realm context or KV-store failure
	InitializeAccrualPendingTokens(_ int, rlm realm) error

	// GetAccrualPendingTokens returns token paths indexed as owning pending buckets.
	//
	// Returns:
	//   - tokenPaths: token contract paths present in the pending-token index
	GetAccrualPendingTokens() []string

	// AddAccrualPendingToken marks a token path as owning at least one pending bucket.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//   - tokenPath: token contract path to add to the pending-token index
	//
	// Returns:
	//   - err: nil when added or already present; an error for invalid realm context or KV-store failure
	AddAccrualPendingToken(_ int, rlm realm, tokenPath string) error

	// RemoveAccrualPendingToken removes a token path from the pending-token index when present.
	//
	// Parameters:
	//   - _: cross-call discriminator; callers pass 0
	//   - rlm: propagated protocol_fee realm context required for the authorized store write
	//   - tokenPath: token contract path to remove after its pending buckets are consumed
	//
	// Returns:
	//   - err: nil when removed or already absent; an error for invalid realm context or KV-store failure
	RemoveAccrualPendingToken(_ int, rlm realm, tokenPath string) error
}
