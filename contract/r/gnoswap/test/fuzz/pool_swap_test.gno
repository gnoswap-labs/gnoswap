package fuzz

import (
	"math"
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
)

// TestFuzzPoolSwap_ValidParams_Stateless tests DrySwap and Swap with valid parameters
func TestFuzzPoolSwap_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		initStates(t)

		params := NewValidPoolSwapParams(ft)

		setupIterations := 25
		for i := 0; i < setupIterations; i++ {
			setupPoolSwapLiquidity(ft, params)
		}

		// Mint random amount of tokens for admin
		// This creates scenarios where balance may be insufficient
		swapAmount := fuzz.Int64Range(1, 100_000_000_000).Draw(ft, "swapAmount").(int64)
		mintTestToken(params.token0Path, swapAmount)
		mintTestToken(params.token1Path, swapAmount)

		params.setPriceLimit(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		runTestPoolSwap(ft, params)
	})
}

// TestFuzzPoolSwap_RandomizedParams_Stateless tests DrySwap and Swap with randomized parameters
func TestFuzzPoolSwap_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		initStates(t)

		params := NewRandomizedPoolSwapParams(ft)

		setupIterations := fuzz.IntRange(1, 10).Draw(ft, "setupIterations").(int)
		for i := 0; i < setupIterations; i++ {
			setupPoolSwapLiquidity(ft, params)
		}

		// Mint random amount of tokens for admin
		// This creates scenarios where balance may be insufficient
		swapAmount := fuzz.Int64Range(1, 100_000_000_000).Draw(ft, "swapAmount").(int64)
		mintTestToken(params.token0Path, swapAmount)
		mintTestToken(params.token1Path, swapAmount)

		params.setPriceLimit(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		runTestPoolSwap(ft, params)
	})
}

// TestFuzzPoolSwap_RandomizedParams_Stateful tests DrySwap and Swap with randomized parameters in stateful mode
func TestFuzzPoolSwap_RandomizedParams_Stateful(t *testing.T) {
	// given
	initStates(t)

	// Mint large amount of tokens for admin ONCE at the beginning for stateful test
	// This ensures sufficient balance for all iterations
	swapAmount := int64(1_000_000_000_000) // Large amount for multiple swaps
	mintTestToken(BAR_PATH, swapAmount)
	mintTestToken(FOO_PATH, swapAmount)

	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		params := NewRandomizedPoolSwapParams(ft)

		setupIterations := fuzz.IntRange(1, 10).Draw(ft, "setupIterations").(int)
		for i := 0; i < setupIterations; i++ {
			setupPoolSwapLiquidity(ft, params)
		}

		params.setPriceLimit(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		runTestPoolSwap(ft, params)
	})
}

// runTestPoolSwap runs the test swap by calling DrySwap and Swap
func runTestPoolSwap(ft *fuzz.T, params *poolSwapParams) {
	// Execute DrySwap first
	dryAmount0, dryAmount1, drySuccess := pool.DrySwap(
		params.token0Path,
		params.token1Path,
		params.fee,
		params.zeroForOne,
		params.amountSpecified,
		params.sqrtPriceLimitX96,
	)

	if !drySuccess {
		panic("DrySwap failed")
	}

	// Execute Swap
	swapAmount0, swapAmount1 := callPoolSwap(
		params.token0Path,
		params.token1Path,
		params.fee,
		params.zeroForOne,
		params.amountSpecified,
		params.sqrtPriceLimitX96,
	)

	// Verify DrySwap and Swap results match
	if dryAmount0 != swapAmount0 {
		panic("DrySwap amount0 != Swap amount0")
	}

	if dryAmount1 != swapAmount1 {
		panic("DrySwap amount1 != Swap amount1")
	}
}

// callPoolSwap calls pool.Swap from a mock contract realm to bypass EOA restriction
func callPoolSwap(
	token0Path, token1Path string,
	fee uint32,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
) (amount0, amount1 string) {
	const mockSwapperPath = "gno.land/r/gnoswap/test/mock_swapper"

	poolAddr := access.MustGetAddress(prabc.ROLE_POOL.String())

	// Approve tokens for swap
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	common.SafeGRC20Approve(cross, token0Path, poolAddr, math.MaxInt64)
	common.SafeGRC20Approve(cross, token1Path, poolAddr, math.MaxInt64)

	// Define swap callback
	swapCallback := func(cur realm, amount0Delta, amount1Delta string) error {
		func(cur realm) {
			testing.SetRealm(testing.NewUserRealm(adminAddr))

			// Transfer token0 if needed
			if len(amount0Delta) > 0 && amount0Delta[0] != '-' && amount0Delta != "0" {
				delta0 := u256.MustFromDecimal(amount0Delta)
				common.SafeGRC20Transfer(cross, token0Path, poolAddr, delta0.Int64())
			}

			// Transfer token1 if needed
			if len(amount1Delta) > 0 && amount1Delta[0] != '-' && amount1Delta != "0" {
				delta1 := u256.MustFromDecimal(amount1Delta)
				common.SafeGRC20Transfer(cross, token1Path, poolAddr, delta1.Int64())
			}
		}(cross)

		return nil
	}

	// Execute swap from mock contract realm
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(mockSwapperPath))
		amount0, amount1 = pool.Swap(
			cross,
			token0Path,
			token1Path,
			fee,
			adminAddr,
			zeroForOne,
			amountSpecified,
			sqrtPriceLimitX96,
			adminAddr,
			swapCallback,
		)
	}(cross)

	return amount0, amount1
}

// setupPoolSwapLiquidity sets up pool and liquidity for swap test
func setupPoolSwapLiquidity(ft *fuzz.T, params *poolSwapParams) {
	poolIdentifier := ufmt.Sprintf("%s:%s:%d", params.token0Path, params.token1Path, params.fee)
	setupRouterMintPositionByRoutePath(ft, poolIdentifier)
}
