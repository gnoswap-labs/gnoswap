package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// positionMintParams is the parameters for the Mint fuzzing test
type positionMintParams struct {
	token0Path      string
	token1Path      string
	fee             uint32
	tickLower       int32
	tickUpper       int32
	amount0Desired  string
	amount1Desired  string
	amount0Min      string
	amount1Min      string
	deadline        int64
}

func (p *positionMintParams) IsValid() bool {
	// Token paths must be different and not empty
	if p.token0Path == p.token1Path || p.token0Path == "" || p.token1Path == "" {
		return false
	}

	// Fee must be one of the supported tiers
	validFee := false
	for _, tier := range VALID_FEE_TIERS {
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

	if amount0.IsZero() && amount1.IsZero() {
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

	// Deadline must be in the future (relative to some reference time)
	if p.deadline <= 0 {
		return false
	}

	return true
}

func (p *positionMintParams) ToString() string {
	return ufmt.Sprintf("token0: %s, token1: %s, fee: %d, tickLower: %d, tickUpper: %d, amount0Desired: %s, amount1Desired: %s",
		p.token0Path,
		p.token1Path,
		p.fee,
		p.tickLower,
		p.tickUpper,
		p.amount0Desired,
		p.amount1Desired,
	)
}

func NewValidPositionMintParams(t *fuzz.T) *positionMintParams {
	// Generate valid fee tier
	feeIndex := fuzz.IntRange(0, len(VALID_FEE_TIERS)-1).Draw(t, "feeIndex").(int)
	fee := VALID_FEE_TIERS[feeIndex]

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

	// Generate valid tick range (will be aligned to tick spacing)
	// Use a reasonable range around current price (tick 0)
	tickLowerRaw := fuzz.Int32Range(-1000, -1).Draw(t, "tickLowerRaw").(int32)
	tickUpperRaw := fuzz.Int32Range(1, 1000).Draw(t, "tickUpperRaw").(int32)

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

	return &positionMintParams{
		token0Path:     "gno.land/r/onbloc/bar",
		token1Path:     "gno.land/r/onbloc/foo",
		fee:            fee,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		amount0Desired: ufmt.Sprintf("%d", amount0),
		amount1Desired: ufmt.Sprintf("%d", amount1),
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       fuzz.Int64Range(1700000000, 2000000000).Draw(t, "deadline").(int64),
	}
}

// NewValidPositionMintParamsWithFee creates valid mint params with a specific fee tier
func NewValidPositionMintParamsWithFee(t *fuzz.T, fee uint32) *positionMintParams {
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
	default:
		panic(ufmt.Sprintf("Invalid fee tier: %d", fee))
	}

	// Generate valid tick range (will be aligned to tick spacing)
	// Use a reasonable range around current price (tick 0)
	tickLowerRaw := fuzz.Int32Range(-1000, -1).Draw(t, "tickLowerRaw").(int32)
	tickUpperRaw := fuzz.Int32Range(1, 1000).Draw(t, "tickUpperRaw").(int32)

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

	return &positionMintParams{
		token0Path:     "gno.land/r/onbloc/bar",
		token1Path:     "gno.land/r/onbloc/foo",
		fee:            fee,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		amount0Desired: ufmt.Sprintf("%d", amount0),
		amount1Desired: ufmt.Sprintf("%d", amount1),
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       fuzz.Int64Range(1700000000, 2000000000).Draw(t, "deadline").(int64),
	}
}

func NewRandomizedPositionMintParams(t *fuzz.T) *positionMintParams {
	// Use valid fee tier
	feeIndex := fuzz.IntRange(0, len(VALID_FEE_TIERS)-1).Draw(t, "feeIndex").(int)
	fee := VALID_FEE_TIERS[feeIndex]

	// Generate wider tick range (may be invalid)
	tickLower := fuzz.Int32Range(-10000, 10000).Draw(t, "tickLower").(int32)
	tickUpper := fuzz.Int32Range(-10000, 10000).Draw(t, "tickUpper").(int32)

	// Generate wider range of amounts (may cause issues)
	amount0 := fuzz.Int64Range(1, 1000000000).Draw(t, "amount0").(int64)
	amount1 := fuzz.Int64Range(1, 1000000000).Draw(t, "amount1").(int64)

	return &positionMintParams{
		token0Path:     "gno.land/r/onbloc/bar",
		token1Path:     "gno.land/r/onbloc/foo",
		fee:            fee,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		amount0Desired: ufmt.Sprintf("%d", amount0),
		amount1Desired: ufmt.Sprintf("%d", amount1),
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       fuzz.Int64Range(1700000000, 2000000000).Draw(t, "deadline").(int64),
	}
}

// NewRandomizedPositionMintParamsWithFee creates randomized mint params with a specific fee tier
func NewRandomizedPositionMintParamsWithFee(t *fuzz.T, fee uint32) *positionMintParams {
	// Generate wider tick range (may be invalid)
	tickLower := fuzz.Int32Range(-10000, 10000).Draw(t, "tickLower").(int32)
	tickUpper := fuzz.Int32Range(-10000, 10000).Draw(t, "tickUpper").(int32)

	// Generate wider range of amounts (may cause issues)
	amount0 := fuzz.Int64Range(1, 1000000000).Draw(t, "amount0").(int64)
	amount1 := fuzz.Int64Range(1, 1000000000).Draw(t, "amount1").(int64)

	return &positionMintParams{
		token0Path:     "gno.land/r/onbloc/bar",
		token1Path:     "gno.land/r/onbloc/foo",
		fee:            fee,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		amount0Desired: ufmt.Sprintf("%d", amount0),
		amount1Desired: ufmt.Sprintf("%d", amount1),
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       fuzz.Int64Range(1700000000, 2000000000).Draw(t, "deadline").(int64),
	}
}
