// Pool contract upgrade scenario test with validate data
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
	_ "gno.land/r/gnoswap/pool/v3_valid"
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
	positionId        = uint64(1)
)

const (
	poolV1Path        = "gno.land/r/gnoswap/pool/v1"
	poolV2InvalidPath = "gno.land/r/gnoswap/pool/v2_invalid"
	poolV3ValidPath   = "gno.land/r/gnoswap/pool/v3_valid"
)

func main() {
	println("[SCENARIO] 1. Pool Contract Initialize")
	initialize()
	println()

	println("[SCENARIO] 2. Create pool with v1")
	createPool(barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	println()

	println("[SCENARIO] 3. Mint position with v1")
	mintPosition(barPath, fooPath, fee500, -960, 960, "50000000", "50000000", "0", "0", time.Now().Unix()+3600, adminAddr, adminAddr)
	println()

	println("[SCENARIO] 4. Check pool data by v1 version:", barFoo500PoolPath)
	checkPoolData(barFoo500PoolPath)
	println()

	println("[SCENARIO] 5. Check position data by v1 version:", positionId)
	checkPositionData(positionId)
	println()

	println("[SCENARIO] 6. Pool Contract Upgrade to v2_invalid")
	upgradePoolContractToV2Invalid()
	println()

	println("[SCENARIO] 7. Mint position with v2_invalid (should panic)")
	withAbortsWithMessage(func() {
		mintPosition(barPath, fooPath, fee500, -960, 960, "30000000", "30000000", "0", "0", time.Now().Unix()+3600, adminAddr, adminAddr)
	},
		"[EXPECTED] Mint position panics correctly with v2_invalid", // log message when success panic
	)
	println()

	println("[SCENARIO] 8. Check pool data with v2_invalid (should panic):", barFoo500PoolPath)
	withAbortsWithMessage(func() {
		checkPoolData(barFoo500PoolPath)
	},
		"[EXPECTED] Check pool data panics correctly with v2_invalid", // log message when success panic
	)
	println()

	println("[SCENARIO] 9. Check position data with v2_invalid:", positionId)
	checkPositionData(positionId)
	println()

	println("[SCENARIO] 10. Pool Contract Upgrade to v3_valid")
	upgradePoolContractToV3Valid()
	println()

	println("[SCENARIO] 11. Check pool data by v3_valid version after upgrade:", barFoo500PoolPath)
	checkPoolData(barFoo500PoolPath)
	println()

	println("[SCENARIO] 12. Check position data by v3_valid version after upgrade:", positionId)
	checkPositionData(positionId)
	println()

	println("[SCENARIO] 13. Mint position with v3_valid after upgrade")
	mintPosition(barPath, fooPath, fee500, -960, 960, "30000000", "30000000", "0", "0", time.Now().Unix()+3600, adminAddr, adminAddr)
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

func upgradePoolContractToV2Invalid() {
	println("[INFO] Upgrade pool contract to v2_invalid")
	testing.SetRealm(adminRealm)

	pool.UpgradeImpl(cross, poolV2InvalidPath)
	println("[EXPECTED] Upgraded pool contract to v2_invalid:", poolV2InvalidPath)
}

func upgradePoolContractToV3Valid() {
	println("[INFO] Upgrade pool contract to v3_valid")
	testing.SetRealm(adminRealm)

	pool.UpgradeImpl(cross, poolV3ValidPath)
	println("[EXPECTED] Upgraded pool contract to v3_valid:", poolV3ValidPath)
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

func checkPositionData(positionId uint64) {
	println("[INFO] Check position data")
	testing.SetRealm(adminRealm)

	positionData, _ := position.GetPosition(positionId)
	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] PoolKey:", positionData.PoolKey())
	println("[EXPECTED] Liquidity:", positionData.Liquidity())
	println("[EXPECTED] TickLower:", positionData.TickLower())
	println("[EXPECTED] TickUpper:", positionData.TickUpper())
}

func withAbortsWithMessage(callback func(), logMessage string) {
	uassert.AbortsContains(t, "implementation", func() {
		callback()
	})
	println(logMessage)
}

// Output:
// [SCENARIO] 1. Pool Contract Initialize
// [EXPECTED] Initialized pool contract with v1: gno.land/r/gnoswap/pool/v1
//
// [SCENARIO] 2. Create pool with v1
// [INFO] Create pool
// [EXPECTED] Created pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
//
// [SCENARIO] 3. Mint position with v1
// [INFO] Mint position
// [EXPECTED] Position ID: 1
// [EXPECTED] Liquidity: 1066918731
// [EXPECTED] Amount0: 50000000
// [EXPECTED] Amount1: 50000000
//
// [SCENARIO] 4. Check pool data by v1 version: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [INFO] Check pool data
// [EXPECTED] Pool data: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Token0 path: gno.land/r/onbloc/bar
// [EXPECTED] Token1 path: gno.land/r/onbloc/foo
// [EXPECTED] Fee: 500
// [EXPECTED] Slot0 sqrt price X96: 79228162514264337593543950336
// [EXPECTED] Slot0 tick: 0
// [EXPECTED] Liquidity: 1066918731
//
// [SCENARIO] 5. Check position data by v1 version: 1
// [INFO] Check position data
// [EXPECTED] Position ID: 1
// [EXPECTED] PoolKey: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Liquidity: &(array[(1066918731 uint64),(0 uint64),(0 uint64),(0 uint64)] gno.land/p/gnoswap/uint256.Uint)
// [EXPECTED] TickLower: -960
// [EXPECTED] TickUpper: 960
//
// [SCENARIO] 6. Pool Contract Upgrade to v2_invalid
// [INFO] Upgrade pool contract to v2_invalid
// [EXPECTED] Upgraded pool contract to v2_invalid: gno.land/r/gnoswap/pool/v2_invalid
//
// [SCENARIO] 7. Mint position with v2_invalid (should panic)
// [INFO] Mint position
// [EXPECTED] Mint position panics correctly with v2_invalid
//
// [SCENARIO] 8. Check pool data with v2_invalid (should panic): gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [INFO] Check pool data
// [EXPECTED] Check pool data panics correctly with v2_invalid
//
// [SCENARIO] 9. Check position data with v2_invalid: 1
// [INFO] Check position data
// [EXPECTED] Position ID: 1
// [EXPECTED] PoolKey: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Liquidity: &(array[(1066918731 uint64),(0 uint64),(0 uint64),(0 uint64)] gno.land/p/gnoswap/uint256.Uint)
// [EXPECTED] TickLower: -960
// [EXPECTED] TickUpper: 960
//
// [SCENARIO] 10. Pool Contract Upgrade to v3_valid
// [INFO] Upgrade pool contract to v3_valid
// [EXPECTED] Upgraded pool contract to v3_valid: gno.land/r/gnoswap/pool/v3_valid
//
// [SCENARIO] 11. Check pool data by v3_valid version after upgrade: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [INFO] Check pool data
// [EXPECTED] Pool data: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Token0 path: gno.land/r/onbloc/bar
// [EXPECTED] Token1 path: gno.land/r/onbloc/foo
// [EXPECTED] Fee: 500
// [EXPECTED] Slot0 sqrt price X96: 79228162514264337593543950336
// [EXPECTED] Slot0 tick: 0
// [EXPECTED] Liquidity: 1066918731
//
// [SCENARIO] 12. Check position data by v3_valid version after upgrade: 1
// [INFO] Check position data
// [EXPECTED] Position ID: 1
// [EXPECTED] PoolKey: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Liquidity: &(array[(1066918731 uint64),(0 uint64),(0 uint64),(0 uint64)] gno.land/p/gnoswap/uint256.Uint)
// [EXPECTED] TickLower: -960
// [EXPECTED] TickUpper: 960
//
// [SCENARIO] 13. Mint position with v3_valid after upgrade
// [INFO] Mint position
// [EXPECTED] Position ID: 2
// [EXPECTED] Liquidity: 640151238
// [EXPECTED] Amount0: 30000000
// [EXPECTED] Amount1: 30000000
