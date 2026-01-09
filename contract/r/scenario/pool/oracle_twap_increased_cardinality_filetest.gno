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

	// 4 hours = 14400 seconds = 2880 blocks (1 block = 5 seconds)
	totalBlocks    int64  = 2880
	halfBlocks     int64  = 1440 // 2 hours
	quarterBlocks  int64  = 720  // 1 hour
	totalSeconds   uint32 = 14400
	halfSeconds    uint32 = 7200
	quarterSeconds uint32 = 3600
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

var (
	fee500   = uint32(500)
	minPrice = "4295128740"                                        // MIN_SQRT_RATIO + 1
	maxPrice = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

func main() {
	println("[SCENARIO] Pool Oracle - TWAP with Increased Observation Cardinality")
	println("[INFO] Testing TWAP with increased observation slots and price changes")
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

	// Increase observation cardinality
	println("[SCENARIO] 2. Increase Observation Cardinality")
	println("[INFO] Increasing observation cardinality limit to 100")
	pool.IncreaseObservationCardinalityLimit(cross, barPath, fooPath, fee500, 100)

	thisPool, _ := pool.GetPool(barPath, fooPath, fee500)
	println("[INFO] Observation cardinality limit:", thisPool.ObservationState().CardinalityLimit())
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

	thisPool, _ = pool.GetPool(barPath, fooPath, fee500)
	println("[INFO] Pool liquidity:", thisPool.Liquidity().ToString())
	println("[INFO] Initial pool tick:", thisPool.Slot0Tick())
	println()

	// Wait 2 hours (1440 blocks) - First half
	println("[SCENARIO] 4. Wait 2 Hours (First Half)")
	println("[INFO] Skipping 1440 blocks (2 hours = 7200 seconds)")
	testing.SkipHeights(halfBlocks)
	println()

	// Perform first swap to change price
	println("[SCENARIO] 5. First Swap to Change Price")
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	println("[INFO] Executing swap: zeroForOne=true, amountSpecified=1000000")
	pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"1000000",
		minPrice,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	testing.SetRealm(adminRealm)
	thisPool, _ = pool.GetPool(barPath, fooPath, fee500)
	println("[INFO] Pool tick after first swap:", thisPool.Slot0Tick())
	println()

	// Wait 1 hour (720 blocks)
	println("[SCENARIO] 6. Wait 1 Hour")
	println("[INFO] Skipping 720 blocks (1 hour = 3600 seconds)")
	testing.SkipHeights(quarterBlocks)
	println()

	// Perform second swap to change price again
	println("[SCENARIO] 7. Second Swap to Change Price Again")
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	println("[INFO] Executing swap: zeroForOne=false, amountSpecified=500000")
	pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		false,
		"500000",
		maxPrice,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	testing.SetRealm(adminRealm)
	thisPool, _ = pool.GetPool(barPath, fooPath, fee500)
	println("[INFO] Pool tick after second swap:", thisPool.Slot0Tick())
	println()

	// Wait another 1 hour (720 blocks) - Complete 4 hours
	println("[SCENARIO] 8. Wait Another 1 Hour (Complete 4 Hours)")
	println("[INFO] Skipping 720 blocks (1 hour = 3600 seconds)")
	testing.SkipHeights(quarterBlocks)
	println()

	// Query TWAP at different time intervals
	println("[SCENARIO] 9. TWAP Queries at Different Intervals")
	poolPath := barPath + ":" + fooPath + ":" + "500"

	twapResult1h , _ := pool.GetTWAP(poolPath, quarterSeconds)
	ufmt.Printf("[EXPECTED] TWAP for last 1 hour (3600s ago): %d\n", twapResult1h)
	println()

	twapResult2h , _ := pool.GetTWAP(poolPath, halfSeconds)
	ufmt.Printf("[EXPECTED] TWAP for last 2 hours (7200s ago): %d\n", twapResult2h)
	println()

	twapResult4h , _ := pool.GetTWAP(poolPath, totalSeconds)
	ufmt.Printf("[EXPECTED] TWAP for last 4 hours (14400s ago): %d\n", twapResult4h)
	println()

	println("[INFO] Test completed successfully")
	println("[EXPECTED] Increased cardinality allows accurate TWAP calculation over longer periods with multiple price changes")
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
// [SCENARIO] Pool Oracle - TWAP with Increased Observation Cardinality
// [INFO] Testing TWAP with increased observation slots and price changes
//
// [SCENARIO] 1. Pool Creation
// [INFO] Approving pool creation fee
// [INFO] Creating bar-foo pool (fee: 500, initial tick: 0)
// [INFO] Approving tokens for pool operations
//
// [SCENARIO] 2. Increase Observation Cardinality
// [INFO] Increasing observation cardinality limit to 100
// [INFO] Observation cardinality limit: 1
//
// [SCENARIO] 3. Add Liquidity
// [INFO] Minting position: tick range [-5000, 5000], liquidity: 100000000
// [INFO] Pool liquidity: 100000000
// [INFO] Initial pool tick: 0
//
// [SCENARIO] 4. Wait 2 Hours (First Half)
// [INFO] Skipping 1440 blocks (2 hours = 7200 seconds)
//
// [SCENARIO] 5. First Swap to Change Price
// [INFO] Executing swap: zeroForOne=true, amountSpecified=1000000
// [INFO] Pool tick after first swap: -199
//
// [SCENARIO] 6. Wait 1 Hour
// [INFO] Skipping 720 blocks (1 hour = 3600 seconds)
//
// [SCENARIO] 7. Second Swap to Change Price Again
// [INFO] Executing swap: zeroForOne=false, amountSpecified=500000
// [INFO] Pool tick after second swap: -99
//
// [SCENARIO] 8. Wait Another 1 Hour (Complete 4 Hours)
// [INFO] Skipping 720 blocks (1 hour = 3600 seconds)
//
// [SCENARIO] 9. TWAP Queries at Different Intervals
// [EXPECTED] TWAP for last 1 hour (3600s ago): -99
//
// [EXPECTED] TWAP for last 2 hours (7200s ago): -149
//
// [EXPECTED] TWAP for last 4 hours (14400s ago): -75
//
// [INFO] Test completed successfully
// [EXPECTED] Increased cardinality allows accurate TWAP calculation over longer periods with multiple price changes
