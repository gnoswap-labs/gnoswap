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
	halfBlocks   int64  = 1440
	totalSeconds uint32 = 14400
	halfSeconds  uint32 = 7200
	hourSeconds  uint32 = 3600
)

var (
	fee500 = uint32(500)
)

func main() {
	println("[SCENARIO] Pool Oracle - Basic TWAP Test")
	println("[INFO] Testing TWAP price query after 4 hours without price changes")
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

	// Add liquidity
	println("[SCENARIO] 2. Add Liquidity")
	testing.SetRealm(posRealm)
	println("[INFO] Minting position: tick range [-1000, 1000], liquidity: 10000000")
	pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-1000,
		1000,
		"10000000",
		adminAddr,
	)

	thisPool, _ := pool.GetPool(barPath, fooPath, fee500)
	println("[INFO] Pool liquidity:", thisPool.Liquidity().ToString())
	println("[INFO] Pool tick:", thisPool.Slot0Tick())
	println()

	// Get initial TWAP (should be current tick since no time has passed)
	println("[SCENARIO] 3. Initial TWAP Query (0 seconds ago)")
	poolPath := barPath + ":" + fooPath + ":" + "500"
	twapTick, twapLiquidity, _ := pool.GetTWAP(poolPath, 0)
	ufmt.Printf("[EXPECTED] TWAP at 0 seconds ago - tick: %d, liquidity: %s\n", twapTick, twapLiquidity.ToString())
	println()

	// Wait 4 hours (2880 blocks)
	println("[SCENARIO] 4. Wait 4 Hours")
	println("[INFO] Skipping 2880 blocks (4 hours = 14400 seconds)")
	testing.SkipHeights(totalBlocks)
	println()

	// Query TWAP for different periods
	println("[SCENARIO] 5. TWAP Queries After Time Passed")

	twapTick1h, twapLiquidity1h, _ := pool.GetTWAP(poolPath, hourSeconds)
	ufmt.Printf("[EXPECTED] TWAP for last 1 hour (3600s ago) - tick: %d, liquidity: %s\n", twapTick1h, twapLiquidity1h.ToString())
	println()

	twapTick2h, twapLiquidity2h, _ := pool.GetTWAP(poolPath, halfSeconds)
	ufmt.Printf("[EXPECTED] TWAP for last 2 hours (7200s ago) - tick: %d, liquidity: %s\n", twapTick2h, twapLiquidity2h.ToString())
	println()

	twapTick4h, twapLiquidity4h, _ := pool.GetTWAP(poolPath, totalSeconds)
	ufmt.Printf("[EXPECTED] TWAP for last 4 hours (14400s ago) - tick: %d, liquidity: %s\n", twapTick4h, twapLiquidity4h.ToString())
	println()

	println("[INFO] Test completed successfully")
	println("[EXPECTED] TWAP should remain at tick 0 since no price changes occurred")
}

// Output:
// [SCENARIO] Pool Oracle - Basic TWAP Test
// [INFO] Testing TWAP price query after 4 hours without price changes
//
// [SCENARIO] 1. Pool Creation
// [INFO] Approving pool creation fee
// [INFO] Creating bar-foo pool (fee: 500, initial tick: 0)
// [INFO] Approving tokens for pool operations
//
// [SCENARIO] 2. Add Liquidity
// [INFO] Minting position: tick range [-1000, 1000], liquidity: 10000000
// [INFO] Pool liquidity: 10000000
// [INFO] Pool tick: 0
//
// [SCENARIO] 3. Initial TWAP Query (0 seconds ago)
// [EXPECTED] TWAP at 0 seconds ago - tick: 0, liquidity:
//
// [SCENARIO] 4. Wait 4 Hours
// [INFO] Skipping 2880 blocks (4 hours = 14400 seconds)
//
// [SCENARIO] 5. TWAP Queries After Time Passed
// [EXPECTED] TWAP for last 1 hour (3600s ago) - tick: 0, liquidity: 10000000
//
// [EXPECTED] TWAP for last 2 hours (7200s ago) - tick: 0, liquidity: 10000000
//
// [EXPECTED] TWAP for last 4 hours (14400s ago) - tick: 0, liquidity: 10000000
//
// [INFO] Test completed successfully
// [EXPECTED] TWAP should remain at tick 0 since no price changes occurred
