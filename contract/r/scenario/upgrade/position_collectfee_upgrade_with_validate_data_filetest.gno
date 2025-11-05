// Pool contract upgrade scenario test with collect fee
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
	"gno.land/r/gnoswap/router"
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

	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee500  = uint32(500)

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

	println("[SCENARIO] 4. Perform swap to generate fees")
	exactInSwapRouteBy(fooPath, barPath, "1000000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1")
	println()

	println("[SCENARIO] 5. Collect fee from position before upgrade")
	collectFee(positionId)
	println()

	println("[SCENARIO] 6. Pool Contract Upgrade to v2_invalid")
	upgradePoolContractToV2Invalid()
	println()

	println("[SCENARIO] 7. Perform swap to generate fees (should panic)")
	withAbortsWithMessage(func() {
		exactInSwapRouteBy(fooPath, barPath, "1000000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1")
	},
		"[EXPECTED] Perform swap to generate fees panics correctly with v2_invalid",
	)

	println("[SCENARIO] 8. Collect fee from position with v2_invalid (should panic)")
	withAbortsWithMessage(func() {
		collectFee(positionId)
	},
		"[EXPECTED] Collect fee from position panics correctly with v2_invalid",
	)
	println()

	println("[SCENARIO] 9. Pool Contract Upgrade to v3_valid")
	upgradePoolContractToV3Valid()
	println()

	println("[SCENARIO] 10. Perform swap to generate fees (should panic)")
	exactInSwapRouteBy(fooPath, barPath, "1000000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1")
	println()

	println("[SCENARIO] 11. Collect fee from position:", positionId)
	collectFee(positionId)
	println()
}

func initialize() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)
	pool.UpgradeImpl(cross, poolV1Path)
	pool.SetFeeProtocol(cross, 6, 6) // 1/6 = ~16.67% protocol fee
	println("[EXPECTED] Initialized pool contract with v1:", poolV1Path)
	println("[EXPECTED] Set fee protocol to 6/6")
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

func exactInSwapRouteBy(inputToken string, outputToken string, specifiedAmount string, routeQueryString string, queryRatios string, minAmountOut string) {
	println("[INFO] Exact-In Swap Route")
	testing.SetRealm(adminRealm)

	bar.Approve(cross, routerAddr, math.MaxInt64)
	foo.Approve(cross, routerAddr, math.MaxInt64)

	inputTokenAmount, outputTokenAmount := router.ExactInSwapRoute(cross, inputToken, outputToken, specifiedAmount, routeQueryString, queryRatios, minAmountOut, int64(9999999999), "")

	println("[EXPECTED] Input token amount:", inputTokenAmount)
	println("[EXPECTED] Output token amount:", outputTokenAmount)
}

func collectProtocolFee(token0Path, token1Path string, fee uint32, recipient address, amount0Requested, amount1Requested string) {
	println("[INFO] Collect protocol fee")
	testing.SetRealm(adminRealm)

	amount0, amount1 := pool.CollectProtocol(cross, token0Path, token1Path, fee, recipient, amount0Requested, amount1Requested)
	println("[EXPECTED] Collected protocol fee amount0:", amount0)
	println("[EXPECTED] Collected protocol fee amount1:", amount1)
}

func collectFee(positionId uint64) {
	testing.SetRealm(adminRealm)

	positionId, protocolFee0, protocolFee1, poolPath, amount0, amount1 := position.CollectFee(cross, positionId, false)
	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] Collected protocol fee amount0:", protocolFee0)
	println("[EXPECTED] Collected protocol fee amount1:", protocolFee1)
	println("[EXPECTED] Pool path:", poolPath)
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

func withAbortsWithMessage(callback func(), logMessage string) {
	uassert.AbortsContains(t, "implementation", func() {
		callback()
	})
	println(logMessage)
}

// Output:
// [SCENARIO] 1. Pool Contract Initialize
// [EXPECTED] Initialized pool contract with v1: gno.land/r/gnoswap/pool/v1
// [EXPECTED] Set fee protocol to 6/6
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
// [SCENARIO] 4. Perform swap to generate fees
// [INFO] Exact-In Swap Route
// [EXPECTED] Input token amount: 1000000
// [EXPECTED] Output token amount: -997067
//
// [SCENARIO] 5. Collect fee from position before upgrade
// [EXPECTED] Position ID: 1
// [EXPECTED] Collected protocol fee amount0: 0
// [EXPECTED] Collected protocol fee amount1: 412
// [EXPECTED] Pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Amount0: 0
// [EXPECTED] Amount1: 416
//
// [SCENARIO] 6. Pool Contract Upgrade to v2_invalid
// [INFO] Upgrade pool contract to v2_invalid
// [EXPECTED] Upgraded pool contract to v2_invalid: gno.land/r/gnoswap/pool/v2_invalid
//
// [SCENARIO] 7. Perform swap to generate fees (should panic)
// [INFO] Exact-In Swap Route
// [EXPECTED] Perform swap to generate fees panics correctly with v2_invalid
// [SCENARIO] 8. Collect fee from position with v2_invalid (should panic)
// [EXPECTED] Collect fee from position panics correctly with v2_invalid
//
// [SCENARIO] 9. Pool Contract Upgrade to v3_valid
// [INFO] Upgrade pool contract to v3_valid
// [EXPECTED] Upgraded pool contract to v3_valid: gno.land/r/gnoswap/pool/v3_valid
//
// [SCENARIO] 10. Perform swap to generate fees (should panic)
// [INFO] Exact-In Swap Route
// [EXPECTED] Input token amount: 1000000
// [EXPECTED] Output token amount: -995202
//
// [SCENARIO] 11. Collect fee from position: 1
// [EXPECTED] Position ID: 1
// [EXPECTED] Collected protocol fee amount0: 0
// [EXPECTED] Collected protocol fee amount1: 412
// [EXPECTED] Pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Amount0: 0
// [EXPECTED] Amount1: 416
