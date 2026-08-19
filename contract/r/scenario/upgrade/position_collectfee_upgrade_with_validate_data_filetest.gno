// PKGPATH: gno.land/r/gnoswap/v1/main

// Pool contract upgrade scenario test with collect fee
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

	barPath = "gno.land/r/onbloc/bar.BAR"
	fooPath = "gno.land/r/onbloc/foo.FOO"
	fee500  = uint32(500)

	barFoo500PoolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500"
	positionId        = uint64(1)

	// snapshot of the position / pool getters right after the v1 fee collection
	v1PositionLiquidity   string
	v1PositionPoolKey     string
	v1PositionOwner       address
	v1PositionTickLower   int32
	v1PositionTickUpper   int32
	v1PositionFeeGrowth0  string
	v1PositionFeeGrowth1  string
	v1PositionTokensOwed0 int64
	v1PositionTokensOwed1 int64
	v1PositionUnclaimed0  string
	v1PositionUnclaimed1  string
	v1PoolFeeGrowth0      string
	v1PoolFeeGrowth1      string
	v1PoolProtocolFee0    int64
	v1PoolProtocolFee1    int64
	v1PoolLiquidity       string
	v1PoolTick            int32
)

const (
	poolV1Path        = "gno.land/r/gnoswap/pool/v1"
	poolV2InvalidPath = "gno.land/r/gnoswap/pool/v2_invalid"
	poolV3ValidPath   = "gno.land/r/gnoswap/pool/v3_valid"
)

func main(cur realm) {
	println("[SCENARIO] 1. Pool Contract Initialize")
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

	println("[SCENARIO] 5. Collect fee from position before upgrade")
	collectFee(cur, positionId)
	println()

	println("[SCENARIO] 5-1. Snapshot the position and pool getters written by v1")
	captureV1Snapshot()
	println()

	println("[SCENARIO] 6. Pool Contract Upgrade to v2_invalid")
	upgradePoolContractToV2Invalid(cur)
	println()

	println("[SCENARIO] 7. Perform swap to generate fees (should panic)")
	withAbortsWithMessage(
		cur, func() {
			exactInSwapRouteBy(cur, fooPath, barPath, "1000000", "gno.land/r/onbloc/foo.FOO:gno.land/r/onbloc/bar.BAR:500", "100", "1")
		},
		"[EXPECTED] Perform swap to generate fees panics correctly with v2_invalid",
	)

	println("[SCENARIO] 8. Collect fee from position with v2_invalid (should panic)")
	withAbortsWithMessage(
		cur, func() {
			collectFee(cur, positionId)
		},
		"[EXPECTED] Collect fee from position panics correctly with v2_invalid",
	)
	println()

	println("[SCENARIO] 9. Pool Contract Upgrade to v3_valid")
	upgradePoolContractToV3Valid(cur)
	println()

	println("[SCENARIO] 10. Perform swap to generate fees (should panic)")
	exactInSwapRouteBy(cur, fooPath, barPath, "1000000", "gno.land/r/onbloc/foo.FOO:gno.land/r/onbloc/bar.BAR:500", "100", "1")
	println()

	println("[SCENARIO] 11. Collect fee from position:", positionId)
	collectFee(cur, positionId)
	println()

	println("[SCENARIO] 12. Validate the v1 position data after the upgrades")
	validateV1Snapshot()
	println()
}

func captureV1Snapshot() {
	v1PositionLiquidity = position.GetPositionLiquidity(positionId)
	v1PositionPoolKey = position.GetPositionPoolKey(positionId)
	v1PositionOwner = position.GetPositionOwner(positionId)
	v1PositionTickLower = position.GetPositionTickLower(positionId)
	v1PositionTickUpper = position.GetPositionTickUpper(positionId)
	v1PositionFeeGrowth0, v1PositionFeeGrowth1 = position.GetPositionFeeGrowthInsideLastX128(positionId)
	v1PositionTokensOwed0, v1PositionTokensOwed1 = position.GetPositionTokensOwed(positionId)
	v1PositionUnclaimed0, v1PositionUnclaimed1 = position.GetUnclaimedFee(positionId)
	v1PoolFeeGrowth0, v1PoolFeeGrowth1 = pool.GetFeeGrowthGlobalX128(barFoo500PoolPath)
	v1PoolProtocolFee0, v1PoolProtocolFee1 = pool.GetProtocolFeesTokens(barFoo500PoolPath)
	v1PoolLiquidity = pool.GetLiquidity(barFoo500PoolPath)
	v1PoolTick = pool.GetSlot0Tick(barFoo500PoolPath)

	println("[EXPECTED] Position liquidity:", v1PositionLiquidity)
	println("[EXPECTED] Position fee growth inside last:", v1PositionFeeGrowth0, v1PositionFeeGrowth1)
	println("[EXPECTED] Position tokens owed:", v1PositionTokensOwed0, v1PositionTokensOwed1)
	println("[EXPECTED] Position unclaimed fee after collect:", v1PositionUnclaimed0, v1PositionUnclaimed1)
	println("[EXPECTED] Pool fee growth global:", v1PoolFeeGrowth0, v1PoolFeeGrowth1)
	println("[EXPECTED] Pool protocol fees:", v1PoolProtocolFee0, v1PoolProtocolFee1)

	// everything was just collected, so nothing may be left owed
	uassert.Equal(t, "0", v1PositionUnclaimed0)
	uassert.Equal(t, "0", v1PositionUnclaimed1)
	uassert.Equal(t, int64(0), v1PositionTokensOwed0)
	uassert.Equal(t, int64(0), v1PositionTokensOwed1)
	// the swap ran foo -> bar, so only the token1 side accrued protocol fee
	uassert.True(t, v1PoolProtocolFee1 > 0)
}

func validateV1Snapshot() {
	feeGrowth0, feeGrowth1 := pool.GetFeeGrowthGlobalX128(barFoo500PoolPath)
	unclaimed0, unclaimed1 := position.GetUnclaimedFee(positionId)

	// identity data must be untouched by the upgrades
	uassert.Equal(t, v1PositionLiquidity, position.GetPositionLiquidity(positionId))
	uassert.Equal(t, v1PositionPoolKey, position.GetPositionPoolKey(positionId))
	uassert.Equal(t, v1PositionOwner, position.GetPositionOwner(positionId))
	uassert.Equal(t, v1PositionTickLower, position.GetPositionTickLower(positionId))
	uassert.Equal(t, v1PositionTickUpper, position.GetPositionTickUpper(positionId))
	// no mint / burn happened, so the in-range liquidity is unchanged; the tick
	// may have moved because of the post-upgrade swap
	uassert.Equal(t, v1PoolLiquidity, pool.GetLiquidity(barFoo500PoolPath))
	uassert.False(t, position.IsBurned(positionId))

	// the post-upgrade swap must keep accruing on top of the v1 values, never
	// reset them
	uassert.True(t, feeGrowth0 >= v1PoolFeeGrowth0)
	uassert.True(t, feeGrowth1 >= v1PoolFeeGrowth1)
	uassert.True(t, pool.GetProtocolFeesToken1(barFoo500PoolPath) >= v1PoolProtocolFee1)
	uassert.Equal(t, "0", unclaimed0)
	uassert.Equal(t, "0", unclaimed1)

	println("[EXPECTED] Position identity data is unchanged after the upgrades")
	println("[EXPECTED] Pool fee growth global after upgrade:", feeGrowth0, feeGrowth1)
	println("[EXPECTED] Position unclaimed fee after the second collect:", unclaimed0, unclaimed1)
	println("[EXPECTED] Pool tick before / after the post-upgrade swap:", v1PoolTick, pool.GetSlot0Tick(barFoo500PoolPath))
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)
	pool.UpgradeImpl(cross(cur), poolV1Path)
	pool.SetFeeProtocol(cross(cur), 6, 6) // 1/6 = ~16.67% protocol fee
	println("[EXPECTED] Initialized pool contract with v1:", poolV1Path)
	println("[EXPECTED] Set fee protocol to 6/6")
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

	inputTokenAmount, outputTokenAmount := router.ExactInSwapRoute(cross(cur), inputToken, outputToken, specifiedAmount, routeQueryString, queryRatios, minAmountOut, int64(9999999999), "")

	println("[EXPECTED] Input token amount:", inputTokenAmount)
	println("[EXPECTED] Output token amount:", outputTokenAmount)
}

func collectProtocolFee(cur realm, token0Path, token1Path string, fee uint32, recipient address, amount0Requested, amount1Requested string) {
	println("[INFO] Collect protocol fee")
	testing.SetRealm(adminRealm)

	amount0, amount1 := pool.CollectProtocol(cross(cur), token0Path, token1Path, fee, recipient, amount0Requested, amount1Requested)
	println("[EXPECTED] Collected protocol fee amount0:", amount0)
	println("[EXPECTED] Collected protocol fee amount1:", amount1)
}

func collectFee(cur realm, positionId uint64) {
	testing.SetRealm(adminRealm)

	positionId, protocolFee0, protocolFee1, poolPath, amount0, amount1 := position.CollectFee(cross(cur), positionId)
	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] Collected protocol fee amount0:", protocolFee0)
	println("[EXPECTED] Collected protocol fee amount1:", protocolFee1)
	println("[EXPECTED] Pool path:", poolPath)
	println("[EXPECTED] Amount0:", amount0)
	println("[EXPECTED] Amount1:", amount1)
}

func upgradePoolContractToV2Invalid(cur realm) {
	println("[INFO] Upgrade pool contract to v2_invalid")
	testing.SetRealm(adminRealm)

	pool.UpgradeImpl(cross(cur), poolV2InvalidPath)
	println("[EXPECTED] Upgraded pool contract to v2_invalid:", poolV2InvalidPath)
}

func upgradePoolContractToV3Valid(cur realm) {
	println("[INFO] Upgrade pool contract to v3_valid")
	testing.SetRealm(adminRealm)

	pool.UpgradeImpl(cross(cur), poolV3ValidPath)
	println("[EXPECTED] Upgraded pool contract to v3_valid:", poolV3ValidPath)
}

func withAbortsWithMessage(cur realm, callback func(), logMessage string) {
	uassert.AbortsContains(t, cur, "implementation", func() {
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
// [SCENARIO] 5. Collect fee from position before upgrade
// [EXPECTED] Position ID: 1
// [EXPECTED] Collected protocol fee amount0: 0
// [EXPECTED] Collected protocol fee amount1: 412
// [EXPECTED] Pool path: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] Amount0: 0
// [EXPECTED] Amount1: 416
//
// [SCENARIO] 5-1. Snapshot the position and pool getters written by v1
// [EXPECTED] Position liquidity: 1066918731
// [EXPECTED] Position fee growth inside last: 0 132997709087958021110257564030945
// [EXPECTED] Position tokens owed: 0 0
// [EXPECTED] Position unclaimed fee after collect: 0 0
// [EXPECTED] Pool fee growth global: 0 132997709087958021110257564030945
// [EXPECTED] Pool protocol fees: 0 83
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
// [EXPECTED] Pool path: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] Amount0: 0
// [EXPECTED] Amount1: 416
//
// [SCENARIO] 12. Validate the v1 position data after the upgrades
// [EXPECTED] Position identity data is unchanged after the upgrades
// [EXPECTED] Pool fee growth global after upgrade: 0 265995418175916042220515128061890
// [EXPECTED] Position unclaimed fee after the second collect: 0 0
// [EXPECTED] Pool tick before / after the post-upgrade swap: 18 37
