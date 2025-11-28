package gnsmath

import (
	"gno.land/p/gnoswap/fuzz"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// Parameters for GetAmount0Delta fuzzing test
type getAmount0DeltaParams struct {
	sqrtRatioAX96 string
	sqrtRatioBX96 string
	liquidity     string
}

func (p *getAmount0DeltaParams) IsValid() bool {
	// Parse parameters
	sqrtA := u256.MustFromDecimal(p.sqrtRatioAX96)
	sqrtB := u256.MustFromDecimal(p.sqrtRatioBX96)
	liquidity := i256.MustFromDecimal(p.liquidity)

	// getAmount0DeltaHelper will swap if sqrtA > sqrtB
	if sqrtA.Gt(sqrtB) {
		sqrtA, sqrtB = sqrtB, sqrtA
	}

	// Check: sqrtRatioAX96 cannot be zero (panic in helper line 216-217)
	if sqrtA.IsZero() {
		return false
	}

	// Check: Lsh overflow - liquidity << 96 must not overflow
	// This happens when liquidity.Abs() > 2^160 (because 2^160 << 96 = 2^256 which overflows)
	liquidityAbs := liquidity.Abs()
	max160 := u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 160), u256.One())
	if liquidityAbs.Gt(max160) {
		return false
	}

	return true
}

func (p *getAmount0DeltaParams) ToString() string {
	return ufmt.Sprintf(
		"sqrtRatioAX96: %s, sqrtRatioBX96: %s, liquidity: %s",
		p.sqrtRatioAX96,
		p.sqrtRatioBX96,
		p.liquidity,
	)
}

func NewValidGetAmount0DeltaParams(t *fuzz.T) *getAmount0DeltaParams {
	// Generate valid sqrt ratios within range
	sqrtA := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtRatioAX96").(*u256.Uint)

	sqrtB := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtRatioBX96").(*u256.Uint)

	// Ensure sqrtA is not zero (division by zero)
	if sqrtA.IsZero() {
		sqrtA = u256.NewUint(1)
	}
	if sqrtA.Gte(MAX_SQRT_RATIO) {
		sqrtA = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}
	if sqrtB.Gte(MAX_SQRT_RATIO) {
		sqrtB = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}

	// Generate valid liquidity (both positive and negative)
	isNegative := fuzz.Bool().Draw(t, "isNegative").(bool)
	liquidityVal := fuzz.Uint64Range(0, 1000000000000000000).Draw(t, "liquidityVal").(uint64)
	liquidityUint := u256.NewUint(liquidityVal)
	liquidity := i256.FromUint256(liquidityUint)

	if isNegative {
		liquidity = liquidity.Neg(liquidity)
	}

	return &getAmount0DeltaParams{
		sqrtRatioAX96: sqrtA.ToString(),
		sqrtRatioBX96: sqrtB.ToString(),
		liquidity:     liquidity.ToString(),
	}
}

func NewRandomizedGetAmount0DeltaParams(t *fuzz.T) *getAmount0DeltaParams {
	// Generate completely random values (may be out of range)
	sqrtA := fuzz.Uint256().Draw(t, "sqrtRatioAX96").(*u256.Uint)
	sqrtB := fuzz.Uint256().Draw(t, "sqrtRatioBX96").(*u256.Uint)
	liquidity := fuzz.Int256().Draw(t, "liquidity").(*i256.Int)

	return &getAmount0DeltaParams{
		sqrtRatioAX96: sqrtA.ToString(),
		sqrtRatioBX96: sqrtB.ToString(),
		liquidity:     liquidity.ToString(),
	}
}

// Parameters for GetAmount1Delta fuzzing test
type getAmount1DeltaParams struct {
	sqrtRatioAX96 string
	sqrtRatioBX96 string
	liquidity     string
}

func (p *getAmount1DeltaParams) IsValid() bool {
	// Parse parameters
	sqrtA := u256.MustFromDecimal(p.sqrtRatioAX96)
	sqrtB := u256.MustFromDecimal(p.sqrtRatioBX96)
	liquidity := i256.MustFromDecimal(p.liquidity)

	liquidityAbs := liquidity.Abs()

	// getAmount1DeltaHelper will swap if sqrtA > sqrtB
	if sqrtA.Gt(sqrtB) {
		sqrtA, sqrtB = sqrtB, sqrtA
	}

	difference := u256.Zero().Sub(sqrtB, sqrtA)

	// Check: MulDiv overflow in getAmount1DeltaHelper
	// MulDiv calculates: (liquidity * difference) / q96
	// For this to not overflow: liquidity * difference < 2^256
	if !difference.IsZero() {
		max256 := u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 256), u256.One())
		maxLiquidity := u256.Zero().Div(max256, difference)
		if liquidityAbs.Gt(maxLiquidity) {
			return false
		}
	}

	return true
}

func (p *getAmount1DeltaParams) ToString() string {
	return ufmt.Sprintf(
		"sqrtRatioAX96: %s, sqrtRatioBX96: %s, liquidity: %s",
		p.sqrtRatioAX96,
		p.sqrtRatioBX96,
		p.liquidity,
	)
}

func NewValidGetAmount1DeltaParams(t *fuzz.T) *getAmount1DeltaParams {
	// Generate valid sqrt ratios within range
	sqrtA := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtRatioAX96").(*u256.Uint)

	sqrtB := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtRatioBX96").(*u256.Uint)

	// Ensure within bounds
	if sqrtA.Gte(MAX_SQRT_RATIO) {
		sqrtA = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}
	if sqrtB.Gte(MAX_SQRT_RATIO) {
		sqrtB = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}

	// Generate valid liquidity (both positive and negative)
	isNegative := fuzz.Bool().Draw(t, "isNegative").(bool)
	liquidityVal := fuzz.Uint64Range(0, 1000000000000000000).Draw(t, "liquidityVal").(uint64)
	liquidityUint := u256.NewUint(liquidityVal)
	liquidity := i256.FromUint256(liquidityUint)

	if isNegative {
		liquidity = liquidity.Neg(liquidity)
	}

	return &getAmount1DeltaParams{
		sqrtRatioAX96: sqrtA.ToString(),
		sqrtRatioBX96: sqrtB.ToString(),
		liquidity:     liquidity.ToString(),
	}
}

func NewRandomizedGetAmount1DeltaParams(t *fuzz.T) *getAmount1DeltaParams {
	// Generate completely random values (may be out of range)
	sqrtA := fuzz.Uint256().Draw(t, "sqrtRatioAX96").(*u256.Uint)
	sqrtB := fuzz.Uint256().Draw(t, "sqrtRatioBX96").(*u256.Uint)
	liquidity := fuzz.Int256().Draw(t, "liquidity").(*i256.Int)

	return &getAmount1DeltaParams{
		sqrtRatioAX96: sqrtA.ToString(),
		sqrtRatioBX96: sqrtB.ToString(),
		liquidity:     liquidity.ToString(),
	}
}

// Parameters for getNextPriceAmount0Add fuzzing test
type nextPriceAmount0AddParams struct {
	currentSqrtPriceX96 string
	liquidity           string
	amountToAdd         string
}

func (p *nextPriceAmount0AddParams) IsValid() bool {
	currentSqrt := u256.MustFromDecimal(p.currentSqrtPriceX96)
	liquidity := u256.MustFromDecimal(p.liquidity)
	amount := u256.MustFromDecimal(p.amountToAdd)

	max160 := u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 160), u256.One())
	if liquidity.Gt(max160) {
		return false
	}

	if amount.IsZero() {
		liquidityShifted := u256.Zero().Lsh(liquidity, 96)
		if liquidityShifted.Lte(currentSqrt) {
			return false
		}
	}

	return true
}

func (p *nextPriceAmount0AddParams) ToString() string {
	return ufmt.Sprintf(
		"currentSqrtPriceX96: %s, liquidity: %s, amountToAdd: %s",
		p.currentSqrtPriceX96,
		p.liquidity,
		p.amountToAdd,
	)
}

func NewValidNextPriceAmount0AddParams(t *fuzz.T) *nextPriceAmount0AddParams {
	currentSqrt := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "currentSqrtPriceX96").(*u256.Uint)

	if currentSqrt.Gte(MAX_SQRT_RATIO) {
		currentSqrt = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}

	liquidityVal := fuzz.Uint64Range(1, 1000000000000000000).Draw(t, "liquidity").(uint64)
	liquidity := u256.NewUint(liquidityVal)

	amountVal := fuzz.Uint64Range(0, 1000000000000).Draw(t, "amountToAdd").(uint64)
	amount := u256.NewUint(amountVal)

	return &nextPriceAmount0AddParams{
		currentSqrtPriceX96: currentSqrt.ToString(),
		liquidity:           liquidity.ToString(),
		amountToAdd:         amount.ToString(),
	}
}

func NewRandomizedNextPriceAmount0AddParams(t *fuzz.T) *nextPriceAmount0AddParams {
	currentSqrt := fuzz.Uint256().Draw(t, "currentSqrtPriceX96").(*u256.Uint)
	liquidity := fuzz.Uint256().Draw(t, "liquidity").(*u256.Uint)
	amount := fuzz.Uint256().Draw(t, "amountToAdd").(*u256.Uint)

	return &nextPriceAmount0AddParams{
		currentSqrtPriceX96: currentSqrt.ToString(),
		liquidity:           liquidity.ToString(),
		amountToAdd:         amount.ToString(),
	}
}

// Parameters for getNextPriceAmount0Remove fuzzing test
type nextPriceAmount0RemoveParams struct {
	currentSqrtPriceX96 string
	liquidity           string
	amountToRemove      string
}

func (p *nextPriceAmount0RemoveParams) IsValid() bool {
	currentSqrt := u256.MustFromDecimal(p.currentSqrtPriceX96)
	liquidity := u256.MustFromDecimal(p.liquidity)
	amount := u256.MustFromDecimal(p.amountToRemove)

	// Check: Lsh overflow - liquidity << 96 must not overflow (line 58)
	max160 := u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 160), u256.One())
	if liquidity.Gt(max160) {
		return false
	}

	// Check: amountToRemove cannot be zero (line 63: division by zero in quotientCheck)
	if amount.IsZero() {
		return false
	}

	// Check: liquidityShifted > amountTimesSqrtPrice (line 64)
	liquidityShifted := u256.Zero().Lsh(liquidity, Q96_RESOLUTION)
	amountTimesSqrtPrice := u256.Zero().Mul(amount, currentSqrt)

	quotientCheck := u256.Zero().Div(amountTimesSqrtPrice, amount)

	if !quotientCheck.Eq(currentSqrt) || !liquidityShifted.Gt(amountTimesSqrtPrice) {
		return false
	}

	return true
}

func (p *nextPriceAmount0RemoveParams) ToString() string {
	return ufmt.Sprintf(
		"currentSqrtPriceX96: %s, liquidity: %s, amountToRemove: %s",
		p.currentSqrtPriceX96,
		p.liquidity,
		p.amountToRemove,
	)
}

func NewValidNextPriceAmount0RemoveParams(t *fuzz.T) *nextPriceAmount0RemoveParams {
	currentSqrt := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "currentSqrtPriceX96").(*u256.Uint)

	if currentSqrt.Gte(MAX_SQRT_RATIO) {
		currentSqrt = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}

	liquidityVal := fuzz.Uint64Range(1000000, 1000000000000000000).Draw(t, "liquidity").(uint64)
	liquidity := u256.NewUint(liquidityVal)

	// amountToRemove should be small enough to satisfy liquidityShifted > amountTimesSqrtPrice
	amountVal := fuzz.Uint64Range(1, 100000).Draw(t, "amountToRemove").(uint64)
	amount := u256.NewUint(amountVal)

	return &nextPriceAmount0RemoveParams{
		currentSqrtPriceX96: currentSqrt.ToString(),
		liquidity:           liquidity.ToString(),
		amountToRemove:      amount.ToString(),
	}
}

func NewRandomizedNextPriceAmount0RemoveParams(t *fuzz.T) *nextPriceAmount0RemoveParams {
	currentSqrt := fuzz.Uint256().Draw(t, "currentSqrtPriceX96").(*u256.Uint)
	liquidity := fuzz.Uint256().Draw(t, "liquidity").(*u256.Uint)
	amount := fuzz.Uint256().Draw(t, "amountToRemove").(*u256.Uint)

	return &nextPriceAmount0RemoveParams{
		currentSqrtPriceX96: currentSqrt.ToString(),
		liquidity:           liquidity.ToString(),
		amountToRemove:      amount.ToString(),
	}
}

// Parameters for getNextPriceAmount1Add fuzzing test
type nextPriceAmount1AddParams struct {
	sqrtPX96  string
	liquidity string
	amount    string
}

func (p *nextPriceAmount1AddParams) IsValid() bool {
	amount := u256.MustFromDecimal(p.amount)
	liquidity := u256.MustFromDecimal(p.liquidity)

	if liquidity.IsZero() {
		return false
	}

	max160 := u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 160), u256.One())
	if !amount.Lte(max160) {
		if !liquidity.IsZero() {
			q96 := u256.Zero().Lsh(u256.One(), Q96_RESOLUTION)
			max256 := u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 256), u256.One())
			maxAmount := u256.Zero().Div(max256, q96)

			if amount.Gt(maxAmount) {
				return false
			}
		}
	}

	return true
}

func (p *nextPriceAmount1AddParams) ToString() string {
	return ufmt.Sprintf(
		"sqrtPX96: %s, liquidity: %s, amount: %s",
		p.sqrtPX96,
		p.liquidity,
		p.amount,
	)
}

func NewValidNextPriceAmount1AddParams(t *fuzz.T) *nextPriceAmount1AddParams {
	sqrtP := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtPX96").(*u256.Uint)

	if sqrtP.Gte(MAX_SQRT_RATIO) {
		sqrtP = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}

	liquidityVal := fuzz.Uint64Range(1, 1000000000000000000).Draw(t, "liquidity").(uint64)
	liquidity := u256.NewUint(liquidityVal)

	amountVal := fuzz.Uint64Range(0, 1000000000000).Draw(t, "amount").(uint64)
	amount := u256.NewUint(amountVal)

	return &nextPriceAmount1AddParams{
		sqrtPX96:  sqrtP.ToString(),
		liquidity: liquidity.ToString(),
		amount:    amount.ToString(),
	}
}

func NewRandomizedNextPriceAmount1AddParams(t *fuzz.T) *nextPriceAmount1AddParams {
	sqrtP := fuzz.Uint256().Draw(t, "sqrtPX96").(*u256.Uint)
	liquidity := fuzz.Uint256().Draw(t, "liquidity").(*u256.Uint)
	amount := fuzz.Uint256().Draw(t, "amount").(*u256.Uint)

	return &nextPriceAmount1AddParams{
		sqrtPX96:  sqrtP.ToString(),
		liquidity: liquidity.ToString(),
		amount:    amount.ToString(),
	}
}

// Parameters for getNextPriceAmount1Remove fuzzing test
type nextPriceAmount1RemoveParams struct {
	sqrtPX96  string
	liquidity string
	amount    string
}

func (p *nextPriceAmount1RemoveParams) IsValid() bool {
	liquidity := u256.MustFromDecimal(p.liquidity)
	amount := u256.MustFromDecimal(p.amount)
	sqrtP := u256.MustFromDecimal(p.sqrtPX96)

	// Check for zero liquidity to avoid division by zero
	if liquidity.IsZero() {
		return false
	}

	// Check: Lsh overflow when amount <= max160 (line 121)
	max160 := u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 160), u256.One())
	var quotient *u256.Uint
	q96 := u256.Zero().Lsh(u256.One(), 96)

	if amount.Lte(max160) {
		shifted := u256.Zero().Lsh(amount, Q96_RESOLUTION)
		quotient = u256.DivRoundingUp(shifted, liquidity)
	} else {
		quotient = u256.MulDivRoundingUp(amount, q96, liquidity)
	}

	// Check: sqrtP > quotient (panic condition in line 127-129)
	if !sqrtP.Gt(quotient) {
		return false
	}

	return true
}

func (p *nextPriceAmount1RemoveParams) ToString() string {
	return ufmt.Sprintf(
		"sqrtPX96: %s, liquidity: %s, amount: %s",
		p.sqrtPX96,
		p.liquidity,
		p.amount,
	)
}

func NewValidNextPriceAmount1RemoveParams(t *fuzz.T) *nextPriceAmount1RemoveParams {
	sqrtP := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtPX96").(*u256.Uint)

	if sqrtP.Gte(MAX_SQRT_RATIO) {
		sqrtP = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}

	liquidityVal := fuzz.Uint64Range(1000000, 1000000000000000000).Draw(t, "liquidity").(uint64)
	liquidity := u256.NewUint(liquidityVal)

	// amount should be small enough to satisfy sqrtP > quotient
	amountVal := fuzz.Uint64Range(1, 100000).Draw(t, "amount").(uint64)
	amount := u256.NewUint(amountVal)

	return &nextPriceAmount1RemoveParams{
		sqrtPX96:  sqrtP.ToString(),
		liquidity: liquidity.ToString(),
		amount:    amount.ToString(),
	}
}

func NewRandomizedNextPriceAmount1RemoveParams(t *fuzz.T) *nextPriceAmount1RemoveParams {
	sqrtP := fuzz.Uint256().Draw(t, "sqrtPX96").(*u256.Uint)
	liquidity := fuzz.Uint256().Draw(t, "liquidity").(*u256.Uint)
	amount := fuzz.Uint256().Draw(t, "amount").(*u256.Uint)

	return &nextPriceAmount1RemoveParams{
		sqrtPX96:  sqrtP.ToString(),
		liquidity: liquidity.ToString(),
		amount:    amount.ToString(),
	}
}

// Parameters for getAmount0DeltaHelper fuzzing test
type amount0DeltaHelperParams struct {
	sqrtRatioAX96 string
	sqrtRatioBX96 string
	liquidity     string
	roundUp       bool
}

func (p *amount0DeltaHelperParams) IsValid() bool {
	sqrtA := u256.MustFromDecimal(p.sqrtRatioAX96)
	sqrtB := u256.MustFromDecimal(p.sqrtRatioBX96)
	liquidity := u256.MustFromDecimal(p.liquidity)

	// getAmount0DeltaHelper will swap if sqrtA > sqrtB
	if sqrtA.Gt(sqrtB) {
		sqrtA, sqrtB = sqrtB, sqrtA
	}

	// Check: sqrtRatioAX96 cannot be zero (panic in helper line 216-217)
	if sqrtA.IsZero() {
		return false
	}

	// Check: Lsh overflow - liquidity << 96 must not overflow (line 213)
	max160 := u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 160), u256.One())
	if liquidity.Gt(max160) {
		return false
	}

	return true
}

func (p *amount0DeltaHelperParams) ToString() string {
	return ufmt.Sprintf(
		"sqrtRatioAX96: %s, sqrtRatioBX96: %s, liquidity: %s, roundUp: %t",
		p.sqrtRatioAX96,
		p.sqrtRatioBX96,
		p.liquidity,
		p.roundUp,
	)
}

func NewValidAmount0DeltaHelperParams(t *fuzz.T) *amount0DeltaHelperParams {
	sqrtA := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtRatioAX96").(*u256.Uint)

	sqrtB := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtRatioBX96").(*u256.Uint)

	if sqrtA.IsZero() {
		sqrtA = u256.NewUint(1)
	}
	if sqrtB.IsZero() {
		sqrtB = u256.NewUint(1)
	}
	if sqrtA.Gte(MAX_SQRT_RATIO) {
		sqrtA = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}
	if sqrtB.Gte(MAX_SQRT_RATIO) {
		sqrtB = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}

	liquidityVal := fuzz.Uint64Range(0, 1000000000000000000).Draw(t, "liquidity").(uint64)
	liquidity := u256.NewUint(liquidityVal)

	roundUp := fuzz.Bool().Draw(t, "roundUp").(bool)

	return &amount0DeltaHelperParams{
		sqrtRatioAX96: sqrtA.ToString(),
		sqrtRatioBX96: sqrtB.ToString(),
		liquidity:     liquidity.ToString(),
		roundUp:       roundUp,
	}
}

func NewRandomizedAmount0DeltaHelperParams(t *fuzz.T) *amount0DeltaHelperParams {
	sqrtA := fuzz.Uint256().Draw(t, "sqrtRatioAX96").(*u256.Uint)
	sqrtB := fuzz.Uint256().Draw(t, "sqrtRatioBX96").(*u256.Uint)
	liquidity := fuzz.Uint256().Draw(t, "liquidity").(*u256.Uint)
	roundUp := fuzz.Bool().Draw(t, "roundUp").(bool)

	return &amount0DeltaHelperParams{
		sqrtRatioAX96: sqrtA.ToString(),
		sqrtRatioBX96: sqrtB.ToString(),
		liquidity:     liquidity.ToString(),
		roundUp:       roundUp,
	}
}

// Parameters for getAmount1DeltaHelper fuzzing test
type amount1DeltaHelperParams struct {
	sqrtRatioAX96 string
	sqrtRatioBX96 string
	liquidity     string
	roundUp       bool
}

func (p *amount1DeltaHelperParams) IsValid() bool {
	sqrtA := u256.MustFromDecimal(p.sqrtRatioAX96)
	sqrtB := u256.MustFromDecimal(p.sqrtRatioBX96)
	liquidity := u256.MustFromDecimal(p.liquidity)

	// getAmount1DeltaHelper will swap if sqrtA > sqrtB
	if sqrtA.Gt(sqrtB) {
		sqrtA, sqrtB = sqrtB, sqrtA
	}

	difference := u256.Zero().Sub(sqrtB, sqrtA)

	// Check: MulDiv overflow in line 245 or 248
	// MulDiv calculates: (liquidity * difference) / q96
	// For this to not overflow: liquidity * difference < 2^256
	// Check if multiplication would overflow by testing: liquidity < 2^256 / difference
	// To avoid division by zero, skip if difference is zero
	if !difference.IsZero() {
		max256 := u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 256), u256.One())
		maxLiquidity := u256.Zero().Div(max256, difference)
		if liquidity.Gt(maxLiquidity) {
			return false
		}
	}

	return true
}

func (p *amount1DeltaHelperParams) ToString() string {
	return ufmt.Sprintf(
		"sqrtRatioAX96: %s, sqrtRatioBX96: %s, liquidity: %s, roundUp: %t",
		p.sqrtRatioAX96,
		p.sqrtRatioBX96,
		p.liquidity,
		p.roundUp,
	)
}

func NewValidAmount1DeltaHelperParams(t *fuzz.T) *amount1DeltaHelperParams {
	sqrtA := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtRatioAX96").(*u256.Uint)

	sqrtB := fuzz.Uint256Range(
		MIN_SQRT_RATIO.ToString(),
		MAX_SQRT_RATIO.ToString(),
	).Draw(t, "sqrtRatioBX96").(*u256.Uint)

	if sqrtA.Gte(MAX_SQRT_RATIO) {
		sqrtA = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}
	if sqrtB.Gte(MAX_SQRT_RATIO) {
		sqrtB = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One())
	}

	liquidityVal := fuzz.Uint64Range(0, 1000000000000000000).Draw(t, "liquidity").(uint64)
	liquidity := u256.NewUint(liquidityVal)

	roundUp := fuzz.Bool().Draw(t, "roundUp").(bool)

	return &amount1DeltaHelperParams{
		sqrtRatioAX96: sqrtA.ToString(),
		sqrtRatioBX96: sqrtB.ToString(),
		liquidity:     liquidity.ToString(),
		roundUp:       roundUp,
	}
}

func NewRandomizedAmount1DeltaHelperParams(t *fuzz.T) *amount1DeltaHelperParams {
	sqrtA := fuzz.Uint256().Draw(t, "sqrtRatioAX96").(*u256.Uint)
	sqrtB := fuzz.Uint256().Draw(t, "sqrtRatioBX96").(*u256.Uint)
	liquidity := fuzz.Uint256().Draw(t, "liquidity").(*u256.Uint)
	roundUp := fuzz.Bool().Draw(t, "roundUp").(bool)

	return &amount1DeltaHelperParams{
		sqrtRatioAX96: sqrtA.ToString(),
		sqrtRatioBX96: sqrtB.ToString(),
		liquidity:     liquidity.ToString(),
		roundUp:       roundUp,
	}
}
