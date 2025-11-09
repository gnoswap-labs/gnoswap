package fuzz

import (
	"math"
	"strconv"
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// TestFuzzPositionCollectFee_ValidParams_Stateless tests CollectFee with valid parameters
func TestFuzzPositionCollectFee_ValidParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Create pool and initial position
		tokenId := createTestPosition(t, adminAddr, poolAddr)

		// Generate fees by executing swaps
		swapCount := fuzz.IntRange(1, 30).Draw(ft, "swapCount").(int)
		generateFeesWithSwap(ft, adminAddr, poolAddr, tokenId, swapCount)

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

		if fee0 == "0" && fee1 == "0" && swapCount > 0 {
			panic(ufmt.Sprintf("fee0 and fee1 should not be 0: fee0=%s, fee1=%s, swapCount=%d", fee0, fee1, swapCount))
		}
	})
}

// TestFuzzPositionCollectFee_RandomizedParams_Stateless tests CollectFee with randomized parameters
func TestFuzzPositionCollectFee_RandomizedParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Create pool and initial position
		tokenId := createTestPosition(t, adminAddr, poolAddr)

		// Generate fees by executing swaps
		swapCount := fuzz.IntRange(0, 30).Draw(ft, "swapCount").(int)
		generateFeesWithSwap(ft, adminAddr, poolAddr, tokenId, swapCount)

		// Generate params for collect fee
		collectParams := NewRandomizedPositionCollectFeeParams(ft, tokenId)
		fuzzResult.AddParams(index, collectParams)

		// when - collect fee (may panic with invalid params)
		_, fee0, fee1, _, _, _ := position.CollectFee(
			cross,
			collectParams.positionId,
			collectParams.unwrapResult,
		)

		if fee0 == "0" && fee1 == "0" && swapCount > 0 {
			panic(ufmt.Sprintf("fee0 and fee1 should not be 0: fee0=%s, fee1=%s, swapCount=%d", fee0, fee1, swapCount))
		}
	})
}

// TestFuzzPositionCollectFee_ValidParams_Stateful tests CollectFee with valid parameters in stateful manner
func TestFuzzPositionCollectFee_ValidParams_Stateful(t *testing.T) {
	initStates(t)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	tokenId := createTestPosition(t, adminAddr, poolAddr)

	// Track total fees collected
	type feeCollection struct {
		fee0 string
		fee1 string
	}
	var collections []feeCollection

	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Generate fees by executing swaps
		swapCount := fuzz.IntRange(1, 30).Draw(ft, "swapCount").(int)
		generateFeesWithSwap(ft, adminAddr, poolAddr, tokenId, swapCount)

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
		if fee0 == "" || fee1 == "" {
			panic("Fee amounts should not be empty")
		}

		if poolPath == "" {
			panic("Pool path should not be empty")
		}

		if fee0 == "0" && fee1 == "0" && swapCount > 0 {
			panic(ufmt.Sprintf("fee0 and fee1 should not be 0: fee0=%s, fee1=%s, swapCount=%d", fee0, fee1, swapCount))
		}

		// Track this collection
		collections = append(collections, feeCollection{
			fee0: fee0,
			fee1: fee1,
		})
	})

	t.Logf("Position #%d collected fees %d times", tokenId, len(collections))
}

// TestFuzzPositionCollectFee_RandomizedParams_Stateful tests CollectFee with randomized parameters in stateful manner
func TestFuzzPositionCollectFee_RandomizedParams_Stateful(t *testing.T) {
	initStates(t)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	tokenId := createTestPosition(t, adminAddr, poolAddr)

	// Track successful collections
	successfulCollections := 0

	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Generate fees by executing swaps
		swapCount := fuzz.IntRange(0, 30).Draw(ft, "swapCount").(int)
		generateFeesWithSwap(ft, adminAddr, poolAddr, tokenId, swapCount)

		// Generate params for collect fee
		collectParams := NewRandomizedPositionCollectFeeParams(ft, tokenId)
		fuzzResult.AddParams(index, collectParams)

		// when - collect fee (may panic with invalid params)
		_, fee0, fee1, _, _, _ := position.CollectFee(
			cross,
			collectParams.positionId,
			collectParams.unwrapResult,
		)

		if fee0 == "0" && fee1 == "0" && swapCount > 0 {
			panic(ufmt.Sprintf("fee0 and fee1 should not be 0: fee0=%s, fee1=%s, swapCount=%d", fee0, fee1, swapCount))
		}

		// Track successful collections
		if fee0 != "" && fee1 != "" {
			successfulCollections++
		}
	})

	t.Logf("Total successful fee collections: %d out of 100", successfulCollections)
}

// Helper function to generate fees by executing swaps
func generateFeesWithSwap(ft *fuzz.T, adminAddr, poolAddr address, positionId uint64, swapCount int) {
	token0Path, token1Path, fee := getPoolInfoFromPosition(positionId)
	poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
	if !pool.ExistsPoolPath(poolPath) {
		panic(ufmt.Sprintf("poolPath(%s) must exist before generating fees", poolPath))
	}

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

	for i := 0; i < swapCount; i++ {
		amountSpecified := fuzz.Int64Range(100, 10000000).Draw(ft, "amountSpecified").(int64)
		zeroForOne := fuzz.Bool().Draw(ft, "zeroForOne").(bool)

		sqrtPriceLimitX96 := MIN_PRICE_LIMIT_ZERO_FOR_ONE
		if zeroForOne {
			mintTestToken(token0Path, amountSpecified)
		} else {
			mintTestToken(token1Path, amountSpecified)
			sqrtPriceLimitX96 = MAX_PRICE_LIMIT_NOT_ZERO_FOR_ONE
		}

		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(mockSwapperPath))
			pool.Swap(
				cross,
				token0Path,
				token1Path,
				fee,
				adminAddr,
				zeroForOne,
				ufmt.Sprintf("%d", amountSpecified),
				sqrtPriceLimitX96,
				adminAddr,
				swapCallback,
			)
		}(cross)
	}
}
