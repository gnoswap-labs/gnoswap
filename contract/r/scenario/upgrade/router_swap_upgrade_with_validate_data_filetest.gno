// PKGPATH: gno.land/r/gnoswap/v1/main

// Router contract upgrade scenario test with collect fee
package main

import (
	"math"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"

	prbac "gno.land/p/gnoswap/rbac"
	uassert "gno.land/p/nt/uassert/v0"

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

	barPath = "gno.land/r/onbloc/bar.BAR"
	fooPath = "gno.land/r/onbloc/foo.FOO"
	fee500  = uint32(500)

	barFoo500PoolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500"
	positionId        = uint64(1)

	// snapshot taken after the v1 swap; the router upgrade must not touch any
	// of the pool / position state it produced
	v1SwapFee            uint64
	v1PoolLiquidity      string
	v1PoolTick           int32
	v1PoolFeeGrowth0     string
	v1PoolFeeGrowth1     string
	v1PoolProtocolFee0   int64
	v1PoolProtocolFee1   int64
	v1PoolBalance0       int64
	v1PoolBalance1       int64
	v1PositionLiquidity  string
	v1PositionPoolKey    string
	v1PositionTickLower  int32
	v1PositionTickUpper  int32
	v1PositionUnclaimed0 string
	v1PositionUnclaimed1 string
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
	exactInSwapRouteBy(cur, fooPath, barPath, "1000000", "gno.land/r/onbloc/foo.FOO:gno.land/r/onbloc/bar.BAR:500", "100", "1")
	println()

	println("[SCENARIO] 5. Check pool data by v1 version")
	checkPoolData(cur, barFoo500PoolPath)
	println()

	println("[SCENARIO] 6. Check position data by v1 version")
	checkPositionData(cur, positionId)
	println()

	println("[SCENARIO] 6-1. Snapshot the swap state produced by v1")
	captureV1Snapshot()
	println()

	println("[SCENARIO] 6. Router Contract Upgrade to v2_mock")
	upgradeRouterContractToV2Mock(cur)
	println()

	println("[SCENARIO] 6-2. Validate the v1 swap state exactly, before the second swap")
	validateExactAfterUpgrade()
	println()

	println("[SCENARIO] 7. Perform swap to generate fees (check swap by v2_mock)")
	exactInSwapRouteBy(cur, fooPath, barPath, "1000000", "gno.land/r/onbloc/foo.FOO:gno.land/r/onbloc/bar.BAR:500", "100", "1")
	println()

	println("[SCENARIO] 8. Check pool data by v2_mock version")
	checkPoolData(cur, barFoo500PoolPath)
	println()

	println("[SCENARIO] 9. Check position data by v2_mock version")
	checkPositionData(cur, positionId)
	println()

	println("[SCENARIO] 10. Validate the accrual produced by the second swap")
	validateAccrualAfterUpgrade()
	println()
}

func captureV1Snapshot() {
	v1SwapFee = router.GetSwapFee()
	v1PoolLiquidity = pool.GetLiquidity(barFoo500PoolPath)
	v1PoolTick = pool.GetSlot0Tick(barFoo500PoolPath)
	v1PoolFeeGrowth0, v1PoolFeeGrowth1 = pool.GetFeeGrowthGlobalX128(barFoo500PoolPath)
	v1PoolProtocolFee0, v1PoolProtocolFee1 = pool.GetProtocolFeesTokens(barFoo500PoolPath)
	v1PoolBalance0, v1PoolBalance1 = pool.GetBalances(barFoo500PoolPath)
	v1PositionLiquidity = position.GetPositionLiquidity(positionId)
	v1PositionPoolKey = position.GetPositionPoolKey(positionId)
	v1PositionTickLower = position.GetPositionTickLower(positionId)
	v1PositionTickUpper = position.GetPositionTickUpper(positionId)
	v1PositionUnclaimed0, v1PositionUnclaimed1 = position.GetUnclaimedFee(positionId)

	println("[EXPECTED] Router swap fee:", v1SwapFee)
	println("[EXPECTED] Pool tick after the v1 swap:", v1PoolTick)
	println("[EXPECTED] Pool liquidity:", v1PoolLiquidity)
	println("[EXPECTED] Pool balances:", v1PoolBalance0, v1PoolBalance1)
	println("[EXPECTED] Pool fee growth global:", v1PoolFeeGrowth0, v1PoolFeeGrowth1)
	println("[EXPECTED] Pool protocol fees:", v1PoolProtocolFee0, v1PoolProtocolFee1)
	println("[EXPECTED] Position unclaimed fee:", v1PositionUnclaimed0, v1PositionUnclaimed1)

	// the v1 swap actually charged an LP fee, otherwise the rest of the test
	// would be validating an empty state
	uassert.NotEqual(t, "0", v1PositionUnclaimed1)
	uassert.Equal(t, v1PoolLiquidity, v1PositionLiquidity)
}

// validateExactAfterUpgrade runs before the post-upgrade swap, so every pool and
// position value must still match the snapshot exactly; a reset that the second
// swap happens to repopulate would slip past a >= check.
func validateExactAfterUpgrade() {
	feeGrowth0, feeGrowth1 := pool.GetFeeGrowthGlobalX128(barFoo500PoolPath)
	protocolFee0, protocolFee1 := pool.GetProtocolFeesTokens(barFoo500PoolPath)
	balance0, balance1 := pool.GetBalances(barFoo500PoolPath)
	unclaimed0, unclaimed1 := position.GetUnclaimedFee(positionId)

	uassert.Equal(t, v1SwapFee, router.GetSwapFee())
	uassert.Equal(t, v1PoolLiquidity, pool.GetLiquidity(barFoo500PoolPath))
	uassert.Equal(t, v1PoolTick, pool.GetSlot0Tick(barFoo500PoolPath))
	uassert.Equal(t, v1PoolFeeGrowth0, feeGrowth0)
	uassert.Equal(t, v1PoolFeeGrowth1, feeGrowth1)
	uassert.Equal(t, v1PoolProtocolFee0, protocolFee0)
	uassert.Equal(t, v1PoolProtocolFee1, protocolFee1)
	uassert.Equal(t, v1PoolBalance0, balance0)
	uassert.Equal(t, v1PoolBalance1, balance1)
	uassert.Equal(t, v1PositionLiquidity, position.GetPositionLiquidity(positionId))
	uassert.Equal(t, v1PositionPoolKey, position.GetPositionPoolKey(positionId))
	uassert.Equal(t, v1PositionTickLower, position.GetPositionTickLower(positionId))
	uassert.Equal(t, v1PositionTickUpper, position.GetPositionTickUpper(positionId))
	uassert.Equal(t, v1PositionUnclaimed0, unclaimed0)
	uassert.Equal(t, v1PositionUnclaimed1, unclaimed1)

	println("[EXPECTED] Every snapshot field matches exactly right after the upgrade")
	println("[EXPECTED] Pool protocol fees:", protocolFee0, protocolFee1)
	println("[EXPECTED] Position unclaimed fee:", unclaimed0, unclaimed1)
}

func validateAccrualAfterUpgrade() {
	feeGrowth0, feeGrowth1 := pool.GetFeeGrowthGlobalX128(barFoo500PoolPath)
	balance0, balance1 := pool.GetBalances(barFoo500PoolPath)
	unclaimed0, unclaimed1 := position.GetUnclaimedFee(positionId)

	// the router upgrade must not move liquidity or reshape the position
	uassert.Equal(t, v1SwapFee, router.GetSwapFee())
	uassert.Equal(t, v1PoolLiquidity, pool.GetLiquidity(barFoo500PoolPath))
	uassert.Equal(t, v1PositionLiquidity, position.GetPositionLiquidity(positionId))
	uassert.Equal(t, v1PositionPoolKey, position.GetPositionPoolKey(positionId))
	uassert.Equal(t, v1PositionTickLower, position.GetPositionTickLower(positionId))
	uassert.Equal(t, v1PositionTickUpper, position.GetPositionTickUpper(positionId))
	uassert.False(t, position.IsBurned(positionId))

	// the swap routed through the upgraded router keeps accruing on top of the
	// v1 values instead of resetting them
	uassert.True(t, feeGrowth0 >= v1PoolFeeGrowth0)
	uassert.True(t, feeGrowth1 >= v1PoolFeeGrowth1)
	uassert.True(t, unclaimed1 >= v1PositionUnclaimed1)
	uassert.True(t, balance1 > v1PoolBalance1)
	uassert.True(t, balance0 < v1PoolBalance0)

	println("[EXPECTED] Router swap fee is unchanged:", router.GetSwapFee())
	println("[EXPECTED] Pool balances after the second swap:", balance0, balance1)
	println("[EXPECTED] Pool fee growth global after the second swap:", feeGrowth0, feeGrowth1)
	println("[EXPECTED] Position unclaimed fee after the second swap:", unclaimed0, unclaimed1)
	println("[EXPECTED] Position identity data is unchanged after the router upgrade")
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
// [EXPECTED] Created pool path: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
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
// [EXPECTED] Pool data: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
//
// [SCENARIO] 6. Check position data by v1 version
// [INFO] Check position data
// [EXPECTED] Position ID: 1
// [EXPECTED] Position key: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] Liquidity: 1066918731
// [EXPECTED] Tick lower: -960
// [EXPECTED] Tick upper: 960
//
// [SCENARIO] 6-1. Snapshot the swap state produced by v1
// [EXPECTED] Router swap fee: 15
// [EXPECTED] Pool tick after the v1 swap: 18
// [EXPECTED] Pool liquidity: 1066918731
// [EXPECTED] Pool balances: 49001436 51000000
// [EXPECTED] Pool fee growth global: 0 159469675165417291499109789005929
// [EXPECTED] Pool protocol fees: 0 0
// [EXPECTED] Position unclaimed fee: 0 499
//
// [SCENARIO] 6. Router Contract Upgrade to v2_mock
// [INFO] Upgrade router contract to v2_mock
// [EXPECTED] Upgraded router contract to v2_mock: gno.land/r/gnoswap/router/v2_mock
//
// [SCENARIO] 6-2. Validate the v1 swap state exactly, before the second swap
// [EXPECTED] Every snapshot field matches exactly right after the upgrade
// [EXPECTED] Pool protocol fees: 0 0
// [EXPECTED] Position unclaimed fee: 0 499
//
// [SCENARIO] 7. Perform swap to generate fees (check swap by v2_mock)
// [INFO] Exact-In Swap Route
// [INFO] ExactInSwapRoute called by v2_mock contract
// [EXPECTED] Input token amount: 1000000
// [EXPECTED] Output token amount: -995202
//
// [SCENARIO] 8. Check pool data by v2_mock version
// [INFO] Check pool data
// [EXPECTED] Pool data: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
//
// [SCENARIO] 9. Check position data by v2_mock version
// [INFO] Check position data
// [EXPECTED] Position ID: 1
// [EXPECTED] Position key: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] Liquidity: 1066918731
// [EXPECTED] Tick lower: -960
// [EXPECTED] Tick upper: 960
//
// [SCENARIO] 10. Validate the accrual produced by the second swap
// [EXPECTED] Router swap fee is unchanged: 15
// [EXPECTED] Pool balances after the second swap: 48004739 52000000
// [EXPECTED] Pool fee growth global after the second swap: 0 318939350330834582998219578011858
// [EXPECTED] Position unclaimed fee after the second swap: 0 999
// [EXPECTED] Position identity data is unchanged after the router upgrade
