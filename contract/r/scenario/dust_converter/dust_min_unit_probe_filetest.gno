// PKGPATH: gno.land/r/demo/main
package main

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	dc "gno.land/r/gnoswap/dust_converter"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	userAddr  = testutils.TestAddress("dust-user")
	userRealm = testing.NewUserRealm(userAddr)

	dustConverterAddr = testing.NewCodeRealm("gno.land/r/gnoswap/dust_converter").Address()
)

const (
	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	gnsPath = "gno.land/r/gnoswap/gns"

	feeTier uint32 = 500
)

func main() {
	println("[SCENARIO] Dust min unit probe")
	println()

	println("[SCENARIO] 1. Setup pool and liquidity (tick=0)")
	setupPool(0)
	println()

	println("[SCENARIO] 2. Min=1 (0.000001) with amount=1")
	convertWithMin(1, 1)
	println()

	println("[SCENARIO] 3. Min=10 with amount=1 (should skip)")
	convertWithMin(10, 1)
	println()

	println("[SCENARIO] 4. Min=1 with amount=10")
	convertWithMin(1, 10)
	println()

	println("[SCENARIO] 5. Setup pool and liquidity (extreme tick)")
	setupExtremePool(-200000)
	println()

	println("[SCENARIO] 6. Extreme tick with amount=1")
	convertWithMinToken(1, 1, bazPath)
	println()

	println("[SCENARIO] 7. Extreme tick with amount=1000")
	convertWithMinToken(1, 1000, bazPath)
	println()
}

func setupPool(startTick int32) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	createPool(barPath, gnsPath, feeTier, startTick)

	bar.Approve(cross, poolAddr, 1_000_000_000)
	gns.Approve(cross, poolAddr, 1_000_000_000)

	mintPosition(barPath, gnsPath, feeTier, "1000000", "1000000")
}

func setupExtremePool(startTick int32) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	createPool(gnsPath, bazPath, feeTier, startTick)

	baz.Approve(cross, poolAddr, 1_000_000_000)
	gns.Approve(cross, poolAddr, 1_000_000_000)

	mintPositionWithTicks(gnsPath, bazPath, feeTier, startTick-6000, startTick+6000, "1000000", "1000000")
}

func createPool(token0Path, token1Path string, fee uint32, startTick int32) {
	poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
	if pool.ExistsPoolPath(poolPath) {
		return
	}

	pool.CreatePool(
		cross,
		token0Path,
		token1Path,
		fee,
		common.TickMathGetSqrtRatioAtTick(startTick).ToString(),
	)
	sr.SetPoolTier(cross, poolPath, 1)
	ufmt.Printf("[EXPECTED] created pool: %s\n", poolPath)
}

func mintPosition(token0Path, token1Path string, fee uint32, amount0, amount1 string) {
	_, liquidity, amt0, amt1 := pn.Mint(
		cross,
		token0Path,
		token1Path,
		fee,
		-6000,
		6000,
		amount0,
		amount1,
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)
	ufmt.Printf("[EXPECTED] liquidity: %s amount0: %s amount1: %s\n", liquidity, amt0, amt1)
}

func mintPositionWithTicks(
	token0Path,
	token1Path string,
	fee uint32,
	tickLower,
	tickUpper int32,
	amount0,
	amount1 string,
) {
	_, liquidity, amt0, amt1 := pn.Mint(
		cross,
		token0Path,
		token1Path,
		fee,
		tickLower,
		tickUpper,
		amount0,
		amount1,
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)
	ufmt.Printf("[EXPECTED] liquidity: %s amount0: %s amount1: %s\n", liquidity, amt0, amt1)
}

func convertWithMin(minAmount int64, amount int64) {
	convertWithMinToken(minAmount, amount, barPath)
}

func convertWithMinToken(minAmount int64, amount int64, tokenPath string) {
	testing.SetRealm(adminRealm)
	dc.SetDustMinAmount(cross, minAmount)
	dc.SetDustMaxAmount(cross, 0)

	common.SafeGRC20Transfer(cross, tokenPath, dustConverterAddr, amount)
	println("[EXPECTED] dust_converter token balance:", common.BalanceOf(tokenPath, dustConverterAddr))

	testing.SetRealm(userRealm)
	beforeUserGns := gns.BalanceOf(userAddr)
	totalOut := dc.ConvertDustToGns(
		cross,
		gnsPath,
		tokenPath+":"+ufmt.Sprintf("%d", amount),
		time.Now().Add(time.Hour).Unix(),
		userAddr,
	)

	println("[EXPECTED] totalOut:", totalOut)
	println("[EXPECTED] dust_converter token balance after convert:", common.BalanceOf(tokenPath, dustConverterAddr))
	println("[EXPECTED] user gns delta:", gns.BalanceOf(userAddr)-beforeUserGns)
}

// Output:
// [SCENARIO] Dust min unit probe
//
// [SCENARIO] 1. Setup pool and liquidity (tick=0)
// [EXPECTED] created pool: gno.land/r/gnoswap/gns:gno.land/r/onbloc/bar:500
// [EXPECTED] liquidity: 3858461 amount0: 1000000 amount1: 1000000
//
// [SCENARIO] 2. Min=1 (0.000001) with amount=1
// [EXPECTED] dust_converter token balance: 1
// [EXPECTED] totalOut: 0
// [EXPECTED] dust_converter token balance after convert: 1
// [EXPECTED] user gns delta: 0
//
// [SCENARIO] 3. Min=10 with amount=1 (should skip)
// [EXPECTED] dust_converter token balance: 2
// [EXPECTED] totalOut: 0
// [EXPECTED] dust_converter token balance after convert: 2
// [EXPECTED] user gns delta: 0
//
// [SCENARIO] 4. Min=1 with amount=10
// [EXPECTED] dust_converter token balance: 12
// [EXPECTED] totalOut: 8
// [EXPECTED] dust_converter token balance after convert: 2
// [EXPECTED] user gns delta: 8
//
// [SCENARIO] 5. Setup pool and liquidity (extreme tick)
// [EXPECTED] created pool: gno.land/r/gnoswap/gns:gno.land/r/onbloc/baz:500
// [EXPECTED] liquidity: 175 amount0: 998509 amount1: 1
//
// [SCENARIO] 6. Extreme tick with amount=1
// [EXPECTED] dust_converter token balance: 1
// [EXPECTED] totalOut: 0
// [EXPECTED] dust_converter token balance after convert: 1
// [EXPECTED] user gns delta: 0
//
// [SCENARIO] 7. Extreme tick with amount=1000
// [EXPECTED] dust_converter token balance: 1001
// [EXPECTED] totalOut: 997008
// [EXPECTED] dust_converter token balance after convert: 993
// [EXPECTED] user gns delta: 997008
