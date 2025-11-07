package fuzz

import (
	"math"
	"strconv"
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	"gno.land/p/nt/ufmt"
	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// TestFuzzPositionCollectFee_ValidParams_Stateless tests CollectFee with valid parameters
func TestFuzzPositionCollectFee_ValidParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Create pool and initial position
		tokenId := createTestPosition(t, adminAddr, poolAddr)

		// Generate fees by executing swaps
		generateFeesWithSwap(t, adminAddr, poolAddr)

		// Generate params for collect fee
		collectParams := NewValidPositionCollectFeeParams(ft, tokenId)
		fuzzResult.AddParams(index, collectParams)

		// when - collect fee
		_, fee0, fee1, _, _, poolPath := position.CollectFee(
			cross,
			collectParams.positionId,
			collectParams.unwrapResult,
		)

		// then - verify fees collected
		// Fees can be zero if position is out of range during swaps
		if fee0 == "" || fee1 == "" {
			panic("Fee amounts should not be empty")
		}

		if poolPath == "" {
			panic("Pool path should not be empty")
		}
	})
}

// TestFuzzPositionCollectFee_RandomizedParams_Stateless tests CollectFee with randomized parameters
func TestFuzzPositionCollectFee_RandomizedParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Create pool and initial position
		tokenId := createTestPosition(t, adminAddr, poolAddr)

		// Generate fees by executing swaps
		generateFeesWithSwap(t, adminAddr, poolAddr)

		// Generate params for collect fee
		collectParams := NewRandomizedPositionCollectFeeParams(ft, tokenId)
		fuzzResult.AddParams(index, collectParams)

		// when - collect fee (may panic with invalid params)
		position.CollectFee(
			cross,
			collectParams.positionId,
			collectParams.unwrapResult,
		)
	})
}

// Helper function to generate fees by executing swaps
func generateFeesWithSwap(t *testing.T, adminAddr, poolAddr address) {
	t.Helper()

	token0Path := "gno.land/r/onbloc/bar"
	token1Path := "gno.land/r/onbloc/foo"
	fee := uint32(3000)

	// Approve tokens for swap
	common.SafeGRC20Approve(cross, token0Path, poolAddr, math.MaxInt64)
	common.SafeGRC20Approve(cross, token1Path, poolAddr, math.MaxInt64)

	// Swap callback function
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
				common.SafeGRC20Transfer(cross, token0Path, poolAddr, delta0)
			}(cross)
		}

		// Pay token1 if delta1 > 0
		if delta1 > 0 {
			func(cur realm) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				common.SafeGRC20Transfer(cross, token1Path, poolAddr, delta1)
			}(cross)
		}

		return nil
	}

	const mockSwapperPath = "gno.land/r/gnoswap/test/mock_swapper"

	// Execute swap to generate fees
	// Swap token0 for token1
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(mockSwapperPath))
		pool.Swap(
			cross,
			token0Path,
			token1Path,
			fee,
			adminAddr,
			true, // zeroForOne
			"1000000",
			MIN_PRICE_LIMIT_ZERO_FOR_ONE,
			adminAddr,
			swapCallback,
		)
	}(cross)

	// Swap token1 for token0
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(mockSwapperPath))
		pool.Swap(
			cross,
			token0Path,
			token1Path,
			fee,
			adminAddr,
			false, // zeroForOne
			"1000000",
			MAX_PRICE_LIMIT_NOT_ZERO_FOR_ONE,
			adminAddr,
			swapCallback,
		)
	}(cross)
}
