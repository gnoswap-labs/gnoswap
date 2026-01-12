package dca_order

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
)

// Order represents a user's DCA order
type Order struct {
	ID    string
	Owner address

	PoolPath   string
	TokenIn    string
	TokenOut   string
	ZeroForOne bool

	AmountPerExecution int64
	TotalExecutions    int
	Interval           int64 // execution interval in seconds

	CreatedAt int64
}

// OrderGroup groups orders by (poolPath + zeroForOne + interval)
// All orders in a group are executed together for gas efficiency
type OrderGroup struct {
	ID         string // poolPath:zeroForOne:interval
	PoolPath   string
	ZeroForOne bool
	Interval   int64

	DepositedAmount int64 // total deposited input tokens
	ClaimedAmount   int64 // total claimed output tokens

	AccumulatedOutX128PerAmount *u256.Uint
	AccumulatedTimestamp        int64

	ReservedOrderChanges *avl.Tree // timestamp(string) -> []*OrderChange

	OrderStates *avl.Tree // orderID(string) -> *OrderState
}

func (group *OrderGroup) AddAccumulatedOutX128PerAmount(amount *u256.Uint) {
	group.AccumulatedOutX128PerAmount = u256.Zero().Add(group.AccumulatedOutX128PerAmount, amount)
}

func (group *OrderGroup) AddClaimedAmount(amount int64) {
	group.ClaimedAmount += amount
}

// OrderChange represents a pending deposit or withdrawal
type OrderChange struct {
	OrderID   string
	Amount    int64
	IsDeposit bool
}

// OrderState tracks individual order state within a group
type OrderState struct {
	OrderID              string
	DepositedAmount      int64      // deposited input tokens
	ClaimedAmount        int64      // claimed output tokens
	AccumulatedOut       int64      // accumulated output from swaps
	OutAmountDebtX128    *u256.Uint // debt at entry (for accumulator calculation)
	FinalAccumulatorX128 *u256.Uint // accumulator at order expiry (nil if not expired)
	ClaimedTimestamp     int64
	LastUpdateTimestamp  int64
}

// BatchResult represents the result of a batch swap execution
type BatchResult struct {
	GroupID   string
	AmountIn  int64
	AmountOut int64
	Success   bool
	Error     string
}

// Helper functions

// NewOrderGroup creates a new OrderGroup
func NewOrderGroup(poolPath string, zeroForOne bool, interval int64) *OrderGroup {
	id := makeGroupID(poolPath, zeroForOne, interval)
	return &OrderGroup{
		ID:                          id,
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
func NewOrderState(orderID string, debtX128 *u256.Uint, timestamp int64) *OrderState {
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
