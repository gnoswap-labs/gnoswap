package dca_order

import (
	"gno.land/p/demo/avl"
	u256 "gno.land/p/gnoswap/uint256"
)

// Order represents a user's DCA order
type Order struct {
	ID    int64
	Owner address

	// Swap configuration
	PoolPath   string
	TokenIn    string
	TokenOut   string
	ZeroForOne bool

	// Amount configuration
	AmountPerExecution int64
	TotalExecutions    int
	Interval           int64 // execution interval in seconds

	// Timestamps
	CreatedAt int64
}

// OrderGroup groups orders by (poolPath + zeroForOne + interval)
// All orders in a group are executed together for gas efficiency
type OrderGroup struct {
	Key        string // poolPath:zeroForOne:interval
	PoolPath   string
	ZeroForOne bool
	Interval   int64

	// Aggregated amounts
	DepositedAmount int64 // total deposited input tokens
	ClaimedAmount   int64 // total claimed output tokens

	// Accumulator for fair distribution (scaled by 2^128)
	AccumulatedOutX128PerAmount *u256.Uint
	AccumulatedTimestamp        int64

	// Pending order changes to be applied at specific timestamps
	ReservedOrderChanges *avl.Tree // timestamp(string) -> []*OrderChange

	// Individual order states within this group
	OrderStates *avl.Tree // orderID(string) -> *OrderState
}

// OrderChange represents a pending deposit or withdrawal
type OrderChange struct {
	OrderID   int64
	Amount    int64
	IsDeposit bool
}

// OrderState tracks individual order state within a group
type OrderState struct {
	OrderID             int64
	DepositedAmount     int64      // deposited input tokens
	ClaimedAmount       int64      // claimed output tokens
	AccumulatedOut      int64      // accumulated output from swaps
	OutAmountDebtX128   *u256.Uint // debt at entry (for accumulator calculation)
	ClaimedTimestamp    int64
	LastUpdateTimestamp int64
}

// BatchResult represents the result of a batch swap execution
type BatchResult struct {
	GroupKey  string
	AmountIn  int64
	AmountOut int64
	Success   bool
	Error     string
}

// Helper functions

// NewOrderGroup creates a new OrderGroup
func NewOrderGroup(poolPath string, zeroForOne bool, interval int64) *OrderGroup {
	key := makeGroupKey(poolPath, zeroForOne, interval)
	return &OrderGroup{
		Key:                         key,
		PoolPath:                    poolPath,
		ZeroForOne:                  zeroForOne,
		Interval:                    interval,
		DepositedAmount:             0,
		ClaimedAmount:               0,
		AccumulatedOutX128PerAmount: u256.Zero(),
		AccumulatedTimestamp:        0,
		ReservedOrderChanges:        avl.NewTree(),
		OrderStates:                 avl.NewTree(),
	}
}

// NewOrderState creates a new OrderState
func NewOrderState(orderID int64, debtX128 *u256.Uint, timestamp int64) *OrderState {
	return &OrderState{
		OrderID:             orderID,
		DepositedAmount:     0,
		ClaimedAmount:       0,
		AccumulatedOut:      0,
		OutAmountDebtX128:   debtX128.Clone(),
		ClaimedTimestamp:    0,
		LastUpdateTimestamp: timestamp,
	}
}
