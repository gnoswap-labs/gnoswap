// Pool contract rollback scenario test with validate data
package main

import (
	"math"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/pool/v2_invalid"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(prbac.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee500  = uint32(500)
	fee3000 = uint32(3000)

	barFoo500PoolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
)

const (
	poolV1Path   = "gno.land/r/gnoswap/pool/v1"
	poolTestPath = "gno.land/r/gnoswap/pool/v2_invalid"
)

func main() {
	println("[SCENARIO] 1. Pool Contract Initialize")
	initialize()
	println()

	println("[SCENARIO] 2. Create pool and mint position")
	createPool(barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	mintPosition(barPath, fooPath, fee500, -960, 960, "50000000", "50000000", "0", "0", time.Now().Unix()+3600, adminAddr, adminAddr)
	println()

	println("[SCENARIO] 3. Check pool data by v1 version:", barFoo500PoolPath)
	checkPoolData(barFoo500PoolPath)
	println()

	println("[SCENARIO] 4. Pool Contract Upgrade to test version")
	upgradePoolContractToTestVersion()
	println()

	println("[SCENARIO] 5. Check pool data with panic by test version:", barFoo500PoolPath)
	withAbortsWithMessage(func() { checkPoolData(barFoo500PoolPath) },
		"test implementation: GetPool not supported",  // expected abort message
		"[EXPECTED] Check pool data panics correctly", // log message when success panic
	)
	println()

	println("[SCENARIO] 6. Pool Contract Rollback to v1")
	rollbackPoolContract()
	println()

	println("[SCENARIO] 7. Check pool data by v1 version after rollback:", barFoo500PoolPath)
	checkPoolData(barFoo500PoolPath)
	println()
}

func initialize() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)
	pool.UpgradeImpl(cross, poolV1Path)
	println("[EXPECTED] Initialized pool contract with v1:", poolV1Path)
}

func createPool(barPath, fooPath string, fee uint32, sqrtPriceX96 string) {
	println("[INFO] Create pool")
	testing.SetRealm(adminRealm)

	pool.CreatePool(cross, barPath, fooPath, fee, sqrtPriceX96)
	poolPath := pool.GetPoolPath(barPath, fooPath, fee)

	println("[EXPECTED] Created pool path:", poolPath)
}

func mintPosition(barPath, fooPath string, fee uint32, tickLower, tickUpper int32, amount0Desired, amount1Desired string, amount0Min, amount1Min string, deadline int64, recipient, operator address) {
	println("[INFO] Mint position")

	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, math.MaxInt64)
	foo.Approve(cross, poolAddr, math.MaxInt64)

	positionId, liquidity, amount0, amount1 := position.Mint(cross, barPath, fooPath, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, recipient, operator, "")
	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] Liquidity:", liquidity)
	println("[EXPECTED] Amount0:", amount0)
	println("[EXPECTED] Amount1:", amount1)
}

func upgradePoolContractToTestVersion() {
	println("[INFO] Upgrade pool contract to test version")
	testing.SetRealm(adminRealm)

	pool.UpgradeImpl(cross, poolTestPath)
	println("[EXPECTED] Upgraded pool contract to test version:", poolTestPath)
}

func rollbackPoolContract() {
	println("[INFO] Rollback pool contract to v1")
	testing.SetRealm(adminRealm)

	pool.UpgradeImpl(cross, poolV1Path)
	println("[EXPECTED] Rolled back pool contract to v1:", poolV1Path)
}

func checkPoolData(poolPath string) {
	println("[INFO] Check pool data")
	testing.SetRealm(adminRealm)

	poolData := pool.GetPool(barPath, fooPath, fee500)

	println("[EXPECTED] Pool data:", poolData.PoolPath())
	println("[EXPECTED] Token0 path:", poolData.Token0Path())
	println("[EXPECTED] Token1 path:", poolData.Token1Path())
	println("[EXPECTED] Fee:", poolData.Fee())
	println("[EXPECTED] Slot0 sqrt price X96:", poolData.Slot0SqrtPriceX96().ToString())
	println("[EXPECTED] Slot0 tick:", poolData.Slot0Tick())
	println("[EXPECTED] Liquidity:", poolData.Liquidity().ToString())
}

func withAbortsWithMessage(callback func(), expectedAbortMessage string, logMessage string) {
	uassert.AbortsWithMessage(t, expectedAbortMessage, func() {
		callback()
	})
	println(logMessage)
}

// Output:
// [SCENARIO] 1. Pool Contract Initialize
// [EXPECTED] Initialized pool contract with v1: gno.land/r/gnoswap/pool/v1
//
// [SCENARIO] 2. Create pool and mint position
// [INFO] Create pool
// [EXPECTED] Created pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [INFO] Mint position
// [EXPECTED] Position ID: 1
// [EXPECTED] Liquidity: 1066918731
// [EXPECTED] Amount0: 50000000
// [EXPECTED] Amount1: 50000000
//
// [SCENARIO] 3. Check pool data by v1 version: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [INFO] Check pool data
// [EXPECTED] Pool data: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Token0 path: gno.land/r/onbloc/bar
// [EXPECTED] Token1 path: gno.land/r/onbloc/foo
// [EXPECTED] Fee: 500
// [EXPECTED] Slot0 sqrt price X96: 79228162514264337593543950336
// [EXPECTED] Slot0 tick: 0
// [EXPECTED] Liquidity: 1066918731
//
// [SCENARIO] 4. Pool Contract Upgrade to test version
// [INFO] Upgrade pool contract to test version
// [EXPECTED] Upgraded pool contract to test version: gno.land/r/gnoswap/pool/v2_invalid
//
// [SCENARIO] 5. Check pool data with panic by test version: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [INFO] Check pool data
// [EXPECTED] Check pool data panics correctly
//
// [SCENARIO] 6. Pool Contract Rollback to v1
// [INFO] Rollback pool contract to v1
// [EXPECTED] Rolled back pool contract to v1: gno.land/r/gnoswap/pool/v1
//
// [SCENARIO] 7. Check pool data by v1 version after rollback: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [INFO] Check pool data
// [EXPECTED] Pool data: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Token0 path: gno.land/r/onbloc/bar
// [EXPECTED] Token1 path: gno.land/r/onbloc/foo
// [EXPECTED] Fee: 500
// [EXPECTED] Slot0 sqrt price X96: 79228162514264337593543950336
// [EXPECTED] Slot0 tick: 0
// [EXPECTED] Liquidity: 1066918731
