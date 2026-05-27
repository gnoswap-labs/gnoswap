package protocol_fee

import bptree "gno.land/p/nt/bptree/v0"

type IProtocolFee interface {
	IProtocolFeeManager
	IProtocolFeeGetter
}

type IProtocolFeeManager interface {
	// Mutating methods take `_ int, rlm realm` so the realm token is threaded
	// from the proxy entry points down to the cross-realm token transfers and
	// store writes performed inside each implementation. The `_ int` sentinel
	// surfaces at every call site as a literal `0`, making the realm threading
	// visible to readers.
	DistributeProtocolFee(_ int, rlm realm)
	SetDevOpsPct(_ int, rlm realm, pct int64)
	SetGovStakerPct(_ int, rlm realm, pct int64)
	AddToProtocolFee(_ int, rlm realm, tokenPath string, amount int64) error
}

type IProtocolFeeGetter interface {
	GetDevOpsPct() int64
	GetGovStakerPct() int64
	GetReservedTokens() []string
	GetAccuTransfersToGovStaker() map[string]int64
	GetAccuTransfersToDevOps() map[string]int64
	GetAccuTransferToGovStakerByTokenPath(path string) int64
	GetAccuTransferToDevOpsByTokenPath(path string) int64
	GetActualDistributedToGovStaker() map[string]int64
	GetActualDistributedToDevOps() map[string]int64
	GetActualDistributedToGovStakerByTokenPath(path string) int64
	GetActualDistributedToDevOpsByTokenPath(path string) int64
}

type IProtocolFeeStore interface {
	HasDevOpsPctStoreKey() bool
	InitializeDevOpsPct(_ int, rlm realm) error
	GetDevOpsPct() int64
	SetDevOpsPct(_ int, rlm realm, pct int64) error

	HasAccuToGovStakerStoreKey() bool
	InitializeAccuToGovStaker(_ int, rlm realm) error
	GetAccuToGovStaker() *bptree.BPTree
	GetAccuToGovStakerItem(tokenPath string) (int64, bool)
	SetAccuToGovStakerItem(_ int, rlm realm, tokenPath string, amount int64) error

	HasAccuToDevOpsStoreKey() bool
	InitializeAccuToDevOps(_ int, rlm realm) error
	GetAccuToDevOps() *bptree.BPTree
	GetAccuToDevOpsItem(tokenPath string) (int64, bool)
	SetAccuToDevOpsItem(_ int, rlm realm, tokenPath string, amount int64) error

	HasDistributedToGovStakerHistoryStoreKey() bool
	InitializeDistributedToGovStakerHistory(_ int, rlm realm) error
	GetDistributedToGovStakerHistory() *bptree.BPTree
	GetDistributedToGovStakerHistoryItem(tokenPath string) (int64, bool)
	SetDistributedToGovStakerHistoryItem(_ int, rlm realm, tokenPath string, amount int64) error

	HasDistributedToDevOpsHistoryStoreKey() bool
	InitializeDistributedToDevOpsHistory(_ int, rlm realm) error
	GetDistributedToDevOpsHistory() *bptree.BPTree
	GetDistributedToDevOpsHistoryItem(tokenPath string) (int64, bool)
	SetDistributedToDevOpsHistoryItem(_ int, rlm realm, tokenPath string, amount int64) error

	HasReservedTokensStoreKey() bool
	InitializeReservedTokens(_ int, rlm realm) error
	GetReservedTokens() []string
	SetReservedTokens(_ int, rlm realm, reservedTokens []string) error
	AddReservedToken(_ int, rlm realm, tokenPath string) error
}
