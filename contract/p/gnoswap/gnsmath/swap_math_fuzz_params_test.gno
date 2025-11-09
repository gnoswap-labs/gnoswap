package gnsmath

import (
	"gno.land/p/gnoswap/fuzz"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// Parameters for SwapMathComputeSwapStep fuzzing test
type swapMathComputeSwapStepParams struct {
	sqrtRatioCurrentX96 string
	sqrtRatioTargetX96  string
	liquidity           string
	amountRemaining     string
	feePips             uint64
}

func (p *swapMathComputeSwapStepParams) IsValid() bool {
	// Parse and validate basic parameters
	sqrtCurrent, sqrtTarget, liquidity, amountRemaining, err := p.parseAndValidateBasicParams()
	if err != nil {
		return false
	}

	// Determine swap direction and mode
	zeroForOne := sqrtCurrent.Gte(sqrtTarget)
	exactIn := !amountRemaining.IsNeg()
	amountRemainingAbs := amountRemaining.Abs()

	// Calculate withoutFeeRateInPips for exactIn
	denominator := uint64(1000000)
	withoutFeeRateInPips := u256.NewUint(denominator - p.feePips)

	if exactIn {
		return p.validateExactIn(
			sqrtCurrent,
			sqrtTarget,
			liquidity,
			amountRemainingAbs,
			withoutFeeRateInPips,
			zeroForOne,
			denominator,
		)
	}

	return p.validateExactOut(
		sqrtCurrent,
		sqrtTarget,
		liquidity,
		amountRemainingAbs,
		zeroForOne,
	)
}

// parseAndValidateBasicParams parses and validates basic parameters
func (p *swapMathComputeSwapStepParams) parseAndValidateBasicParams() (
	sqrtCurrent, sqrtTarget, liquidity *u256.Uint,
	amountRemaining *i256.Int,
	err error,
) {
	sqrtCurrent, err = u256.FromDecimal(p.sqrtRatioCurrentX96)
	if err != nil {
		return nil, nil, nil, nil, err
	}

	sqrtTarget, err = u256.FromDecimal(p.sqrtRatioTargetX96)
	if err != nil {
		return nil, nil, nil, nil, err
	}

	liquidity, err = u256.FromDecimal(p.liquidity)
	if err != nil {
		return nil, nil, nil, nil, err
	}

	amountRemaining, err = i256.FromDecimal(p.amountRemaining)
	if err != nil {
		return nil, nil, nil, nil, err
	}

	// Check basic constraints
	if p.feePips > 1_000_000 {
		return nil, nil, nil, nil, errInvalidPoolSqrtPrice
	}

	if sqrtCurrent.IsZero() || sqrtTarget.IsZero() {
		return nil, nil, nil, nil, errInvalidPoolSqrtPrice
	}

	return sqrtCurrent, sqrtTarget, liquidity, amountRemaining, nil
}

// validateExactIn validates exactIn swap parameters
func (p *swapMathComputeSwapStepParams) validateExactIn(
	sqrtCurrent, sqrtTarget, liquidity, amountRemainingAbs, withoutFeeRateInPips *u256.Uint,
	zeroForOne bool,
	denominator uint64,
) bool {
	// Calculate amount after fee
	amountRemainingLessFee := u256.MulDiv(
		amountRemainingAbs,
		withoutFeeRateInPips,
		u256.NewUint(denominator),
	)

	// If fee consumes all amount, it's valid (returns current price)
	if amountRemainingLessFee.IsZero() {
		return true
	}

	// Calculate amount needed to reach target
	var amountIn *u256.Uint
	if zeroForOne {
		amountIn = getAmount0DeltaHelper(sqrtTarget, sqrtCurrent, liquidity, true)
	} else {
		amountIn = getAmount1DeltaHelper(sqrtCurrent, sqrtTarget, liquidity, true)
	}

	// Check if we reach target or do partial move
	if amountRemainingLessFee.Gte(amountIn) {
		// Reach target - validate target price is in bounds
		return sqrtTarget.Gte(MIN_SQRT_RATIO) && sqrtTarget.Lte(MAX_SQRT_RATIO)
	}

	// Partial move - validate next sqrt price calculation
	if zeroForOne {
		return p.validateExactInZeroForOnePartial(sqrtCurrent, liquidity, amountRemainingLessFee)
	}

	return p.validateExactInOneForZeroPartial(sqrtCurrent, liquidity, amountRemainingLessFee)
}

// validateExactInZeroForOnePartial validates exactIn zeroForOne partial move
func (p *swapMathComputeSwapStepParams) validateExactInZeroForOnePartial(
	sqrtCurrent, liquidity, amountRemainingLessFee *u256.Uint,
) bool {
	// Will call getNextSqrtPriceFromAmount0RoundingUp with add=false (remove)
	// This calls getNextPriceAmount0Remove which has validation:
	// quotientCheck.Eq(currentSqrtPriceX96) && liquidityShifted.Gt(amountTimesSqrtPrice)

	// Check liquidity << 96 won't overflow
	max160 := u256.Zero().Lsh(u256.One(), 160)
	if liquidity.Gte(max160) {
		return false
	}

	liquidityShifted := u256.Zero().Lsh(liquidity, 96)
	amountTimesSqrtPrice := u256.Zero().Mul(amountRemainingLessFee, sqrtCurrent)

	// Check multiplication overflow
	if !amountRemainingLessFee.IsZero() {
		quotientCheck := u256.Zero().Div(amountTimesSqrtPrice, amountRemainingLessFee)
		if !quotientCheck.Eq(sqrtCurrent) {
			return false
		}
	}

	// Check liquidityShifted > amountTimesSqrtPrice for getNextPriceAmount0Remove
	if !liquidityShifted.Gt(amountTimesSqrtPrice) {
		return false
	}

	// Check denominator won't be zero
	if sqrtCurrent.IsZero() {
		return false
	}

	// Calculate sqrtNext and validate bounds
	divValue := u256.Zero().Div(liquidityShifted, sqrtCurrent)
	denominator := u256.Zero().Add(divValue, amountRemainingLessFee)
	if denominator.IsZero() {
		return false
	}

	sqrtNext := u256.DivRoundingUp(liquidityShifted, denominator)
	return sqrtNext.Gte(MIN_SQRT_RATIO) && sqrtNext.Lte(MAX_SQRT_RATIO)
}

// validateExactInOneForZeroPartial validates exactIn oneForZero partial move
func (p *swapMathComputeSwapStepParams) validateExactInOneForZeroPartial(
	sqrtCurrent, liquidity, amountRemainingLessFee *u256.Uint,
) bool {
	// Will call getNextSqrtPriceFromAmount1RoundingDown with add=true
	// This calls getNextPriceAmount1Add which adds quotient to sqrtCurrent

	max160 := u256.Zero().Lsh(u256.One(), 160)
	var quotient *u256.Uint

	if amountRemainingLessFee.Lte(max160) {
		// Check liquidity is not zero to avoid division by zero
		if liquidity.IsZero() {
			return false
		}
		shifted := u256.Zero().Lsh(amountRemainingLessFee, 96)
		quotient = u256.Zero().Div(shifted, liquidity)
	} else {
		q96 := u256.Zero().Lsh(u256.One(), 96)
		if liquidity.IsZero() {
			return false
		}
		quotient = u256.MulDiv(amountRemainingLessFee, q96, liquidity)
	}

	// Check addition overflow
	sqrtNext, overflow := u256.Zero().AddOverflow(sqrtCurrent, quotient)
	if overflow {
		return false
	}

	return sqrtNext.Gte(MIN_SQRT_RATIO) && sqrtNext.Lte(MAX_SQRT_RATIO)
}

// validateExactOut validates exactOut swap parameters
func (p *swapMathComputeSwapStepParams) validateExactOut(
	sqrtCurrent, sqrtTarget, liquidity, amountRemainingAbs *u256.Uint,
	zeroForOne bool,
) bool {
	// Calculate amount needed to reach target
	var amountOut *u256.Uint
	if zeroForOne {
		amountOut = getAmount1DeltaHelper(sqrtTarget, sqrtCurrent, liquidity, false)
	} else {
		amountOut = getAmount0DeltaHelper(sqrtCurrent, sqrtTarget, liquidity, false)
	}

	// Check if we reach target or do partial move
	if amountRemainingAbs.Gte(amountOut) {
		// Reach target - validate target price is in bounds
		return sqrtTarget.Gte(MIN_SQRT_RATIO) && sqrtTarget.Lte(MAX_SQRT_RATIO)
	}

	// Partial move - validate next sqrt price calculation
	if zeroForOne {
		return p.validateExactOutZeroForOnePartial(sqrtCurrent, liquidity, amountRemainingAbs)
	}

	return p.validateExactOutOneForZeroPartial(sqrtCurrent, liquidity, amountRemainingAbs)
}

// validateExactOutZeroForOnePartial validates exactOut zeroForOne partial move
func (p *swapMathComputeSwapStepParams) validateExactOutZeroForOnePartial(
	sqrtCurrent, liquidity, amountRemainingAbs *u256.Uint,
) bool {
	// Will call getNextSqrtPriceFromAmount1RoundingDown with add=false (remove)
	// This just subtracts quotient from sqrtCurrent

	max160 := u256.Zero().Lsh(u256.One(), 160)
	var quotient *u256.Uint

	if amountRemainingAbs.Lte(max160) {
		if liquidity.IsZero() {
			return false
		}
		shifted := u256.Zero().Lsh(amountRemainingAbs, 96)
		quotient = u256.Zero().Div(shifted, liquidity)
	} else {
		q96 := u256.Zero().Lsh(u256.One(), 96)
		if liquidity.IsZero() {
			return false
		}
		quotient = u256.MulDiv(amountRemainingAbs, q96, liquidity)
	}

	// Check subtraction underflow
	if sqrtCurrent.Lt(quotient) {
		return false
	}

	sqrtNext := u256.Zero().Sub(sqrtCurrent, quotient)
	return sqrtNext.Gte(MIN_SQRT_RATIO) && sqrtNext.Lte(MAX_SQRT_RATIO)
}

// validateExactOutOneForZeroPartial validates exactOut oneForZero partial move
func (p *swapMathComputeSwapStepParams) validateExactOutOneForZeroPartial(
	sqrtCurrent, liquidity, amountRemainingAbs *u256.Uint,
) bool {
	// Will call getNextSqrtPriceFromAmount0RoundingUp with add=true
	// This calls getNextPriceAmount0Add

	// Check liquidity << 96 won't overflow
	max160 := u256.Zero().Lsh(u256.One(), 160)
	if liquidity.Gte(max160) {
		return false
	}

	liquidityShifted := u256.Zero().Lsh(liquidity, 96)
	amountTimesSqrtPrice := u256.Zero().Mul(amountRemainingAbs, sqrtCurrent)

	// Check multiplication overflow
	if !amountRemainingAbs.IsZero() {
		quotientCheck := u256.Zero().Div(amountTimesSqrtPrice, amountRemainingAbs)
		if !quotientCheck.Eq(sqrtCurrent) {
			// Will use fallback path
			if sqrtCurrent.IsZero() {
				return false
			}
			divValue := u256.Zero().Div(liquidityShifted, sqrtCurrent)
			denominator := u256.Zero().Add(divValue, amountRemainingAbs)
			if denominator.IsZero() {
				return false
			}
			sqrtNext := u256.DivRoundingUp(liquidityShifted, denominator)
			return sqrtNext.Gte(MIN_SQRT_RATIO) && sqrtNext.Lte(MAX_SQRT_RATIO)
		}
	}

	// Fast path - check denominator won't underflow
	denominator := u256.Zero().Add(liquidityShifted, amountTimesSqrtPrice)
	if !denominator.Gte(liquidityShifted) {
		// Will use fallback path
		if sqrtCurrent.IsZero() {
			return false
		}
		divValue := u256.Zero().Div(liquidityShifted, sqrtCurrent)
		denom := u256.Zero().Add(divValue, amountRemainingAbs)
		if denom.IsZero() {
			return false
		}
		sqrtNext := u256.DivRoundingUp(liquidityShifted, denom)
		return sqrtNext.Gte(MIN_SQRT_RATIO) && sqrtNext.Lte(MAX_SQRT_RATIO)
	}

	// Calculate sqrtNext using fast path
	sqrtNext := u256.MulDivRoundingUp(liquidityShifted, sqrtCurrent, denominator)
	return sqrtNext.Gte(MIN_SQRT_RATIO) && sqrtNext.Lte(MAX_SQRT_RATIO)
}

func (p *swapMathComputeSwapStepParams) ToString() string {
	return ufmt.Sprintf(
		"sqrtRatioCurrentX96: %s, sqrtRatioTargetX96: %s, liquidity: %s, amountRemaining: %s, feePips: %d",
		p.sqrtRatioCurrentX96,
		p.sqrtRatioTargetX96,
		p.liquidity,
		p.amountRemaining,
		p.feePips,
	)
}

func NewValidSwapMathComputeSwapStepParams(t *fuzz.T) *swapMathComputeSwapStepParams {
	sqrtCurrent := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtRatioCurrentX96").(*u256.Uint)

	sqrtTarget := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtRatioTargetX96").(*u256.Uint)

	if sqrtCurrent.Gte(MAX_SQRT_RATIO) {
		sqrtCurrent = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}
	if sqrtTarget.Gte(MAX_SQRT_RATIO) {
		sqrtTarget = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}

	liquidityVal := fuzz.Uint64Range(0, 1000000000000000000).Draw(t, "liquidity").(uint64)
	liquidity := u256.NewUint(liquidityVal)

	isExactIn := fuzz.Bool().Draw(t, "isExactIn").(bool)
	var amountRemaining *i256.Int

	if isExactIn {
		amount := fuzz.Uint64Range(1, 1000000000000).Draw(t, "amountRemainingPositive").(uint64)
		amountRemaining = i256.FromUint256(u256.NewUint(amount))
	} else {
		amount := fuzz.Uint64Range(1, 1000000000000).Draw(t, "amountRemainingNegative").(uint64)
		amountRemaining = i256.FromUint256(u256.NewUint(amount))
		amountRemaining = amountRemaining.Neg(amountRemaining)
	}

	standardFees := []uint64{100, 500, 3000, 10000}
	useStandardFee := fuzz.Bool().Draw(t, "useStandardFee").(bool)

	var feePips uint64
	if useStandardFee {
		feeIndex := fuzz.Uint64Range(0, 3).Draw(t, "feeIndex").(uint64)
		feePips = standardFees[feeIndex]
	} else {
		feePips = fuzz.Uint64Range(0, 999_999).Draw(t, "feePips").(uint64)
	}

	return &swapMathComputeSwapStepParams{
		sqrtRatioCurrentX96: sqrtCurrent.ToString(),
		sqrtRatioTargetX96:  sqrtTarget.ToString(),
		liquidity:           liquidity.ToString(),
		amountRemaining:     amountRemaining.ToString(),
		feePips:             feePips,
	}
}

func NewRandomizedSwapMathComputeSwapStepParams(t *fuzz.T) *swapMathComputeSwapStepParams {
	sqrtCurrent := fuzz.Uint256().Draw(t, "sqrtRatioCurrentX96").(*u256.Uint)
	sqrtTarget := fuzz.Uint256().Draw(t, "sqrtRatioTargetX96").(*u256.Uint)
	liquidity := fuzz.Uint256().Draw(t, "liquidity").(*u256.Uint)
	amountRemaining := fuzz.Int256().Draw(t, "amountRemaining").(*i256.Int)
	feePips := fuzz.Uint64Range(0, 2_000_000).Draw(t, "feePips").(uint64)

	return &swapMathComputeSwapStepParams{
		sqrtRatioCurrentX96: sqrtCurrent.ToString(),
		sqrtRatioTargetX96:  sqrtTarget.ToString(),
		liquidity:           liquidity.ToString(),
		amountRemaining:     amountRemaining.ToString(),
		feePips:             feePips,
	}
}
