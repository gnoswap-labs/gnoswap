package limit_order

import (
	"time"

	u256 "gno.land/p/gnoswap/uint256"
)

// OrderStatus represents the current state of a limit order
type OrderStatus uint8

const (
	OrderStatusActive OrderStatus = iota
	OrderStatusExecuted
	OrderStatusCancelled
	OrderStatusExpired
)

func (s OrderStatus) String() string {
	switch s {
	case OrderStatusActive:
		return "ACTIVE"
	case OrderStatusExecuted:
		return "EXECUTED"
	case OrderStatusCancelled:
		return "CANCELLED"
	case OrderStatusExpired:
		return "EXPIRED"
	default:
		return "UNKNOWN"
	}
}

// LimitOrder represents an intent-based limit order
// Tokens are escrowed in the contract and executed by keepers when conditions are met
type LimitOrder struct {
	id       uint64
	owner    address
	poolPath string

	// Order parameters
	inputMint    address    // Input token (escrowed)
	outputMint   address    // Output token (target)
	makingAmount *u256.Uint // Amount user provides (input)
	takingAmount *u256.Uint // Amount user wants to receive (output)

	// Execution parameters
	slippageBps uint64 // Slippage in basis points (0 for exact execution)
	feeBps      uint64 // Keeper fee in basis points

	// Status and metadata
	status    OrderStatus
	deposited bool
	createdAt int64
	expiredAt int64
}

func NewLimitOrder(
	id uint64,
	owner address,
	poolPath string,
	inputMint address,
	outputMint address,
	makingAmount *u256.Uint,
	takingAmount *u256.Uint,
	slippageBps uint64,
	feeBps uint64,
	expiredAt int64,
) *LimitOrder {
	return &LimitOrder{
		id:           id,
		owner:        owner,
		poolPath:     poolPath,
		inputMint:    inputMint,
		outputMint:   outputMint,
		makingAmount: makingAmount,
		takingAmount: takingAmount,
		slippageBps:  slippageBps,
		feeBps:       feeBps,
		status:       OrderStatusActive,
		deposited:    false,
		createdAt:    time.Now().Unix(),
		expiredAt:    expiredAt,
	}
}

// Getters
func (o *LimitOrder) ID() uint64 {
	return o.id
}

func (o *LimitOrder) Owner() address {
	return o.owner
}

func (o *LimitOrder) PoolPath() string {
	return o.poolPath
}

func (o *LimitOrder) InputMint() address {
	return o.inputMint
}

func (o *LimitOrder) OutputMint() address {
	return o.outputMint
}

func (o *LimitOrder) MakingAmount() *u256.Uint {
	return o.makingAmount
}

func (o *LimitOrder) TakingAmount() *u256.Uint {
	return o.takingAmount
}

func (o *LimitOrder) SlippageBps() uint64 {
	return o.slippageBps
}

func (o *LimitOrder) FeeBps() uint64 {
	return o.feeBps
}

func (o *LimitOrder) Status() OrderStatus {
	return o.status
}

func (o *LimitOrder) Deposited() bool {
	return o.deposited
}

func (o *LimitOrder) CreatedAt() int64 {
	return o.createdAt
}

func (o *LimitOrder) ExpiredAt() int64 {
	return o.expiredAt
}

// Setters
func (o *LimitOrder) SetStatus(status OrderStatus) {
	o.status = status
}

func (o *LimitOrder) SetDeposited(deposited bool) {
	o.deposited = deposited
}

// IsActive checks if the order is active and not expired
func (o *LimitOrder) IsActive() bool {
	if o.status != OrderStatusActive {
		return false
	}
	if !o.deposited {
		return false
	}
	if time.Now().Unix() >= o.expiredAt {
		return false
	}
	return true
}

// IsExpired checks if the order has passed its expiration time
func (o *LimitOrder) IsExpired() bool {
	return time.Now().Unix() >= o.expiredAt
}

// GetLimitPrice calculates the limit price from takingAmount/makingAmount
// Returns the price of output per input (takingAmount / makingAmount)
func (o *LimitOrder) GetLimitPrice() *u256.Uint {
	if o.makingAmount.IsZero() {
		return u256.Zero()
	}
	// Price = takingAmount / makingAmount
	// Scale up for precision
	q96 := u256.MustFromDecimal("79228162514264337593543950336") // 2^96
	scaled := u256.Zero().Mul(o.takingAmount, q96)
	price := u256.Zero().Div(scaled, o.makingAmount)
	return price
}

// CanExecute checks if the order can be executed by a keeper
// Compares current market price with order's limit price
func (o *LimitOrder) CanExecute(currentPrice *u256.Uint) bool {
	if !o.IsActive() {
		return false
	}

	limitPrice := o.GetLimitPrice()

	// For zero slippage: current price must exactly match or be better
	if o.slippageBps == 0 {
		return currentPrice.Gte(limitPrice)
	}

	// With slippage: calculate price with slippage tolerance
	slippageAmount := u256.Zero().Mul(limitPrice, u256.NewUint(o.slippageBps))
	slippageAmount = u256.Zero().Div(slippageAmount, u256.NewUint(BPS_DENOMINATOR))
	minAcceptablePrice := u256.Zero().Sub(limitPrice, slippageAmount)

	return currentPrice.Gte(minAcceptablePrice)
}

// GetMinimumOutput calculates the minimum acceptable output considering slippage and keeper fee
// Returns the total output needed so that after keeper fee, user receives at least takingAmount
func (o *LimitOrder) GetMinimumOutput() *u256.Uint {
	// Calculate target amount considering slippage
	var targetAmount *u256.Uint
	if o.slippageBps == 0 {
		// Zero slippage: target exact takingAmount
		targetAmount = o.takingAmount
	} else {
		// With slippage: apply slippage tolerance
		slippageAmount := u256.Zero().Mul(o.takingAmount, u256.NewUint(o.slippageBps))
		slippageAmount = u256.Zero().Div(slippageAmount, u256.NewUint(BPS_DENOMINATOR))
		targetAmount = u256.Zero().Sub(o.takingAmount, slippageAmount)
	}

	// Calculate total output needed to give user targetAmount after keeper fee
	// Formula: totalOutput = targetAmount * 10000 / (10000 - feeBps)
	denominator := BPS_DENOMINATOR - o.feeBps
	minOutput := u256.Zero().Mul(targetAmount, u256.NewUint(BPS_DENOMINATOR))
	minOutput = u256.Zero().Div(minOutput, u256.NewUint(denominator))

	return minOutput
}
