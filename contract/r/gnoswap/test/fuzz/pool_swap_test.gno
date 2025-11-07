package fuzz

import (
	"math"
	"strconv"
	"testing"
	"time"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
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

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Create pool if not exists
		exists := pool.ExistsPoolPath(pool.GetPoolPath(poolSwapParams.token0Path, poolSwapParams.token1Path, poolSwapParams.fee))
		if !exists {
			pool.SetPoolCreationFee(cross, 0)
			pool.CreatePool(
				cross,
				poolSwapParams.token0Path,
				poolSwapParams.token1Path,
				poolSwapParams.fee,
				"79228162514264337593543950337",
			)
		}

		// Approve tokens
		common.SafeGRC20Approve(cross, poolSwapParams.token0Path, poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, poolSwapParams.token1Path, poolAddr, math.MaxInt64)

		// Add liquidity
		addTestLiquidity(t, poolSwapParams.token0Path, poolSwapParams.token1Path, poolSwapParams.fee, adminAddr)

		// when - execute DrySwap
		dryAmount0, dryAmount1, drySuccess := pool.DrySwap(
			poolSwapParams.token0Path,
			poolSwapParams.token1Path,
			poolSwapParams.fee,
			poolSwapParams.zeroForOne,
			poolSwapParams.amountSpecified,
			poolSwapParams.sqrtPriceLimitX96,
		)

		if !drySuccess {
			panic("DrySwap failed")
		}

		// when - execute Swap
		swapCallback := func(cur realm, amount0Delta, amount1Delta string) error {
			delta0, _ := strconv.Atoi(amount0Delta)
			delta1, _ := strconv.Atoi(amount1Delta)

			var tokenToPay string
			var amountToPay int64

			if delta0 > 0 {
				tokenToPay = poolSwapParams.token0Path
				amountToPay = int64(delta0)
			} else if delta1 > 0 {
				tokenToPay = poolSwapParams.token1Path
				amountToPay = int64(delta1)
			} else {
				return nil
			}

			func(cur realm) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				common.SafeGRC20Transfer(cross, tokenToPay, poolAddr, amountToPay)
			}(cross)
			return nil
		}

		swapAmount0, swapAmount1 := callPoolSwapFromContract(
			poolSwapParams.token0Path,
			poolSwapParams.token1Path,
			poolSwapParams.fee,
			adminAddr,
			poolSwapParams.zeroForOne,
			poolSwapParams.amountSpecified,
			poolSwapParams.sqrtPriceLimitX96,
			adminAddr,
			swapCallback,
		)

		// then - compare results
		if dryAmount0 != swapAmount0 {
			panic(ufmt.Sprintf("DrySwap amount0 (%s) != Swap amount0 (%s)", dryAmount0, swapAmount0))
		}

		if dryAmount1 != swapAmount1 {
			panic(ufmt.Sprintf("DrySwap amount1 (%s) != Swap amount1 (%s)", dryAmount1, swapAmount1))
		}
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

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Create pool if not exists
		exists := pool.ExistsPoolPath(pool.GetPoolPath(poolSwapParams.token0Path, poolSwapParams.token1Path, poolSwapParams.fee))
		if !exists {
			pool.SetPoolCreationFee(cross, 0)
			pool.CreatePool(
				cross,
				poolSwapParams.token0Path,
				poolSwapParams.token1Path,
				poolSwapParams.fee,
				"79228162514264337593543950337",
			)
		}

		// Approve tokens
		common.SafeGRC20Approve(cross, poolSwapParams.token0Path, poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, poolSwapParams.token1Path, poolAddr, math.MaxInt64)

		// Add liquidity
		addTestLiquidity(t, poolSwapParams.token0Path, poolSwapParams.token1Path, poolSwapParams.fee, adminAddr)

		// when - execute DrySwap
		dryAmount0, dryAmount1, drySuccess := pool.DrySwap(
			poolSwapParams.token0Path,
			poolSwapParams.token1Path,
			poolSwapParams.fee,
			poolSwapParams.zeroForOne,
			poolSwapParams.amountSpecified,
			poolSwapParams.sqrtPriceLimitX96,
		)

		if !drySuccess {
			panic("DrySwap failed")
		}

		// when - execute Swap
		swapCallback := func(cur realm, amount0Delta, amount1Delta string) error {
			delta0, _ := strconv.Atoi(amount0Delta)
			delta1, _ := strconv.Atoi(amount1Delta)

			var tokenToPay string
			var amountToPay int64

			if delta0 > 0 {
				tokenToPay = poolSwapParams.token0Path
				amountToPay = int64(delta0)
			} else if delta1 > 0 {
				tokenToPay = poolSwapParams.token1Path
				amountToPay = int64(delta1)
			} else {
				return nil
			}

			func(cur realm) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				common.SafeGRC20Transfer(cross, tokenToPay, poolAddr, amountToPay)
			}(cross)
			return nil
		}

		swapAmount0, swapAmount1 := callPoolSwapFromContract(
			poolSwapParams.token0Path,
			poolSwapParams.token1Path,
			poolSwapParams.fee,
			adminAddr,
			poolSwapParams.zeroForOne,
			poolSwapParams.amountSpecified,
			poolSwapParams.sqrtPriceLimitX96,
			adminAddr,
			swapCallback,
		)

		// then - compare results
		if dryAmount0 != swapAmount0 {
			panic(ufmt.Sprintf("DrySwap amount0 (%s) != Swap amount0 (%s)", dryAmount0, swapAmount0))
		}

		if dryAmount1 != swapAmount1 {
			panic(ufmt.Sprintf("DrySwap amount1 (%s) != Swap amount1 (%s)", dryAmount1, swapAmount1))
		}
	})
}


// Helper functions

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
	tickSpacing := getTickSpacingForFee(fee)
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

// getTickSpacingForFee returns tick spacing for a given fee tier
func getTickSpacingForFee(fee uint32) int32 {
	switch fee {
	case 100:
		return 1
	case 500:
		return 10
	case 3000:
		return 60
	case 10000:
		return 200
	default:
		panic(ufmt.Sprintf("invalid fee tier: %d", fee))
	}
}
