package fuzz

import (
	"math"
	"strconv"
	"time"

	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
)

// positionMintParams is the parameters for the Mint fuzzing test
type positionMintParams struct {
	token0Path     string
	token1Path     string
	fee            uint32
	tickLower      int32
	tickUpper      int32
	amount0Desired string
	amount1Desired string
	amount0Min     string
	amount1Min     string
	deadline       int64
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

	// Min amounts must be parseable and non-negative
	amount0Min, err0Min := strconv.ParseInt(p.amount0Min, 10, 64)
	amount1Min, err1Min := strconv.ParseInt(p.amount1Min, 10, 64)
	if err0Min != nil || err1Min != nil {
		return false
	}

	if amount0Min < 0 || amount1Min < 0 {
		return false
	}

	// Amounts must be parseable and non-negative
	amount0, err0 := strconv.ParseInt(p.amount0Desired, 10, 64)
	amount1, err1 := strconv.ParseInt(p.amount1Desired, 10, 64)
	if err0 != nil || err1 != nil {
		return false
	}
	if amount0 < 0 || amount1 < 0 {
		return false
	}

	// Both amounts must be non-zero to avoid zero liquidity issues
	// When one amount is 0, depending on the tick range and current price,
	// it can result in zero liquidity which is invalid
	if amount0 == 0 || amount1 == 0 {
		return false
	}

	// Prevent token mint overflow
	const maxSafeAmount = math.MaxInt64 / 1000
	if amount0 > maxSafeAmount || amount1 > maxSafeAmount {
		return false
	}

	if amount0Min > amount0 || amount1Min > amount1 {
		return false
	}

	// Deadline must be in the future (relative to some reference time)
	if p.deadline < time.Now().Unix() {
		return false
	}

	poolPath := pool.GetPoolPath(p.token0Path, p.token1Path, p.fee)
	exists := pool.ExistsPoolPath(poolPath)
	if !exists {
		return false
	}

	// Simulate actual liquidity calculation to detect overflows
	if !p.canCalculateLiquidityWithoutPanic(poolPath) {
		return false
	}

	return true
}

// canCalculateLiquidityWithoutPanic attempts to calculate liquidity and returns false if it panics
func (p *positionMintParams) canCalculateLiquidityWithoutPanic(poolPath string) (success bool) {
	defer func() {
		if r := recover(); r != nil {
			// Panic occurred during liquidity calculation (likely overflow)
			success = false
		}
	}()

	sqrtPriceX96 := pool.GetSlot0SqrtPriceX96(poolPath)
	sqrtRatioAX96 := common.TickMathGetSqrtRatioAtTick(p.tickLower)
	sqrtRatioBX96 := common.TickMathGetSqrtRatioAtTick(p.tickUpper)

	amount0U256 := u256.MustFromDecimal(p.amount0Desired)
	amount1U256 := u256.MustFromDecimal(p.amount1Desired)

	liquidity := common.GetLiquidityForAmounts(
		sqrtPriceX96,
		sqrtRatioAX96,
		sqrtRatioBX96,
		amount0U256,
		amount1U256,
	)

	// Zero liquidity is invalid
	if liquidity.IsZero() {
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
func NewValidPositionMintParamsWithFee(t *fuzz.T) *positionMintParams {
	token0Path, token1Path := generateTokenPair(t)
	fee := generateFeeTier(t)
	tickLower, tickUpper := generateRandomTicks(t, 0, fee)

	// Generate valid amounts
	amount0 := fuzz.Int64Range(0, math.MaxInt64).Draw(t, "amount0").(int64)
	amount1 := fuzz.Int64Range(0, math.MaxInt64).Draw(t, "amount1").(int64)

	deadline := fuzz.Int64Range(time.Now().Unix(), math.MaxInt64).Draw(t, "deadline").(int64)

	return &positionMintParams{
		token0Path:     token0Path,
		token1Path:     token1Path,
		fee:            fee,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		amount0Desired: ufmt.Sprintf("%d", amount0),
		amount1Desired: ufmt.Sprintf("%d", amount1),
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       deadline,
	}
}

func NewRandomizedPositionMintParams(t *fuzz.T) *positionMintParams {
	token0Path, token1Path := generateTokenPair(t)
	fee := generateFeeTier(t)
	tickLower, tickUpper := generateRandomTicks(t, 0, fee)

	// Generate valid amounts
	amount0 := fuzz.Int64Range(math.MinInt64, math.MaxInt64).Draw(t, "amount0").(int64)
	amount1 := fuzz.Int64Range(math.MinInt64, math.MaxInt64).Draw(t, "amount1").(int64)

	deadline := fuzz.Int64Range(time.Now().Unix(), math.MaxInt64).Draw(t, "deadline").(int64)

	return &positionMintParams{
		token0Path:     token0Path,
		token1Path:     token1Path,
		fee:            fee,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		amount0Desired: ufmt.Sprintf("%d", amount0),
		amount1Desired: ufmt.Sprintf("%d", amount1),
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       deadline,
	}
}
