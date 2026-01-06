// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

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
	totalBlocks    int64  = 2880
	halfBlocks     int64  = 1440
	totalSeconds   uint32 = 14400
	halfSeconds    uint32 = 7200
	hourSeconds    uint32 = 3600
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

	thisPool := pool.GetPool(barPath, fooPath, fee500)
	println("[INFO] Pool liquidity:", thisPool.Liquidity().ToString())
	println("[INFO] Pool tick:", thisPool.Slot0Tick())
	println()

	// Get initial TWAP (should be current tick since no time has passed)
	println("[SCENARIO] 3. Initial TWAP Query (0 seconds ago)")
	poolPath := barPath + ":" + fooPath + ":" + "500"
	twapResult := pool.ApiGetTWAP(poolPath, 0)
	println("[EXPECTED] TWAP at 0 seconds ago (current tick):")
	println(twapResult)
	println()

	// Wait 4 hours (2880 blocks)
	println("[SCENARIO] 4. Wait 4 Hours")
	println("[INFO] Skipping 2880 blocks (4 hours = 14400 seconds)")
	testing.SkipHeights(totalBlocks)
	println()

	// Query TWAP for different periods
	println("[SCENARIO] 5. TWAP Queries After Time Passed")

	println("[INFO] Querying TWAP for last 1 hour")
	twapResult1h := pool.ApiGetTWAP(poolPath, hourSeconds)
	println("[EXPECTED] TWAP for last 1 hour:")
	println(twapResult1h)
	println()

	println("[INFO] Querying TWAP for last 2 hours")
	twapResult2h := pool.ApiGetTWAP(poolPath, halfSeconds)
	println("[EXPECTED] TWAP for last 2 hours:")
	println(twapResult2h)
	println()

	println("[INFO] Querying TWAP for last 4 hours")
	twapResult4h := pool.ApiGetTWAP(poolPath, totalSeconds)
	println("[EXPECTED] TWAP for last 4 hours:")
	println(twapResult4h)
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
// [EXPECTED] TWAP at 0 seconds ago (current tick):
// {"stat":{"height":123,"timestamp":1234567890},"response":{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500","twapTick":"0","secondsAgo":"0"}}
//
// [SCENARIO] 4. Wait 4 Hours
// [INFO] Skipping 2880 blocks (4 hours = 14400 seconds)
//
// [SCENARIO] 5. TWAP Queries After Time Passed
// [INFO] Querying TWAP for last 1 hour
// [EXPECTED] TWAP for last 1 hour:
// {"stat":{"height":3003,"timestamp":1234582290},"response":{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500","twapTick":"0","secondsAgo":"3600"}}
//
// [INFO] Querying TWAP for last 2 hours
// [EXPECTED] TWAP for last 2 hours:
// {"stat":{"height":3003,"timestamp":1234582290},"response":{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500","twapTick":"0","secondsAgo":"7200"}}
//
// [INFO] Querying TWAP for last 4 hours
// [EXPECTED] TWAP for last 4 hours:
// {"stat":{"height":3003,"timestamp":1234582290},"response":{"poolPath":"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500","twapTick":"0","secondsAgo":"14400"}}
//
// [INFO] Test completed successfully
// [EXPECTED] TWAP should remain at tick 0 since no price changes occurred
