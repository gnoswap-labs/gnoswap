// Router contract upgrade scenario test with collect fee
package main

import (
	"math"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
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

func main() {
	println("[SCENARIO] 1. Router Contract Initialize")
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

	println("[SCENARIO] 5. Check pool data by v1 version")
	checkPoolData(barFoo500PoolPath)
	println()

	println("[SCENARIO] 6. Check position data by v1 version")
	checkPositionData(positionId)
	println()

	println("[SCENARIO] 6. Router Contract Upgrade to v2_mock")
	upgradeRouterContractToV2Mock()
	println()

	println("[SCENARIO] 7. Perform swap to generate fees (check swap by v2_mock)")
	exactInSwapRouteBy(fooPath, barPath, "1000000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1")
	println()

	println("[SCENARIO] 8. Check pool data by v2_mock version")
	checkPoolData(barFoo500PoolPath)
	println()

	println("[SCENARIO] 9. Check position data by v2_mock version")
	checkPositionData(positionId)
	println()
}

func initialize() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	router.UpgradeImpl(cross, routerV1Path)
	println("[EXPECTED] Initialized router contract with v1:", routerV1Path)

	initializeV2Mock()
}

func initializeV2Mock() {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router/v2_mock"))
	router.RegisterInitializer(cross, func(store router.IRouterStore) router.IRouter {
		r := mock.NewMockRouter(store)
		r.SetMockFn("ExactInSwapRoute", func(args ...any) any {
			println("[INFO] ExactInSwapRoute called by v2_mock contract")
			amountIn, amountOut := r.GetInstance().ExactInSwapRoute(args[0].(string), args[1].(string), args[2].(string), args[3].(string), args[4].(string), args[5].(string), args[6].(int64), args[7].(string))
			return []any{amountIn, amountOut}
		})

		return r
	})
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

func checkPoolData(poolPath string) {
	println("[INFO] Check pool data")
	testing.SetRealm(adminRealm)

	poolData := pool.GetPool(barPath, fooPath, fee500)
	println("[EXPECTED] Pool data:", poolData.PoolPath())
}

func checkPositionData(positionId uint64) {
	println("[INFO] Check position data")
	testing.SetRealm(adminRealm)

	positionData, _ := position.GetPosition(positionId)
	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] Position key:", positionData.PoolKey())
	println("[EXPECTED] Liquidity:", positionData.Liquidity())
	println("[EXPECTED] Tick lower:", positionData.TickLower())
	println("[EXPECTED] Tick upper:", positionData.TickUpper())
}

func upgradeRouterContractToV2Mock() {
	println("[INFO] Upgrade router contract to v2_mock")
	testing.SetRealm(adminRealm)

	router.UpgradeImpl(cross, routerV2MockPath)
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
// [EXPECTED] Liquidity: &(struct{(array[(1066918731 uint64),(0 uint64),(0 uint64),(0 uint64)] [4]uint64)} gno.land/p/gnoswap/uint256.Uint)
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
// [EXPECTED] Liquidity: &(struct{(array[(1066918731 uint64),(0 uint64),(0 uint64),(0 uint64)] [4]uint64)} gno.land/p/gnoswap/uint256.Uint)
// [EXPECTED] Tick lower: -960
// [EXPECTED] Tick upper: 960
