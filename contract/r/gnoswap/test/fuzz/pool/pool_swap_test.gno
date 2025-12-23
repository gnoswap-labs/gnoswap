package pool

import (
	"math"
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	prabc "gno.land/p/gnoswap/rbac"
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

		params.PreDrySwap()

		mintTestToken(params.token0Path, params.SwapAmount())
		mintTestToken(params.token1Path, params.SwapAmount())

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

		params.PreDrySwap()

		mintTestToken(params.token0Path, params.SwapAmount())
		mintTestToken(params.token1Path, params.SwapAmount())

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

	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		params := NewRandomizedPoolSwapParams(ft)

		setupIterations := fuzz.IntRange(1, 10).Draw(ft, "setupIterations").(int)
		for i := 0; i < setupIterations; i++ {
			setupPoolSwapLiquidity(ft, params)
		}

		params.PreDrySwap()

		mintTestToken(params.token0Path, params.SwapAmount())
		mintTestToken(params.token1Path, params.SwapAmount())

		// when
		fuzzResult.AddParams(index, params)

		// then
		runTestPoolSwap(ft, params)
	})
}

// runTestPoolSwap runs the test swap by calling DrySwap and Swap
func runTestPoolSwap(ft *fuzz.T, params *poolSwapParams) {
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
	if params.expectedAmount0 != swapAmount0 {
		panic("DrySwap amount0 != Swap amount0")
	}

	if params.expectedAmount1 != swapAmount1 {
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
	swapCallback := func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
		func(cur realm) {
			testing.SetRealm(testing.NewUserRealm(adminAddr))

			// Transfer token0 if needed
			if amount0Delta > 0 {
				common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
			}

			// Transfer token1 if needed
			if amount1Delta > 0 {
				common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
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
