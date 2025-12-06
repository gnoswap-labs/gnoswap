package gnsmath

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

const FUZZ_ITERATIONS = 100

// TestFuzzGetAmount0Delta_ValidParams_Stateless tests GetAmount0Delta with valid parameters
func TestFuzzGetAmount0Delta_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidGetAmount0DeltaParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtA := u256.MustFromDecimal(params.sqrtRatioAX96)
		sqrtB := u256.MustFromDecimal(params.sqrtRatioBX96)
		liquidity := i256.MustFromDecimal(params.liquidity)

		GetAmount0Delta(sqrtA, sqrtB, liquidity)
	})
}

// TestFuzzGetAmount0Delta_RandomizedParams_Stateless tests GetAmount0Delta with randomized parameters
func TestFuzzGetAmount0Delta_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedGetAmount0DeltaParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtA := u256.MustFromDecimal(params.sqrtRatioAX96)
		sqrtB := u256.MustFromDecimal(params.sqrtRatioBX96)
		liquidity := i256.MustFromDecimal(params.liquidity)

		GetAmount0Delta(sqrtA, sqrtB, liquidity)
	})
}

// TestFuzzGetAmount1Delta_ValidParams_Stateless tests GetAmount1Delta with valid parameters
func TestFuzzGetAmount1Delta_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidGetAmount1DeltaParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtA := u256.MustFromDecimal(params.sqrtRatioAX96)
		sqrtB := u256.MustFromDecimal(params.sqrtRatioBX96)
		liquidity := i256.MustFromDecimal(params.liquidity)

		GetAmount1Delta(sqrtA, sqrtB, liquidity)
	})
}

// TestFuzzGetAmount1Delta_RandomizedParams_Stateless tests GetAmount1Delta with randomized parameters
func TestFuzzGetAmount1Delta_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedGetAmount1DeltaParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtA := u256.MustFromDecimal(params.sqrtRatioAX96)
		sqrtB := u256.MustFromDecimal(params.sqrtRatioBX96)
		liquidity := i256.MustFromDecimal(params.liquidity)

		GetAmount1Delta(sqrtA, sqrtB, liquidity)
	})
}

// TestFuzzGetNextPriceAmount0Add_ValidParams_Stateless tests getNextPriceAmount0Add with valid parameters
func TestFuzzGetNextPriceAmount0Add_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidNextPriceAmount0AddParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtPrice := u256.MustFromDecimal(params.currentSqrtPriceX96)
		liquidity := u256.MustFromDecimal(params.liquidity)
		amount := u256.MustFromDecimal(params.amountToAdd)

		getNextPriceAmount0Add(sqrtPrice, liquidity, amount)
	})
}

// TestFuzzGetNextPriceAmount0Add_RandomizedParams_Stateless tests getNextPriceAmount0Add with randomized parameters
func TestFuzzGetNextPriceAmount0Add_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedNextPriceAmount0AddParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtPrice := u256.MustFromDecimal(params.currentSqrtPriceX96)
		liquidity := u256.MustFromDecimal(params.liquidity)
		amount := u256.MustFromDecimal(params.amountToAdd)

		getNextPriceAmount0Add(sqrtPrice, liquidity, amount)
	})
}

// TestFuzzGetNextPriceAmount0Remove_RandomizedParams_Stateless tests getNextPriceAmount0Remove with randomized parameters
func TestFuzzGetNextPriceAmount0Remove_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedNextPriceAmount0RemoveParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtPrice := u256.MustFromDecimal(params.currentSqrtPriceX96)
		liquidity := u256.MustFromDecimal(params.liquidity)
		amount := u256.MustFromDecimal(params.amountToRemove)

		getNextPriceAmount0Remove(sqrtPrice, liquidity, amount)
	})
}

// TestFuzzGetNextPriceAmount1Add_RandomizedParams_Stateless tests getNextPriceAmount1Add with randomized parameters
func TestFuzzGetNextPriceAmount1Add_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedNextPriceAmount1AddParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtPrice := u256.MustFromDecimal(params.sqrtPX96)
		liquidity := u256.MustFromDecimal(params.liquidity)
		amount := u256.MustFromDecimal(params.amount)

		getNextPriceAmount1Add(sqrtPrice, liquidity, amount)
	})
}

// TestFuzzGetNextPriceAmount1Remove_RandomizedParams_Stateless tests getNextPriceAmount1Remove with randomized parameters
func TestFuzzGetNextPriceAmount1Remove_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedNextPriceAmount1RemoveParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtPrice := u256.MustFromDecimal(params.sqrtPX96)
		liquidity := u256.MustFromDecimal(params.liquidity)
		amount := u256.MustFromDecimal(params.amount)

		getNextPriceAmount1Remove(sqrtPrice, liquidity, amount)
	})
}

// TestFuzzGetAmount0DeltaHelper_RandomizedParams_Stateless tests getAmount0DeltaHelper with randomized parameters
func TestFuzzGetAmount0DeltaHelper_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedAmount0DeltaHelperParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtA := u256.MustFromDecimal(params.sqrtRatioAX96)
		sqrtB := u256.MustFromDecimal(params.sqrtRatioBX96)
		liquidity := u256.MustFromDecimal(params.liquidity)

		getAmount0DeltaHelper(sqrtA, sqrtB, liquidity, params.roundUp)
	})
}

// TestFuzzGetAmount1DeltaHelper_RandomizedParams_Stateless tests getAmount1DeltaHelper with randomized parameters
func TestFuzzGetAmount1DeltaHelper_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedAmount1DeltaHelperParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtA := u256.MustFromDecimal(params.sqrtRatioAX96)
		sqrtB := u256.MustFromDecimal(params.sqrtRatioBX96)
		liquidity := u256.MustFromDecimal(params.liquidity)

		getAmount1DeltaHelper(sqrtA, sqrtB, liquidity, params.roundUp)
	})
}
