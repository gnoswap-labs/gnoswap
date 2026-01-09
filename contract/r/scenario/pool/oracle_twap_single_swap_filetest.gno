// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	maxApprove int64 = 9223372036854775806
)

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = testing.NewUserRealm(positionAddr)
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())

	poolCreationFee int64 = 100_000_000
)

var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
)

const (
	// 4 hours = 14400 seconds = 2880 blocks (1 block = 5 seconds)
	totalBlocks  int64  = 2880
	halfBlocks   int64  = 1440 // 2 hours
	totalSeconds uint32 = 14400
	halfSeconds  uint32 = 7200
	hourSeconds  uint32 = 3600
)

var (
	fee500   = uint32(500)
	minPrice = "4295128740"                                        // MIN_SQRT_RATIO + 1
	maxPrice = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

func main() {
	println("[SCENARIO] Pool Oracle - TWAP with Price Change")
	println("[INFO] Testing TWAP price query with price change at 2 hours (middle of 4 hours)")
	println()

	// Setup: Create pool
	println("[SCENARIO] 1. Pool Creation")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, poolCreationFee)

	println("[INFO] Creating bar-foo pool (fee: 500, initial tick: 0)")
	pool.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	println("[INFO] Approving tokens for pool operations")
	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)
	println()

	// Increase observation cardinality to store multiple observations
	println("[SCENARIO] 2. Increase Observation Cardinality")
	println("[INFO] Increasing observation cardinality limit to 100")
	pool.IncreaseObservationCardinalityLimit(cross, barPath, fooPath, fee500, 100)
	println()

	// Add liquidity
	println("[SCENARIO] 3. Add Liquidity")
	testing.SetRealm(posRealm)
	println("[INFO] Minting position: tick range [-5000, 5000], liquidity: 100000000")
	pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-5000,
		5000,
		"100000000",
		adminAddr,
	)

	thisPool, _ := pool.GetPool(barPath, fooPath, fee500)
	println("[INFO] Pool liquidity:", thisPool.Liquidity().ToString())
	println("[INFO] Initial pool tick:", thisPool.Slot0Tick())
	println()

	// Wait 2 hours (1440 blocks) - First half
	println("[SCENARIO] 4. Wait 2 Hours (First Half)")
	println("[INFO] Skipping 1440 blocks (2 hours = 7200 seconds)")
	testing.SkipHeights(halfBlocks)
	println()

	// Perform swap to change price at midpoint
	println("[SCENARIO] 5. Swap to Change Price at Midpoint")
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	println("[INFO] Executing swap: zeroForOne=true, amountSpecified=10000000")
	pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"10000000",
		minPrice,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	testing.SetRealm(adminRealm)
	thisPool, _ = pool.GetPool(barPath, fooPath, fee500)
	println("[INFO] Pool tick after swap:", thisPool.Slot0Tick())
	println()

	// Wait another 2 hours (1440 blocks) - Second half
	println("[SCENARIO] 6. Wait Another 2 Hours (Second Half)")
	println("[INFO] Skipping 1440 blocks (2 hours = 7200 seconds)")
	testing.SkipHeights(halfBlocks)
	println()

	// Query TWAP at different intervals
	println("[SCENARIO] 7. TWAP Queries After Price Change")
	poolPath := barPath + ":" + fooPath + ":" + "500"

	twapResult1h , _ := pool.GetTWAP(poolPath, hourSeconds)
	ufmt.Printf("[EXPECTED] TWAP for last 1 hour (3600s ago, recent price): %d\n", twapResult1h)
	println()

	twapResult2h , _ := pool.GetTWAP(poolPath, halfSeconds)
	ufmt.Printf("[EXPECTED] TWAP for last 2 hours (7200s ago, after price change): %d\n", twapResult2h)
	println()

	twapResult4h , _ := pool.GetTWAP(poolPath, totalSeconds)
	ufmt.Printf("[EXPECTED] TWAP for last 4 hours (14400s ago, weighted average of both periods): %d\n", twapResult4h)
	println()

	println("[INFO] Test completed successfully")
	println("[EXPECTED] TWAP should show weighted average: tick 0 (2h) and new tick (2h)")
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64) error {
	testing.SetRealm(adminRealm)

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] Pool Oracle - TWAP with Price Change
// [INFO] Testing TWAP price query with price change at 2 hours (middle of 4 hours)
//
// [SCENARIO] 1. Pool Creation
// [INFO] Approving pool creation fee
// [INFO] Creating bar-foo pool (fee: 500, initial tick: 0)
// [INFO] Approving tokens for pool operations
//
// [SCENARIO] 2. Increase Observation Cardinality
// [INFO] Increasing observation cardinality limit to 100
//
// [SCENARIO] 3. Add Liquidity
// [INFO] Minting position: tick range [-5000, 5000], liquidity: 100000000
// [INFO] Pool liquidity: 100000000
// [INFO] Initial pool tick: 0
//
// [SCENARIO] 4. Wait 2 Hours (First Half)
// [INFO] Skipping 1440 blocks (2 hours = 7200 seconds)
//
// [SCENARIO] 5. Swap to Change Price at Midpoint
// [INFO] Executing swap: zeroForOne=true, amountSpecified=10000000
// [INFO] Pool tick after swap: -1906
//
// [SCENARIO] 6. Wait Another 2 Hours (Second Half)
// [INFO] Skipping 1440 blocks (2 hours = 7200 seconds)
//
// [SCENARIO] 7. TWAP Queries After Price Change
// [EXPECTED] TWAP for last 1 hour (3600s ago, recent price): -1906
//
// [EXPECTED] TWAP for last 2 hours (7200s ago, after price change): -1906
//
// [EXPECTED] TWAP for last 4 hours (14400s ago, weighted average of both periods): -953
//
// [INFO] Test completed successfully
// [EXPECTED] TWAP should show weighted average: tick 0 (2h) and new tick (2h)
