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
	println("[SCENARIO] TickMath Boundary Alignment Test")
	println()

	testing.SetRealm(adminRealm)

	minSqrtRatio := u256.MustFromDecimal(MIN_SQRT_RATIO)
	maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)
	maxMinusOne := u256.Zero().Sub(maxSqrtRatio, u256.One())
	maxPlusOne := u256.Zero().Add(maxSqrtRatio, u256.One())

	println("[INFO] Test 1: MIN_SQRT_RATIO (inclusive)")
	tickAtMin := common.TickMathGetTickAtSqrtRatio(minSqrtRatio)
	println("[INFO] tick_math tick:", tickAtMin)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, 500, MIN_SQRT_RATIO)
	println("[INFO] pool.CreatePool accepted")
	println()

	println("[INFO] Test 2: MAX_SQRT_RATIO - 1 (valid)")
	tickAtMaxMinusOne := common.TickMathGetTickAtSqrtRatio(maxMinusOne)
	println("[INFO] tick_math tick:", tickAtMaxMinusOne)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, bazPath, quxPath, 3000, maxMinusOne.ToString())
	println("[INFO] pool.CreatePool accepted")
	println()

	println("[INFO] Test 3: MAX_SQRT_RATIO (exclusive)")
	func() {
		defer func() {
			if r := recover(); r != nil {
				println("[EXPECTED] tick_math rejected")
			}
		}()
		common.TickMathGetTickAtSqrtRatio(maxSqrtRatio)
	}()

	func() {
		defer func() {
			if r := recover(); r != nil {
				println("[EXPECTED] pool rejected")
			}
		}()
		gns.Approve(cross, poolAddr, poolCreationFee)
		pool.CreatePool(cross, barPath, bazPath, 10000, MAX_SQRT_RATIO)
	}()
	println()

	println("[INFO] Test 4: MAX_SQRT_RATIO + 1 (out of range)")
	func() {
		defer func() {
			if r := recover(); r != nil {
				println("[EXPECTED] tick_math rejected")
			}
		}()
		common.TickMathGetTickAtSqrtRatio(maxPlusOne)
	}()

	func() {
		defer func() {
			if r := recover(); r != nil {
				println("[EXPECTED] pool rejected")
			}
		}()
		gns.Approve(cross, poolAddr, poolCreationFee)
		pool.CreatePool(cross, fooPath, quxPath, 100, maxPlusOne.ToString())
	}()
	println()

	println("[INFO] Boundary alignment verified")
}

// Output:
// [SCENARIO] TickMath Boundary Alignment Test
//
// [INFO] Test 1: MIN_SQRT_RATIO (inclusive)
// [INFO] tick_math tick: -887272
// [INFO] pool.CreatePool accepted
//
// [INFO] Test 2: MAX_SQRT_RATIO - 1 (valid)
// [INFO] tick_math tick: 887271
// [INFO] pool.CreatePool accepted
//
// [INFO] Test 3: MAX_SQRT_RATIO (exclusive)
// [EXPECTED] tick_math rejected

// Error:
// [GNOSWAP-POOL-003] out of range for numeric value || sqrtPriceX96(1461446703485210103287273052203988822378723970342) is out of range
