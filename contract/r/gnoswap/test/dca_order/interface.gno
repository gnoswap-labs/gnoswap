package dca_order

import (
	bptree "gno.land/p/nt/bptree/v0"
)

// ErrSpoofedRealm is returned when a store write receives a non-current realm.
const ErrSpoofedRealm = "[GNOSWAP-DCA-ORDER-000] spoofed realm"

// ErrUpgradeWhileExecuting is raised when UpgradeImpl runs during a group swap.
const ErrUpgradeWhileExecuting = "[GNOSWAP-DCA-ORDER-021] cannot upgrade while a group execution is in progress"

// IDCAOrder is the implementation interface behind the dca_order proxy.
type IDCAOrder interface {
	IDCAOrderManager
	IDCAOrderExecutor
	IDCAOrderAdmin
	IDCAOrderGetter
}

// IDCAOrderManager covers owner-facing order operations.
type IDCAOrderManager interface {
	// CreateOrder escrows amountPerExecution*totalExecutions of tokenIn plus the
	// prepaid creation fee and joins the (pool, direction, interval) group.
	// It reverts when the current fee exceeds maxFeeBps.
	CreateOrder(
		_ int,
		rlm realm,
		poolPath string,
		tokenIn string,
		interval int64,
		amountPerExecution int64,
		totalExecutions int64,
		maxFeeBps int64,
	) uint64

	// CancelOrder settles output, refunds unsold input, and closes the order.
	// Only the owner may cancel.
	CancelOrder(_ int, rlm realm, orderID uint64) (refundIn int64, claimedOut int64)

	// Claim transfers accrued output to the order owner. Anyone may trigger it;
	// output always goes to the owner.
	Claim(_ int, rlm realm, orderID uint64) int64
}

// IDCAOrderExecutor covers the permissionless keeper entry point.
type IDCAOrderExecutor interface {
	// ExecuteGroup sells the group's per-round input through the router.
	// amountOutMin (0 disables) is the floor the executor quoted for
	// expectedAmountIn; when the rate differs at execution, the floor is
	// scaled to the actual input (expectedAmountIn 0 uses it unscaled).
	ExecuteGroup(_ int, rlm realm, groupID string, expectedAmountIn int64, amountOutMin int64) (amountIn int64, amountOut int64)
}

// IDCAOrderAdmin covers admin/governance configuration.
type IDCAOrderAdmin interface {
	SetCreationFeeBps(_ int, rlm realm, feeBps int64)
	SetOrderLimits(_ int, rlm realm, minAmountPerExecution int64, maxTotalExecutions int64)
	WithdrawFee(_ int, rlm realm, tokenPath string, recipient address, amount int64)
}

// IDCAOrderGetter covers read-only queries. JSON-returning getters are meant
// for off-chain keepers and indexers.
type IDCAOrderGetter interface {
	GetOrderJSON(orderID uint64) string
	GetGroupJSON(groupID string) string
	GetConfigJSON() string
	GetClaimable(orderID uint64) int64
	GetPendingFee(tokenPath string) int64
	GetGroupIDs(offset int, count int) string
	GetExecutableGroups(cursor string, count int) string
	GetOrderIDsByOwner(owner address, startAfterID uint64, count int) string
}

// IDCAOrderStore is the persistent storage interface shared by all versions.
// Typed accessors are fixed at deployment; later versions add state through
// the Extension accessors.
type IDCAOrderStore interface {
	HasOrders() bool
	GetOrders() *bptree.BPTree
	SetOrders(_ int, rlm realm, orders *bptree.BPTree) error

	HasOrdersByOwner() bool
	GetOrdersByOwner() *bptree.BPTree
	SetOrdersByOwner(_ int, rlm realm, ordersByOwner *bptree.BPTree) error

	HasGroups() bool
	GetGroups() *bptree.BPTree
	SetGroups(_ int, rlm realm, groups *bptree.BPTree) error

	HasScheduledGroups() bool
	GetScheduledGroups() *bptree.BPTree
	SetScheduledGroups(_ int, rlm realm, groups *bptree.BPTree) error

	HasPendingFees() bool
	GetPendingFees() *bptree.BPTree
	SetPendingFees(_ int, rlm realm, fees *bptree.BPTree) error

	HasNextOrderID() bool
	GetNextOrderID() uint64
	SetNextOrderID(_ int, rlm realm, id uint64) error

	HasConfig() bool
	GetConfig() *Config
	SetConfig(_ int, rlm realm, config *Config) error

	IsExecuting() bool
	SetExecuting(_ int, rlm realm, executing bool) error

	HasExtension(key string) bool
	GetExtension(key string) (any, error)
	SetExtension(_ int, rlm realm, key string, value any) error
	DeleteExtension(_ int, rlm realm, key string) error
}
