// PKGPATH: gno.land/r/gnoswap/v1/main

// Router contract upgrade scenario test with collect fee
package main

import (
	"gno.land/p/gnoswap/gnsmath"
	"math"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	mock "gno.land/r/gnoswap/router/mock"

	_ "gno.land/r/gnoswap/router/v1"
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
	routerV1Path     = "gno.land/r/gnoswap/router/v1"
	routerV2MockPath = "gno.land/r/gnoswap/router/v2_mock"
)

func main(cur realm) {
	println("[SCENARIO] 1. Router Contract Initialize")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Create pool with v1")
	createPool(cur, barPath, fooPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	println()

	println("[SCENARIO] 3. Mint position with v1")
	mintPosition(cur, barPath, fooPath, fee500, -960, 960, "50000000", "50000000", "0", "0", time.Now().Unix()+3600, adminAddr, adminAddr)
	println()

	println("[SCENARIO] 4. Perform swap to generate fees")
	exactInSwapRouteBy(cur, fooPath, barPath, "1000000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1")
	println()

	println("[SCENARIO] 5. Check pool data by v1 version")
	checkPoolData(cur, barFoo500PoolPath)
	println()

	println("[SCENARIO] 6. Check position data by v1 version")
	checkPositionData(cur, positionId)
	println()

	println("[SCENARIO] 6. Router Contract Upgrade to v2_mock")
	upgradeRouterContractToV2Mock(cur)
	println()

	println("[SCENARIO] 7. Perform swap to generate fees (check swap by v2_mock)")
	exactInSwapRouteBy(cur, fooPath, barPath, "1000000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1")
	println()

	println("[SCENARIO] 8. Check pool data by v2_mock version")
	checkPoolData(cur, barFoo500PoolPath)
	println()

	println("[SCENARIO] 9. Check position data by v2_mock version")
	checkPositionData(cur, positionId)
	println()
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)

	router.UpgradeImpl(cross(cur), routerV1Path)
	println("[EXPECTED] Initialized router contract with v1:", routerV1Path)

	initializeV2Mock(cur)
}

func initializeV2Mock(cur realm) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v2_mock"))
	router.RegisterInitializer(cross(cur), func(_ int, rlm realm, store router.IRouterStore) router.IRouter {
		return mock.NewMockRouter(store)
	})
}

func createPool(cur realm, barPath, fooPath string, fee uint32, sqrtPriceX96 string) {
	println("[INFO] Create pool")
	testing.SetRealm(adminRealm)

	pool.CreatePool(cross(cur), barPath, fooPath, fee, sqrtPriceX96)
	poolPath := pool.GetPoolPath(barPath, fooPath, fee)

	println("[EXPECTED] Created pool path:", poolPath)
}

func mintPosition(cur realm, barPath, fooPath string, fee uint32, tickLower, tickUpper int32, amount0Desired, amount1Desired string, amount0Min, amount1Min string, deadline int64, recipient, operator address) {
	println("[INFO] Mint position")

	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)

	positionId, liquidity, amount0, amount1 := position.Mint(cross(cur), barPath, fooPath, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, adminAddr, "")
	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] Liquidity:", liquidity)
	println("[EXPECTED] Amount0:", amount0)
	println("[EXPECTED] Amount1:", amount1)
}

func exactInSwapRouteBy(cur realm, inputToken string, outputToken string, specifiedAmount string, routeQueryString string, queryRatios string, minAmountOut string) {
	println("[INFO] Exact-In Swap Route")
	testing.SetRealm(adminRealm)

	bar.Approve(cross(cur), routerAddr, math.MaxInt64)
	foo.Approve(cross(cur), routerAddr, math.MaxInt64)

	if router.GetImplementationPackagePath() == routerV2MockPath {
		println("[INFO] ExactInSwapRoute called by v2_mock contract")
	}
	inputTokenAmount, outputTokenAmount := router.ExactInSwapRoute(cross(cur), inputToken, outputToken, specifiedAmount, routeQueryString, queryRatios, minAmountOut, int64(9999999999), "")

	println("[EXPECTED] Input token amount:", inputTokenAmount)
	println("[EXPECTED] Output token amount:", outputTokenAmount)
}

func checkPoolData(cur realm, poolPath string) {
	println("[INFO] Check pool data")
	testing.SetRealm(adminRealm)

	poolData, _ := pool.GetPool(barPath, fooPath, fee500)
	println("[EXPECTED] Pool data:", poolData.PoolPath())
}

func checkPositionData(cur realm, positionId uint64) {
	println("[INFO] Check position data")
	testing.SetRealm(adminRealm)

	positionData, _ := position.GetPosition(positionId)
	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] Position key:", positionData.PoolKey())
	println("[EXPECTED] Liquidity:", positionData.Liquidity())
	println("[EXPECTED] Tick lower:", positionData.TickLower())
	println("[EXPECTED] Tick upper:", positionData.TickUpper())
}

func upgradeRouterContractToV2Mock(cur realm) {
	println("[INFO] Upgrade router contract to v2_mock")
	testing.SetRealm(adminRealm)

	router.UpgradeImpl(cross(cur), routerV2MockPath)
	println("[EXPECTED] Upgraded router contract to v2_mock:", routerV2MockPath)
}

// Output:
// [SCENARIO] 1. Router Contract Initialize
// [EXPECTED] Initialized router contract with v1: gno.land/r/gnoswap/router/v1
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
// [SCENARIO] 5. Check pool data by v1 version
// [INFO] Check pool data
// [EXPECTED] Pool data: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
//
// [SCENARIO] 6. Check position data by v1 version
// [INFO] Check position data
// [EXPECTED] Position ID: 1
// [EXPECTED] Position key: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Liquidity: 1066918731
// [EXPECTED] Tick lower: -960
// [EXPECTED] Tick upper: 960
//
// [SCENARIO] 6. Router Contract Upgrade to v2_mock
// [INFO] Upgrade router contract to v2_mock
// [EXPECTED] Upgraded router contract to v2_mock: gno.land/r/gnoswap/router/v2_mock
//
// [SCENARIO] 7. Perform swap to generate fees (check swap by v2_mock)
// [INFO] Exact-In Swap Route
// [INFO] ExactInSwapRoute called by v2_mock contract
// [EXPECTED] Input token amount: 1000000
// [EXPECTED] Output token amount: -995202
//
// [SCENARIO] 8. Check pool data by v2_mock version
// [INFO] Check pool data
// [EXPECTED] Pool data: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
//
// [SCENARIO] 9. Check position data by v2_mock version
// [INFO] Check position data
// [EXPECTED] Position ID: 1
// [EXPECTED] Position key: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Liquidity: 1066918731
// [EXPECTED] Tick lower: -960
// [EXPECTED] Tick upper: 960
