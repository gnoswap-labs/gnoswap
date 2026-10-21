package limit_order

import (
	"time"

	u256 "gno.land/p/gnoswap/uint256/v1"
)

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

// LimitOrder keeps the original net exchange ratio and immutable execution fee.
// GrossOutput is already net of the Router fee. Execution fees are paid at each
// fill, but rounded on cumulative gross output so splitting cannot evade them.
type LimitOrder struct {
	id            uint64
	owner         address
	poolPath      string
	inputMint     address
	outputMint    address
	makingAmount  *u256.Uint
	takingAmount  *u256.Uint
	slippageBps   uint64
	feeBps        uint64
	feeRecipient  address
	status        OrderStatus
	createdAt     int64
	expiredAt     int64
	filledInput   *u256.Uint
	refundedInput *u256.Uint
	grossOutput   *u256.Uint
	executionFee  *u256.Uint
}

// OrderView exposes scalar snapshots rather than mutable accounting pointers.
type OrderView struct {
	ID             uint64
	Owner          address
	PoolPath       string
	InputMint      address
	OutputMint     address
	MakingAmount   uint64
	TakingAmount   uint64
	SlippageBps    uint64
	FeeBps         uint64
	FeeRecipient   address
	Status         OrderStatus
	CreatedAt      int64
	ExpiredAt      int64
	FilledInput    uint64
	RefundedInput  uint64
	RemainingInput uint64
	GrossOutput    uint64
	ExecutionFee   uint64
}

func NewLimitOrder(id uint64, owner address, poolPath string, inputMint, outputMint address, makingAmount, takingAmount *u256.Uint, slippageBps uint64, feeRecipient address, expiredAt int64) *LimitOrder {
	max := u256.NewUint(MAX_TOKEN_AMOUNT)
	if makingAmount.IsZero() || makingAmount.Gt(max) {
		panic(ErrInvalidAmountIn)
	}
	if takingAmount.IsZero() || takingAmount.Gt(max) {
		panic(ErrInvalidMinAmountOut)
	}
	if slippageBps > 1000 {
		panic(ErrInvalidSlippage)
	}
	return &LimitOrder{
		id: id, owner: owner, poolPath: poolPath,
		inputMint: inputMint, outputMint: outputMint,
		makingAmount: u256.Zero().Set(makingAmount),
		takingAmount: u256.Zero().Set(takingAmount),
		slippageBps:  slippageBps, feeBps: EXECUTION_FEE_BPS, feeRecipient: feeRecipient,
		status: OrderStatusActive, createdAt: time.Now().Unix(), expiredAt: expiredAt,
		filledInput: u256.Zero(), refundedInput: u256.Zero(),
		grossOutput: u256.Zero(), executionFee: u256.Zero(),
	}
}

func (o *LimitOrder) ID() uint64                   { return o.id }
func (o *LimitOrder) Owner() address               { return o.owner }
func (o *LimitOrder) PoolPath() string             { return o.poolPath }
func (o *LimitOrder) InputMint() address           { return o.inputMint }
func (o *LimitOrder) OutputMint() address          { return o.outputMint }
func (o *LimitOrder) MakingAmount() *u256.Uint     { return o.makingAmount }
func (o *LimitOrder) TakingAmount() *u256.Uint     { return o.takingAmount }
func (o *LimitOrder) SlippageBps() uint64          { return o.slippageBps }
func (o *LimitOrder) FeeBps() uint64               { return o.feeBps }
func (o *LimitOrder) FeeRecipient() address        { return o.feeRecipient }
func (o *LimitOrder) Status() OrderStatus          { return o.status }
func (o *LimitOrder) CreatedAt() int64             { return o.createdAt }
func (o *LimitOrder) ExpiredAt() int64             { return o.expiredAt }
func (o *LimitOrder) FilledInput() *u256.Uint      { return o.filledInput }
func (o *LimitOrder) RefundedInput() *u256.Uint    { return o.refundedInput }
func (o *LimitOrder) GrossOutput() *u256.Uint      { return o.grossOutput }
func (o *LimitOrder) ExecutionFee() *u256.Uint     { return o.executionFee }
func (o *LimitOrder) SetStatus(status OrderStatus) { o.status = status }

func (o *LimitOrder) RemainingInput() *u256.Uint {
	used := u256.Zero().Add(o.filledInput, o.refundedInput)
	return u256.Zero().Sub(o.makingAmount, used)
}

func (o *LimitOrder) IsExpired() bool { return time.Now().Unix() >= o.expiredAt }
func (o *LimitOrder) IsActive() bool {
	return o.status == OrderStatusActive && !o.IsExpired() && !o.RemainingInput().IsZero()
}

// MinimumUserOutput rounds the slippage-adjusted exchange ratio upward for
// this fill. All multiplicands are bounded by int64 or 10000, so the products
// fit in 140 bits, without relying on truncating uint256 overflow behavior.
func (o *LimitOrder) MinimumUserOutput(amountIn *u256.Uint) *u256.Uint {
	if amountIn.IsZero() || amountIn.Gt(o.RemainingInput()) {
		panic(ErrInvalidFillAmount)
	}
	numerator := u256.Zero().Mul(o.takingAmount, amountIn)
	numerator.Mul(numerator, u256.NewUint(BPS_DENOMINATOR-o.slippageBps))
	denominator := u256.Zero().Mul(o.makingAmount, u256.NewUint(BPS_DENOMINATOR))
	return divideRoundingUp(numerator, denominator)
}

// GetMinimumOutput returns the exact minimum Router-net output needed by this
// fill, including the next cumulative execution-fee rounding boundary.
// With net(G) = G-floor(G*f/D) = ceil(G*(D-f)/D), the least gross output
// producing N net units is floor((N-1)*D/(D-f))+1.
func (o *LimitOrder) GetMinimumOutput(amountIn *u256.Uint) *u256.Uint {
	minimum := o.MinimumUserOutput(amountIn)
	netSoFar := u256.Zero().Sub(o.grossOutput, o.executionFee)
	requiredNet := u256.Zero().Add(netSoFar, minimum)
	numerator := u256.Zero().Sub(requiredNet, u256.NewUint(1))
	numerator.Mul(numerator, u256.NewUint(BPS_DENOMINATOR))
	requiredGross := u256.Zero().Div(numerator, u256.NewUint(BPS_DENOMINATOR-o.feeBps))
	requiredGross.Add(requiredGross, u256.NewUint(1))
	return u256.Zero().Sub(requiredGross, o.grossOutput)
}

// ApplyFill validates all quantities before changing any accounting. The
// implementation persists this result before paying the owner and recipient.
func (o *LimitOrder) ApplyFill(amountIn, amountOut *u256.Uint) {
	if o.status != OrderStatusActive {
		panic(ErrOrderNotActive)
	}
	if o.IsExpired() {
		panic(ErrOrderExpired)
	}
	minimum := o.MinimumUserOutput(amountIn)
	if amountOut.IsZero() || amountOut.Gt(u256.NewUint(MAX_TOKEN_AMOUNT)) {
		panic(ErrInsufficientOutput)
	}
	gross := u256.Zero().Add(o.grossOutput, amountOut)
	if gross.Gt(u256.NewUint(MAX_TOKEN_AMOUNT)) {
		panic(ErrAmountOverflow)
	}
	fee := u256.Zero().Mul(gross, u256.NewUint(o.feeBps))
	fee.Div(fee, u256.NewUint(BPS_DENOMINATOR))
	incrementalFee := u256.Zero().Sub(fee, o.executionFee)
	net := u256.Zero().Sub(amountOut, incrementalFee)
	if net.Lt(minimum) {
		panic(ErrSlippageExceeded)
	}
	filled := u256.Zero().Add(o.filledInput, amountIn)
	o.filledInput = filled
	o.grossOutput = gross
	o.executionFee = fee
	if filled.Eq(o.makingAmount) {
		o.status = OrderStatusExecuted
	}
}

// RefundInput consumes the remaining escrow exactly once, without pretending
// that refunded input was traded.
func (o *LimitOrder) RefundInput() *u256.Uint {
	remaining := o.RemainingInput()
	o.refundedInput = u256.Zero().Add(o.refundedInput, remaining)
	return remaining
}

func (o *LimitOrder) View() OrderView {
	return OrderView{
		ID: o.id, Owner: o.owner, PoolPath: o.poolPath,
		InputMint: o.inputMint, OutputMint: o.outputMint,
		MakingAmount: o.makingAmount.Uint64(), TakingAmount: o.takingAmount.Uint64(),
		SlippageBps: o.slippageBps, FeeBps: o.feeBps, FeeRecipient: o.feeRecipient,
		Status: o.status, CreatedAt: o.createdAt, ExpiredAt: o.expiredAt,
		FilledInput: o.filledInput.Uint64(), RefundedInput: o.refundedInput.Uint64(),
		RemainingInput: o.RemainingInput().Uint64(),
		GrossOutput:    o.grossOutput.Uint64(), ExecutionFee: o.executionFee.Uint64(),
	}
}

func divideRoundingUp(numerator, denominator *u256.Uint) *u256.Uint {
	quotient, remainder := u256.Zero(), u256.Zero()
	quotient.DivMod(numerator, denominator, remainder)
	if !remainder.IsZero() {
		quotient.Add(quotient, u256.NewUint(1))
	}
	return quotient
}
