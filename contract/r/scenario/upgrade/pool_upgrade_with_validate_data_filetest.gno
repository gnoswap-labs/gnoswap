// PKGPATH: gno.land/r/gnoswap/v1/main

// Pool contract upgrade scenario test with validate data
package main

import (
	"math"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	"gno.land/p/gnoswap/utils"

	prbac "gno.land/p/gnoswap/rbac"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/access"
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

	barPath = "gno.land/r/onbloc/bar.BAR"
	fooPath = "gno.land/r/onbloc/foo.FOO"
	fee500  = uint32(500)
	fee3000 = uint32(3000)

	barFoo500PoolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500"
	positionId        = uint64(1)

	tickLower = int32(-960)
	tickUpper = int32(960)

	// snapshot of every getter value written by v1; the KV store is shared
	// across implementations, so each of these must survive both upgrades
	v1PoolLiquidity      string
	v1PoolSqrtPriceX96   string
	v1PoolTick           int32
	v1PoolFeeGrowth0     string
	v1PoolFeeGrowth1     string
	v1PoolTickSpacing    int32
	v1PoolFee            uint32
	v1PoolToken0         string
	v1PoolToken1         string
	v1PoolBalance0       int64
	v1PoolBalance1       int64
	v1PoolProtocolFee0   int64
	v1PoolProtocolFee1   int64
	v1PoolPositionCount  int
	v1TickLowerGross     string
	v1TickLowerNet       string
	v1TickUpperGross     string
	v1TickUpperNet       string
	v1TickLowerInit      bool
	v1PoolPosLiquidity   string
	v1PoolCreationFee    int64
	v1WithdrawalFee      uint64
	v1PositionCount      int
	v1PositionLiquidity  string
	v1PositionOwner      address
	v1PositionTickLower  int32
	v1PositionTickUpper  int32
	v1PositionPoolKey    string
	v1PositionIsBurned   bool
	v1PositionIsInRange  bool
	v1PositionTokensOwed int64
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

	println("[SCENARIO] 4. Check pool data by v1 version:", barFoo500PoolPath)
	checkPoolData(cur, barFoo500PoolPath)
	println()

	println("[SCENARIO] 5. Check position data by v1 version:", positionId)
	checkPositionData(cur, positionId)
	println()

	println("[SCENARIO] 5-1. Snapshot every pool / position getter written by v1")
	captureV1Snapshot()
	println()

	println("[SCENARIO] 6. Pool Contract Upgrade to v2_invalid")
	upgradePoolContractToV2Invalid(cur)
	println()

	println("[SCENARIO] 7. Mint position with v2_invalid (should panic)")
	withAbortsWithMessage(
		cur, func() {
			mintPosition(cur, barPath, fooPath, fee500, -960, 960, "30000000", "30000000", "0", "0", time.Now().Unix()+3600, adminAddr, adminAddr)
		},
		"[EXPECTED] Mint position panics correctly with v2_invalid", // log message when success panic
	)
	println()

	println("[SCENARIO] 8. Check pool data with v2_invalid (should panic):", barFoo500PoolPath)
	withAbortsWithMessage(
		cur, func() {
			checkPoolData(cur, barFoo500PoolPath)
		},
		"[EXPECTED] Check pool data panics correctly with v2_invalid", // log message when success panic
	)
	println()

	println("[SCENARIO] 9. Check position data with v2_invalid:", positionId)
	checkPositionData(cur, positionId)
	println()

	println("[SCENARIO] 10. Pool Contract Upgrade to v3_valid")
	upgradePoolContractToV3Valid(cur)
	println()

	println("[SCENARIO] 11. Check pool data by v3_valid version after upgrade:", barFoo500PoolPath)
	checkPoolData(cur, barFoo500PoolPath)
	println()

	println("[SCENARIO] 12. Check position data by v3_valid version after upgrade:", positionId)
	checkPositionData(cur, positionId)
	println()

	println("[SCENARIO] 13. Validate every v1 getter value after the upgrades")
	validateV1Snapshot()
	println()

	println("[SCENARIO] 14. Mint position with v3_valid after upgrade")
	mintPosition(cur, barPath, fooPath, fee500, -960, 960, "30000000", "30000000", "0", "0", time.Now().Unix()+3600, adminAddr, adminAddr)
	println()

	println("[SCENARIO] 15. The new mint must only add liquidity, not reshape v1 data")
	validateAfterSecondMint(cur)
	println()
}

// positionKey mirrors the pool-side position key for the tick range used here.
func positionKey() string {
	return pool.EncodePositionKey(tickLower, tickUpper)
}

func captureV1Snapshot() {
	key := positionKey()
	var err error

	v1PoolLiquidity, err = pool.GetLiquidity(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	v1PoolSqrtPriceX96, err = pool.GetSlot0SqrtPriceX96(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	v1PoolTick, err = pool.GetSlot0Tick(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	v1PoolFeeGrowth0, v1PoolFeeGrowth1, err = pool.GetFeeGrowthGlobalX128(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	v1PoolTickSpacing, err = pool.GetTickSpacing(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	v1PoolFee, err = pool.GetFee(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	v1PoolToken0, err = pool.GetToken0Path(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	v1PoolToken1, err = pool.GetToken1Path(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	v1PoolBalance0, v1PoolBalance1, err = pool.GetBalances(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	v1PoolProtocolFee0, v1PoolProtocolFee1, err = pool.GetProtocolFeesTokens(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	v1PoolPositionCount = pool.GetPoolPositions(barFoo500PoolPath).Size()
	v1TickLowerGross, err = pool.GetTickLiquidityGross(barFoo500PoolPath, tickLower)
	if err != nil {
		panic(err)
	}
	v1TickLowerNet, err = pool.GetTickLiquidityNet(barFoo500PoolPath, tickLower)
	if err != nil {
		panic(err)
	}
	v1TickUpperGross, err = pool.GetTickLiquidityGross(barFoo500PoolPath, tickUpper)
	if err != nil {
		panic(err)
	}
	v1TickUpperNet, err = pool.GetTickLiquidityNet(barFoo500PoolPath, tickUpper)
	if err != nil {
		panic(err)
	}
	v1TickLowerInit, err = pool.GetTickInitialized(barFoo500PoolPath, tickLower)
	if err != nil {
		panic(err)
	}
	v1PoolPosLiquidity, err = pool.GetPositionLiquidity(barFoo500PoolPath, key)
	if err != nil {
		panic(err)
	}
	v1PoolCreationFee = pool.GetPoolCreationFee()
	v1WithdrawalFee = pool.GetWithdrawalFee()

	v1PositionCount = position.GetPositions().Size()
	v1PositionLiquidity = position.GetPositionLiquidity(positionId)
	v1PositionOwner = position.GetPositionOwner(positionId)
	v1PositionTickLower = position.GetPositionTickLower(positionId)
	v1PositionTickUpper = position.GetPositionTickUpper(positionId)
	v1PositionPoolKey = position.GetPositionPoolKey(positionId)
	v1PositionIsBurned = position.IsBurned(positionId)
	v1PositionIsInRange = position.IsInRange(positionId)
	v1PositionTokensOwed = position.GetPositionTokensOwed0(positionId)

	println("[EXPECTED] pool liquidity:", v1PoolLiquidity)
	println("[EXPECTED] pool balances:", v1PoolBalance0, v1PoolBalance1)
	println("[EXPECTED] pool position count:", v1PoolPositionCount)
	println("[EXPECTED] tick liquidity gross (lower / upper):", v1TickLowerGross, v1TickUpperGross)
	println("[EXPECTED] tick liquidity net (lower / upper):", v1TickLowerNet, v1TickUpperNet)
	println("[EXPECTED] pool-side position liquidity:", v1PoolPosLiquidity)
	println("[EXPECTED] position-side liquidity:", v1PositionLiquidity)
	println("[EXPECTED] position count:", v1PositionCount)

	// the pool-side and position-side ledgers must agree
	uassert.Equal(t, v1PoolLiquidity, v1PositionLiquidity)
	uassert.Equal(t, v1PoolLiquidity, v1PoolPosLiquidity)
	uassert.Equal(t, v1PoolLiquidity, v1TickLowerGross)
	uassert.True(t, v1TickLowerInit)
}

func validateV1Snapshot() {
	key := positionKey()
	feeGrowth0, feeGrowth1, err := pool.GetFeeGrowthGlobalX128(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	balance0, balance1, err := pool.GetBalances(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	protocolFee0, protocolFee1, err := pool.GetProtocolFeesTokens(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	poolLiquidity, err := pool.GetLiquidity(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	poolSqrtPriceX96, err := pool.GetSlot0SqrtPriceX96(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	poolTick, err := pool.GetSlot0Tick(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	tickSpacing, err := pool.GetTickSpacing(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	poolFee, err := pool.GetFee(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	token0, err := pool.GetToken0Path(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	token1, err := pool.GetToken1Path(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	tickLowerGross, err := pool.GetTickLiquidityGross(barFoo500PoolPath, tickLower)
	if err != nil {
		panic(err)
	}
	tickLowerNet, err := pool.GetTickLiquidityNet(barFoo500PoolPath, tickLower)
	if err != nil {
		panic(err)
	}
	tickUpperGross, err := pool.GetTickLiquidityGross(barFoo500PoolPath, tickUpper)
	if err != nil {
		panic(err)
	}
	tickUpperNet, err := pool.GetTickLiquidityNet(barFoo500PoolPath, tickUpper)
	if err != nil {
		panic(err)
	}
	tickLowerInit, err := pool.GetTickInitialized(barFoo500PoolPath, tickLower)
	if err != nil {
		panic(err)
	}
	poolPositionLiquidity, err := pool.GetPositionLiquidity(barFoo500PoolPath, key)
	if err != nil {
		panic(err)
	}

	uassert.Equal(t, v1PoolLiquidity, poolLiquidity)
	uassert.Equal(t, v1PoolSqrtPriceX96, poolSqrtPriceX96)
	uassert.Equal(t, v1PoolTick, poolTick)
	uassert.Equal(t, v1PoolFeeGrowth0, feeGrowth0)
	uassert.Equal(t, v1PoolFeeGrowth1, feeGrowth1)
	uassert.Equal(t, v1PoolTickSpacing, tickSpacing)
	uassert.Equal(t, v1PoolFee, poolFee)
	uassert.Equal(t, v1PoolToken0, token0)
	uassert.Equal(t, v1PoolToken1, token1)
	uassert.Equal(t, v1PoolBalance0, balance0)
	uassert.Equal(t, v1PoolBalance1, balance1)
	uassert.Equal(t, v1PoolProtocolFee0, protocolFee0)
	uassert.Equal(t, v1PoolProtocolFee1, protocolFee1)
	uassert.Equal(t, v1PoolPositionCount, pool.GetPoolPositions(barFoo500PoolPath).Size())
	uassert.Equal(t, v1TickLowerGross, tickLowerGross)
	uassert.Equal(t, v1TickLowerNet, tickLowerNet)
	uassert.Equal(t, v1TickUpperGross, tickUpperGross)
	uassert.Equal(t, v1TickUpperNet, tickUpperNet)
	uassert.Equal(t, v1TickLowerInit, tickLowerInit)
	uassert.Equal(t, v1PoolPosLiquidity, poolPositionLiquidity)
	uassert.Equal(t, v1PoolCreationFee, pool.GetPoolCreationFee())
	uassert.Equal(t, v1WithdrawalFee, pool.GetWithdrawalFee())

	uassert.Equal(t, v1PositionCount, position.GetPositions().Size())
	uassert.Equal(t, v1PositionLiquidity, position.GetPositionLiquidity(positionId))
	uassert.Equal(t, v1PositionOwner, position.GetPositionOwner(positionId))
	uassert.Equal(t, v1PositionTickLower, position.GetPositionTickLower(positionId))
	uassert.Equal(t, v1PositionTickUpper, position.GetPositionTickUpper(positionId))
	uassert.Equal(t, v1PositionPoolKey, position.GetPositionPoolKey(positionId))
	uassert.Equal(t, v1PositionIsBurned, position.IsBurned(positionId))
	uassert.Equal(t, v1PositionIsInRange, position.IsInRange(positionId))
	uassert.Equal(t, v1PositionTokensOwed, position.GetPositionTokensOwed0(positionId))
	uassert.True(t, pool.ExistsPoolPath(barFoo500PoolPath))

	println("[EXPECTED] every pool and position getter still returns the v1 value")
}

func validateAfterSecondMint(cur realm) {
	key := positionKey()
	poolLiquidity, err := pool.GetLiquidity(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	poolPositionLiquidity, err := pool.GetPositionLiquidity(barFoo500PoolPath, key)
	if err != nil {
		panic(err)
	}
	tickLowerGross, err := pool.GetTickLiquidityGross(barFoo500PoolPath, tickLower)
	if err != nil {
		panic(err)
	}

	println("[EXPECTED] pool liquidity after the second mint:", poolLiquidity)
	println("[EXPECTED] pool-side position liquidity:", poolPositionLiquidity)
	println("[EXPECTED] pool position count:", pool.GetPoolPositions(barFoo500PoolPath).Size())
	println("[EXPECTED] position count:", position.GetPositions().Size())
	println("[EXPECTED] tick liquidity gross (lower):", tickLowerGross)

	// the two positions share the same tick range, so the pool-side position
	// entry is the sum of both and the first position is untouched
	uassert.Equal(t, v1PositionCount+1, position.GetPositions().Size())
	uassert.Equal(t, v1PositionLiquidity, position.GetPositionLiquidity(positionId))
	uassert.Equal(t, poolLiquidity, poolPositionLiquidity)
	uassert.Equal(t, poolLiquidity, tickLowerGross)
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)
	pool.UpgradeImpl(cross(cur), poolV1Path)
	println("[EXPECTED] Initialized pool contract with v1:", poolV1Path)
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

func checkPoolData(cur realm, poolPath string) {
	println("[INFO] Check pool data")
	testing.SetRealm(adminRealm)

	poolData, _ := pool.GetPools().Get(pool.GetPoolPath(barPath, fooPath, fee500)).(*pool.Pool)

	println("[EXPECTED] Pool data:", poolData.PoolPath())
	println("[EXPECTED] Token0 path:", poolData.Token0Path())
	println("[EXPECTED] Token1 path:", poolData.Token1Path())
	println("[EXPECTED] Fee:", poolData.Fee())
	println("[EXPECTED] Slot0 sqrt price X96:", poolData.Slot0SqrtPriceX96().ToString())
	println("[EXPECTED] Slot0 tick:", poolData.Slot0Tick())
	println("[EXPECTED] Liquidity:", poolData.Liquidity().ToString())
}

func checkPositionData(cur realm, positionId uint64) {
	println("[INFO] Check position data")
	testing.SetRealm(adminRealm)

	positionData, _ := position.GetPositions().Get(utils.Uint64ToString(positionId)).(position.Position)
	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] PoolKey:", positionData.PoolKey())
	println("[EXPECTED] Liquidity:", positionData.Liquidity())
	println("[EXPECTED] TickLower:", positionData.TickLower())
	println("[EXPECTED] TickUpper:", positionData.TickUpper())
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
// [SCENARIO] 4. Check pool data by v1 version: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [INFO] Check pool data
// [EXPECTED] Pool data: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] Token0 path: gno.land/r/onbloc/bar.BAR
// [EXPECTED] Token1 path: gno.land/r/onbloc/foo.FOO
// [EXPECTED] Fee: 500
// [EXPECTED] Slot0 sqrt price X96: 79228162514264337593543950336
// [EXPECTED] Slot0 tick: 0
// [EXPECTED] Liquidity: 1066918731
//
// [SCENARIO] 5. Check position data by v1 version: 1
// [INFO] Check position data
// [EXPECTED] Position ID: 1
// [EXPECTED] PoolKey: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] Liquidity: 1066918731
// [EXPECTED] TickLower: -960
// [EXPECTED] TickUpper: 960
//
// [SCENARIO] 5-1. Snapshot every pool / position getter written by v1
// [EXPECTED] pool liquidity: 1066918731
// [EXPECTED] pool balances: 50000000 50000000
// [EXPECTED] pool position count: 1
// [EXPECTED] tick liquidity gross (lower / upper): 1066918731 1066918731
// [EXPECTED] tick liquidity net (lower / upper): 1066918731 -1066918731
// [EXPECTED] pool-side position liquidity: 1066918731
// [EXPECTED] position-side liquidity: 1066918731
// [EXPECTED] position count: 1
//
// [SCENARIO] 6. Pool Contract Upgrade to v2_invalid
// [INFO] Upgrade pool contract to v2_invalid
// [EXPECTED] Upgraded pool contract to v2_invalid: gno.land/r/gnoswap/pool/v2_invalid
//
// [SCENARIO] 7. Mint position with v2_invalid (should panic)
// [INFO] Mint position
// [EXPECTED] Mint position panics correctly with v2_invalid
//
// [SCENARIO] 8. Check pool data with v2_invalid (should panic): gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [INFO] Check pool data
// [EXPECTED] Check pool data panics correctly with v2_invalid
//
// [SCENARIO] 9. Check position data with v2_invalid: 1
// [INFO] Check position data
// [EXPECTED] Position ID: 1
// [EXPECTED] PoolKey: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] Liquidity: 1066918731
// [EXPECTED] TickLower: -960
// [EXPECTED] TickUpper: 960
//
// [SCENARIO] 10. Pool Contract Upgrade to v3_valid
// [INFO] Upgrade pool contract to v3_valid
// [EXPECTED] Upgraded pool contract to v3_valid: gno.land/r/gnoswap/pool/v3_valid
//
// [SCENARIO] 11. Check pool data by v3_valid version after upgrade: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [INFO] Check pool data
// [EXPECTED] Pool data: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] Token0 path: gno.land/r/onbloc/bar.BAR
// [EXPECTED] Token1 path: gno.land/r/onbloc/foo.FOO
// [EXPECTED] Fee: 500
// [EXPECTED] Slot0 sqrt price X96: 79228162514264337593543950336
// [EXPECTED] Slot0 tick: 0
// [EXPECTED] Liquidity: 1066918731
//
// [SCENARIO] 12. Check position data by v3_valid version after upgrade: 1
// [INFO] Check position data
// [EXPECTED] Position ID: 1
// [EXPECTED] PoolKey: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] Liquidity: 1066918731
// [EXPECTED] TickLower: -960
// [EXPECTED] TickUpper: 960
//
// [SCENARIO] 13. Validate every v1 getter value after the upgrades
// [EXPECTED] every pool and position getter still returns the v1 value
//
// [SCENARIO] 14. Mint position with v3_valid after upgrade
// [INFO] Mint position
// [EXPECTED] Position ID: 2
// [EXPECTED] Liquidity: 640151238
// [EXPECTED] Amount0: 30000000
// [EXPECTED] Amount1: 30000000
//
// [SCENARIO] 15. The new mint must only add liquidity, not reshape v1 data
// [EXPECTED] pool liquidity after the second mint: 1707069969
// [EXPECTED] pool-side position liquidity: 1707069969
// [EXPECTED] pool position count: 1
// [EXPECTED] position count: 2
// [EXPECTED] tick liquidity gross (lower): 1707069969
