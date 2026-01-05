// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
	_ "gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/baz"
	_ "gno.land/r/onbloc/foo"
	_ "gno.land/r/onbloc/qux"
)

const (
	maxApprove      int64 = 9223372036854775806
	poolCreationFee int64 = 100_000_000
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())
)

var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	quxPath = "gno.land/r/onbloc/qux"
)

const (
	MIN_SQRT_RATIO = "4295128739"
	MAX_SQRT_RATIO = "1461446703485210103287273052203988822378723970342"
)

func main() {
	println("[REGRESSION] TickMath Boundary Alignment Test")
	println("[PURPOSE] Verify tick_math and pool validation use same boundary logic")
	println("[ISSUE] Fixed validateSqrtPriceX96 to align with TickMathGetTickAtSqrtRatio")
	println("[COMMIT] e551901ea7724ae5041da10adaeb1f95f265e3db")
	println()

	testing.SetRealm(adminRealm)

	// Setup test data
	minSqrtRatio := u256.MustFromDecimal(MIN_SQRT_RATIO)
	maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)
	maxMinusOne := u256.Zero().Sub(maxSqrtRatio, u256.One())
	maxPlusOne := u256.Zero().Add(maxSqrtRatio, u256.One())

	println("[INFO] MIN_SQRT_RATIO:", MIN_SQRT_RATIO)
	println("[INFO] MAX_SQRT_RATIO:", MAX_SQRT_RATIO)
	println("[INFO] MAX_SQRT_RATIO - 1:", maxMinusOne.ToString())
	println("[INFO] MAX_SQRT_RATIO + 1:", maxPlusOne.ToString())
	println()

	// Test 1: MIN_SQRT_RATIO (should be accepted by both)
	println("[TEST 1] sqrtPrice = MIN_SQRT_RATIO (inclusive boundary)")
	println("[EXPECTED] Both tick_math and pool should accept MIN_SQRT_RATIO")

	// Test tick_math acceptance
	tickAtMin := common.TickMathGetTickAtSqrtRatio(minSqrtRatio)
	println("[✓] tick_math.TickMathGetTickAtSqrtRatio accepted MIN_SQRT_RATIO")
	println("[INFO] Resulting tick:", tickAtMin)

	// Test pool validation acceptance
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, 500, MIN_SQRT_RATIO)
	println("[✓] pool.CreatePool accepted MIN_SQRT_RATIO")
	println()

	// Test 2: MAX_SQRT_RATIO - 1 (should be accepted by both)
	println("[TEST 2] sqrtPrice = MAX_SQRT_RATIO - 1 (within valid range)")
	println("[EXPECTED] Both tick_math and pool should accept MAX_SQRT_RATIO - 1")

	// Test tick_math acceptance
	tickAtMaxMinusOne := common.TickMathGetTickAtSqrtRatio(maxMinusOne)
	println("[✓] tick_math.TickMathGetTickAtSqrtRatio accepted MAX_SQRT_RATIO - 1")
	println("[INFO] Resulting tick:", tickAtMaxMinusOne)

	// Test pool validation acceptance
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, bazPath, quxPath, 3000, maxMinusOne.ToString())
	println("[✓] pool.CreatePool accepted MAX_SQRT_RATIO - 1")
	println()

	// Test 3: MAX_SQRT_RATIO (should be rejected by both - exclusive boundary)
	println("[TEST 3] sqrtPrice = MAX_SQRT_RATIO (exclusive boundary)")
	println("[EXPECTED] Both tick_math and pool should reject MAX_SQRT_RATIO")

	// Test tick_math rejection
	tickMathPanicked := false
	func() {
		defer func() {
			if r := recover(); r != nil {
				tickMathPanicked = true
				println("[✓] tick_math.TickMathGetTickAtSqrtRatio rejected MAX_SQRT_RATIO")
				println("[INFO] Panic message:", r)
			}
		}()
		common.TickMathGetTickAtSqrtRatio(maxSqrtRatio)
	}()

	if !tickMathPanicked {
		println("[✗] REGRESSION: tick_math did not reject MAX_SQRT_RATIO")
	}

	// Test pool validation rejection
	poolPanicked := false
	func() {
		defer func() {
			if r := recover(); r != nil {
				poolPanicked = true
				println("[✓] pool.CreatePool rejected MAX_SQRT_RATIO")
				println("[INFO] Panic message:", r)
			}
		}()
		gns.Approve(cross, poolAddr, poolCreationFee)
		pool.CreatePool(cross, barPath, bazPath, 10000, MAX_SQRT_RATIO)
	}()

	if !poolPanicked {
		println("[✗] REGRESSION: pool did not reject MAX_SQRT_RATIO")
	}

	println()

	// Test 4: MAX_SQRT_RATIO + 1 (should be rejected by both)
	println("[TEST 4] sqrtPrice = MAX_SQRT_RATIO + 1 (above valid range)")
	println("[EXPECTED] Both tick_math and pool should reject MAX_SQRT_RATIO + 1")

	// Test tick_math rejection
	tickMathPanicked = false
	func() {
		defer func() {
			if r := recover(); r != nil {
				tickMathPanicked = true
				println("[✓] tick_math.TickMathGetTickAtSqrtRatio rejected MAX_SQRT_RATIO + 1")
				println("[INFO] Panic message:", r)
			}
		}()
		common.TickMathGetTickAtSqrtRatio(maxPlusOne)
	}()

	if !tickMathPanicked {
		println("[✗] REGRESSION: tick_math did not reject MAX_SQRT_RATIO + 1")
	}

	// Test pool validation rejection
	poolPanicked = false
	func() {
		defer func() {
			if r := recover(); r != nil {
				poolPanicked = true
				println("[✓] pool.CreatePool rejected MAX_SQRT_RATIO + 1")
				println("[INFO] Panic message:", r)
			}
		}()
		gns.Approve(cross, poolAddr, poolCreationFee)
		pool.CreatePool(cross, fooPath, quxPath, 100, maxPlusOne.ToString())
	}()

	if !poolPanicked {
		println("[✗] REGRESSION: pool did not reject MAX_SQRT_RATIO + 1")
	}

	println()
	println("[CONCLUSION] Boundary validation alignment verified")
	println("[INFO] tick_math.TickMathGetTickAtSqrtRatio and pool.validateSqrtPriceX96")
	println("[INFO] both use half-open interval [MIN, MAX) consistently")
}

// Output:
// [REGRESSION] TickMath Boundary Alignment Test
// [PURPOSE] Verify tick_math and pool validation use same boundary logic
// [ISSUE] Fixed validateSqrtPriceX96 to align with TickMathGetTickAtSqrtRatio
// [COMMIT] e551901ea7724ae5041da10adaeb1f95f265e3db
//
// [INFO] MIN_SQRT_RATIO: 4295128739
// [INFO] MAX_SQRT_RATIO: 1461446703485210103287273052203988822378723970342
// [INFO] MAX_SQRT_RATIO - 1: 1461446703485210103287273052203988822378723970341
// [INFO] MAX_SQRT_RATIO + 1: 1461446703485210103287273052203988822378723970343
//
// [TEST 1] sqrtPrice = MIN_SQRT_RATIO (inclusive boundary)
// [EXPECTED] Both tick_math and pool should accept MIN_SQRT_RATIO
// [✓] tick_math.TickMathGetTickAtSqrtRatio accepted MIN_SQRT_RATIO
// [INFO] Resulting tick: -887272
// [✓] pool.CreatePool accepted MIN_SQRT_RATIO
//
// [TEST 2] sqrtPrice = MAX_SQRT_RATIO - 1 (within valid range)
// [EXPECTED] Both tick_math and pool should accept MAX_SQRT_RATIO - 1
// [✓] tick_math.TickMathGetTickAtSqrtRatio accepted MAX_SQRT_RATIO - 1
// [INFO] Resulting tick: 887271
// [✓] pool.CreatePool accepted MAX_SQRT_RATIO - 1
//
// [TEST 3] sqrtPrice = MAX_SQRT_RATIO (exclusive boundary)
// [EXPECTED] Both tick_math and pool should reject MAX_SQRT_RATIO
// [✓] tick_math.TickMathGetTickAtSqrtRatio rejected MAX_SQRT_RATIO
// [INFO] Panic message: [GNOSWAP-COMMON-001] value out of range || sqrtPriceX96(1461446703485210103287273052203988822378723970342) is out of range

// Error:
// [GNOSWAP-POOL-003] out of range for numeric value || sqrtPriceX96(1461446703485210103287273052203988822378723970342) is out of range
