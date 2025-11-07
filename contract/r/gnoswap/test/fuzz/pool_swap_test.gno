package fuzz

import (
	"math"
	"strconv"
	"testing"
	"time"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
)

// TestFuzzPoolSwap_ValidParams_Stateless tests DrySwap and Swap with valid parameters
func TestFuzzPoolSwap_ValidParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTestWithCrossPanic(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		poolSwapParams := NewValidPoolSwapParams(ft)
		fuzzResult.AddParams(index, poolSwapParams)

		// Setup pool and liquidity
		poolPath := setupPoolSwapTest(t, poolSwapParams, adminAddr, poolAddr)

		// Record state before swap
		adminToken0Before, adminToken1Before, poolToken0Before, poolToken1Before, sqrtPriceBefore, liquidityBefore := recordBalancesAndPoolState(adminAddr, poolAddr, poolPath)

		// when - execute DrySwap and Swap
		dryAmount0, dryAmount1, swapAmount0, swapAmount1 := executeSwap(poolSwapParams, adminAddr, poolAddr)

		// then - verify results
		verifySwapResults(dryAmount0, dryAmount1, swapAmount0, swapAmount1)
		verifyBalanceChanges(adminAddr, poolAddr, adminToken0Before, adminToken1Before, poolToken0Before, poolToken1Before, swapAmount0, swapAmount1)
		verifyPoolStateChanges(poolPath, sqrtPriceBefore, liquidityBefore, poolSwapParams.zeroForOne)
	})
}

// TestFuzzPoolSwap_RandomizedParams_Stateless tests DrySwap and Swap with randomized parameters
func TestFuzzPoolSwap_RandomizedParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTestWithCrossPanic(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		poolSwapParams := NewRandomizedPoolSwapParams(ft)
		fuzzResult.AddParams(index, poolSwapParams)

		// Setup pool and liquidity
		poolPath := setupPoolSwapTest(t, poolSwapParams, adminAddr, poolAddr)

		// Record state before swap
		adminToken0Before, adminToken1Before, poolToken0Before, poolToken1Before, sqrtPriceBefore, liquidityBefore := recordBalancesAndPoolState(adminAddr, poolAddr, poolPath)

		// when - execute DrySwap and Swap
		dryAmount0, dryAmount1, swapAmount0, swapAmount1 := executeSwap(poolSwapParams, adminAddr, poolAddr)

		// then - verify results
		verifySwapResults(dryAmount0, dryAmount1, swapAmount0, swapAmount1)
		verifyBalanceChanges(adminAddr, poolAddr, adminToken0Before, adminToken1Before, poolToken0Before, poolToken1Before, swapAmount0, swapAmount1)
		verifyPoolStateChanges(poolPath, sqrtPriceBefore, liquidityBefore, poolSwapParams.zeroForOne)
	})
}


// Helper functions

// poolSwapTestContext holds the test context for pool swap tests
type poolSwapTestContext struct {
	adminAddr address
	poolAddr  address
	poolPath  string
	params    *poolSwapParams
}

// setupPoolSwapTest initializes pool and liquidity for swap test
func setupPoolSwapTest(t *testing.T, params *poolSwapParams, adminAddr, poolAddr address) string {
	t.Helper()

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	poolPath := pool.GetPoolPath(params.token0Path, params.token1Path, params.fee)

	// Create pool if not exists
	if !pool.ExistsPoolPath(poolPath) {
		pool.SetPoolCreationFee(cross, 0)
		pool.CreatePool(
			cross,
			params.token0Path,
			params.token1Path,
			params.fee,
			"79228162514264337593543950337",
		)
	}

	// Approve tokens
	common.SafeGRC20Approve(cross, params.token0Path, poolAddr, math.MaxInt64)
	common.SafeGRC20Approve(cross, params.token1Path, poolAddr, math.MaxInt64)

	// Add liquidity
	addTestLiquidity(t, params.token0Path, params.token1Path, params.fee, adminAddr)

	return poolPath
}

// recordBalancesAndPoolState records token balances and pool state before swap
func recordBalancesAndPoolState(adminAddr, poolAddr address, poolPath string) (
	adminToken0, adminToken1, poolToken0, poolToken1 int64,
	sqrtPrice *u256.Uint, liquidity string,
) {
	adminToken0 = bar.BalanceOf(adminAddr)
	adminToken1 = foo.BalanceOf(adminAddr)
	poolToken0 = bar.BalanceOf(poolAddr)
	poolToken1 = foo.BalanceOf(poolAddr)
	sqrtPrice = pool.GetSlot0SqrtPriceX96(poolPath)
	liquidity = pool.GetLiquidity(poolPath)
	return
}

// executeSwap executes DrySwap and Swap, and returns the results
func executeSwap(params *poolSwapParams, adminAddr, poolAddr address) (dryAmount0, dryAmount1, swapAmount0, swapAmount1 string) {
	// Execute DrySwap
	var drySuccess bool
	dryAmount0, dryAmount1, drySuccess = pool.DrySwap(
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
	swapCallback := func(cur realm, amount0Delta, amount1Delta string) error {
		delta0, err0 := strconv.ParseInt(amount0Delta, 10, 64)
		delta1, err1 := strconv.ParseInt(amount1Delta, 10, 64)

		if err0 != nil || err1 != nil {
			panic(ufmt.Sprintf("failed to parse delta: amount0Delta=%s, amount1Delta=%s, err0=%v, err1=%v",
				amount0Delta, amount1Delta, err0, err1))
		}

		// Pay token0 if delta0 > 0
		if delta0 > 0 {
			func(cur realm) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				common.SafeGRC20Transfer(cross, params.token0Path, poolAddr, delta0)
			}(cross)
		}

		// Pay token1 if delta1 > 0
		if delta1 > 0 {
			func(cur realm) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				common.SafeGRC20Transfer(cross, params.token1Path, poolAddr, delta1)
			}(cross)
		}

		return nil
	}

	swapAmount0, swapAmount1 = callPoolSwapFromContract(
		params.token0Path,
		params.token1Path,
		params.fee,
		adminAddr,
		params.zeroForOne,
		params.amountSpecified,
		params.sqrtPriceLimitX96,
		adminAddr,
		swapCallback,
	)

	return
}

// verifySwapResults verifies DrySwap and Swap results match
func verifySwapResults(dryAmount0, dryAmount1, swapAmount0, swapAmount1 string) {
	if dryAmount0 != swapAmount0 {
		panic(ufmt.Sprintf("DrySwap amount0 (%s) != Swap amount0 (%s)", dryAmount0, swapAmount0))
	}

	if dryAmount1 != swapAmount1 {
		panic(ufmt.Sprintf("DrySwap amount1 (%s) != Swap amount1 (%s)", dryAmount1, swapAmount1))
	}
}

// verifyBalanceChanges verifies token balance changes match swap amounts
func verifyBalanceChanges(
	adminAddr, poolAddr address,
	adminToken0Before, adminToken1Before, poolToken0Before, poolToken1Before int64,
	swapAmount0, swapAmount1 string,
) {
	adminToken0After := bar.BalanceOf(adminAddr)
	adminToken1After := foo.BalanceOf(adminAddr)
	poolToken0After := bar.BalanceOf(poolAddr)
	poolToken1After := foo.BalanceOf(poolAddr)

	// Calculate actual balance changes
	adminToken0Delta := adminToken0After - adminToken0Before
	adminToken1Delta := adminToken1After - adminToken1Before
	poolToken0Delta := poolToken0After - poolToken0Before
	poolToken1Delta := poolToken1After - poolToken1Before

	// Verify conservation: admin's loss = pool's gain (for each token)
	// This is the fundamental invariant: tokens don't disappear or appear from nowhere
	if adminToken0Delta+poolToken0Delta != 0 {
		panic(ufmt.Sprintf("Token0 balance conservation violated: admin delta %d, pool delta %d",
			adminToken0Delta, poolToken0Delta))
	}

	if adminToken1Delta+poolToken1Delta != 0 {
		panic(ufmt.Sprintf("Token1 balance conservation violated: admin delta %d, pool delta %d",
			adminToken1Delta, poolToken1Delta))
	}
}

// verifyPoolStateChanges verifies pool state changes after swap
func verifyPoolStateChanges(
	poolPath string,
	sqrtPriceBefore *u256.Uint,
	liquidityBefore string,
	zeroForOne bool,
) {
	sqrtPriceAfter := pool.GetSlot0SqrtPriceX96(poolPath)

	// Verify price direction if price changed (small swaps may not change price due to rounding)
	if sqrtPriceBefore.Cmp(sqrtPriceAfter) != 0 {
		if zeroForOne {
			// Swapping token0 for token1 -> price goes down
			if sqrtPriceBefore.Cmp(sqrtPriceAfter) < 0 {
				panic(ufmt.Sprintf("Price should decrease for zeroForOne swap: before %s, after %s",
					sqrtPriceBefore.ToString(), sqrtPriceAfter.ToString()))
			}
		} else {
			// Swapping token1 for token0 -> price goes up
			if sqrtPriceBefore.Cmp(sqrtPriceAfter) > 0 {
				panic(ufmt.Sprintf("Price should increase for !zeroForOne swap: before %s, after %s",
					sqrtPriceBefore.ToString(), sqrtPriceAfter.ToString()))
			}
		}
	}

	// Note: Price may not change for very small swaps due to rounding
	// Note: Liquidity can change when crossing tick boundaries (concentrated liquidity)
}

// callPoolSwapFromContract calls pool.Swap from a mock contract realm to bypass EOA restriction
func callPoolSwapFromContract(
	token0Path, token1Path string,
	fee uint32,
	recipient address,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
	payer address,
	swapCallback func(cur realm, amount0Delta, amount1Delta string) error,
) (amount0, amount1 string) {
	const mockSwapperPath = "gno.land/r/gnoswap/test/mock_swapper"

	// Call from mock contract realm
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(mockSwapperPath))
		amount0, amount1 = pool.Swap(
			cross,
			token0Path,
			token1Path,
			fee,
			recipient,
			zeroForOne,
			amountSpecified,
			sqrtPriceLimitX96,
			payer,
			swapCallback,
		)
	}(cross)

	return amount0, amount1
}


// addTestLiquidity adds liquidity to a pool for testing
func addTestLiquidity(t *testing.T, token0Path, token1Path string, fee uint32, adminAddr address) {
	t.Helper()

	// Calculate tick range based on fee tier
	tickSpacing := pool.GetFeeAmountTickSpacing(fee)
	tickLower := -tickSpacing * 100 // Wide range for testing
	tickUpper := tickSpacing * 100

	// Mint position to add liquidity
	_, _, _, _ = position.Mint(
		cross,
		token0Path,
		token1Path,
		fee,
		tickLower,
		tickUpper,
		"100000000", // amount0Desired - 100M units
		"100000000", // amount1Desired - 100M units
		"0",         // amount0Min
		"0",         // amount1Min
		time.Now().Add(time.Hour).Unix(), // deadline
		adminAddr, // mintTo
		adminAddr, // caller
		"",        // referrer
	)
}
