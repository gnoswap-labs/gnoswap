package fuzz

import (
	"math"

	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// positionRepositionParams is the parameters for Reposition fuzzing test
type positionRepositionParams struct {
	positionId     uint64
	fee            uint32
	tickLower      int32
	tickUpper      int32
	amount0Desired string
	amount1Desired string
	amount0Min     string
	amount1Min     string
}

func (p *positionRepositionParams) IsValid() bool {
	// Position ID must be non-zero
	if p.positionId == 0 {
		return false
	}

	// Fee must be one of the supported tiers
	validFee := false
	for _, tier := range []uint32{100, 500, 3000, 10000} {
		if p.fee == tier {
			validFee = true
			break
		}
	}
	if !validFee {
		return false
	}

	// Tick range must be valid
	if p.tickLower >= p.tickUpper {
		return false
	}

	// Verify tick spacing based on fee tier
	var tickSpacing int32
	switch p.fee {
	case 100:
		tickSpacing = 1
	case 500:
		tickSpacing = 10
	case 3000:
		tickSpacing = 60
	case 10000:
		tickSpacing = 200
	default:
		return false
	}

	// Ticks must be aligned to tick spacing
	if p.tickLower%tickSpacing != 0 || p.tickUpper%tickSpacing != 0 {
		return false
	}

	// Tick range must be at least one tick spacing
	if p.tickUpper-p.tickLower < tickSpacing {
		return false
	}

	// Amounts must be parseable and non-negative
	amount0, err0 := u256.FromDecimal(p.amount0Desired)
	amount1, err1 := u256.FromDecimal(p.amount1Desired)
	if err0 != nil || err1 != nil {
		return false
	}
	if amount0.Lt(u256.Zero()) || amount1.Lt(u256.Zero()) {
		return false
	}

	// Both amounts must be non-zero to avoid zero liquidity issues
	if amount0.IsZero() || amount1.IsZero() {
		return false
	}

	// Prevent token mint overflow in stateful tests
	maxSafeAmount := u256.NewUint(uint64(math.MaxInt64 / 1000))
	if amount0.Gt(maxSafeAmount) || amount1.Gt(maxSafeAmount) {
		return false
	}

	// Min amounts must be parseable and non-negative
	amount0Min, err0Min := u256.FromDecimal(p.amount0Min)
	amount1Min, err1Min := u256.FromDecimal(p.amount1Min)
	if err0Min != nil || err1Min != nil {
		return false
	}
	if amount0Min.Lt(u256.Zero()) || amount1Min.Lt(u256.Zero()) {
		return false
	}

	// Min amounts must not exceed desired amounts
	if amount0Min.Gt(amount0) || amount1Min.Gt(amount1) {
		return false
	}

	return true
}

func (p *positionRepositionParams) ToString() string {
	return ufmt.Sprintf("positionId: %d, tickLower: %d, tickUpper: %d, amount0Desired: %s, amount1Desired: %s",
		p.positionId,
		p.tickLower,
		p.tickUpper,
		p.amount0Desired,
		p.amount1Desired,
	)
}

func NewValidPositionRepositionParams(t *fuzz.T, existingPositionId uint64, fee uint32) *positionRepositionParams {
	// Calculate tick spacing based on fee tier
	var tickSpacing int32
	switch fee {
	case 100:
		tickSpacing = 1
	case 500:
		tickSpacing = 10
	case 3000:
		tickSpacing = 60
	case 10000:
		tickSpacing = 200
	}

	// Generate new tick range (different from original)
	tickLowerRaw := fuzz.Int32Range(-2000, -100).Draw(t, "tickLowerRaw").(int32)
	tickUpperRaw := fuzz.Int32Range(100, 2000).Draw(t, "tickUpperRaw").(int32)

	// Align to tick spacing
	tickLower := (tickLowerRaw / tickSpacing) * tickSpacing
	tickUpper := (tickUpperRaw / tickSpacing) * tickSpacing

	// Ensure tickLower < tickUpper and at least one spacing apart
	if tickLower >= tickUpper {
		tickUpper = tickLower + tickSpacing
	}

	// Generate valid amounts
	amount0 := fuzz.Int64Range(1000000, 100000000).Draw(t, "amount0").(int64)
	amount1 := fuzz.Int64Range(1000000, 100000000).Draw(t, "amount1").(int64)

	return &positionRepositionParams{
		positionId:     existingPositionId,
		fee:            fee,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		amount0Desired: ufmt.Sprintf("%d", amount0),
		amount1Desired: ufmt.Sprintf("%d", amount1),
		amount0Min:     "0",
		amount1Min:     "0",
	}
}

func NewRandomizedPositionRepositionParams(t *fuzz.T, existingPositionId uint64) *positionRepositionParams {
	// Generate random fee - full range to test edge cases
	fee := fuzz.Uint32Range(0, math.MaxUint32).Draw(t, "fee").(uint32)

	// Generate full tick range - to test invalid ticks
	tickLower := fuzz.Int32Range(math.MinInt32, math.MaxInt32).Draw(t, "tickLower").(int32)
	tickUpper := fuzz.Int32Range(math.MinInt32, math.MaxInt32).Draw(t, "tickUpper").(int32)

	// Generate randomized amounts - full range to test edge cases
	amount0 := fuzz.Int64Range(math.MinInt64, math.MaxInt64).Draw(t, "amount0").(int64)
	amount1 := fuzz.Int64Range(math.MinInt64, math.MaxInt64).Draw(t, "amount1").(int64)

	return &positionRepositionParams{
		positionId:     existingPositionId,
		fee:            fee,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		amount0Desired: ufmt.Sprintf("%d", amount0),
		amount1Desired: ufmt.Sprintf("%d", amount1),
		amount0Min:     "0",
		amount1Min:     "0",
	}
}
