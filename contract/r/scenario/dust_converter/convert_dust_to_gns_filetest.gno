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
	adminAddr  = access.MustGetAddress(prabc.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	poolAddr = access.MustGetAddress(prabc.ROLE_POOL.String())

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
	println("[SCENARIO] Claim dust via dust_converter")
	println()

	println("[SCENARIO] 1. Setup pools and liquidity")
	setupPools()
	println()

	println("[SCENARIO] 2. Transfer dust to dust_converter")
	setupDustBalances()
	println()

	println("[SCENARIO] 3. Convert dust to GNS")
	convertDust()
	println()
}

func setupPools() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	createPool(barPath, gnsPath, feeTier)
	createPool(bazPath, gnsPath, feeTier)

	bar.Approve(cross, poolAddr, 1_000_000_000)
	baz.Approve(cross, poolAddr, 1_000_000_000)
	gns.Approve(cross, poolAddr, 1_000_000_000)

	mintPosition(barPath, gnsPath, feeTier, "1000000", "1000000")
	mintPosition(bazPath, gnsPath, feeTier, "1000000", "1000000")
}

func createPool(token0Path, token1Path string, fee uint32) {
	poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
	if pool.ExistsPoolPath(poolPath) {
		return
	}

	pool.CreatePool(
		cross,
		token0Path,
		token1Path,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
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

func setupDustBalances() {
	testing.SetRealm(adminRealm)

	println("[INFO] Transferring bar dust to dust_converter")
	bar.Transfer(cross, dustConverterAddr, 3)
	println("[INFO] Transferring baz dust to dust_converter")
	baz.Transfer(cross, dustConverterAddr, 4)
	println("[INFO] Transferring gns dust to dust_converter")
	gns.Transfer(cross, dustConverterAddr, 2)

	println("[EXPECTED] dust_converter bar balance:", bar.BalanceOf(dustConverterAddr))
	println("[EXPECTED] dust_converter baz balance:", baz.BalanceOf(dustConverterAddr))
	println("[EXPECTED] dust_converter gns balance:", gns.BalanceOf(dustConverterAddr))
}

func convertDust() {
	testing.SetRealm(userRealm)

	beforeUserGns := gns.BalanceOf(userAddr)
	totalGnsOut := dc.ConvertDustToGns(
		cross,
		barPath+":3,"+bazPath+":4,"+gnsPath+":2",
		time.Now().Add(time.Hour).Unix(),
		userAddr,
	)

	println("[EXPECTED] totalGnsOut:", totalGnsOut)
	println("[EXPECTED] dust_converter bar balance after convert:", bar.BalanceOf(dustConverterAddr))
	println("[EXPECTED] dust_converter baz balance after convert:", baz.BalanceOf(dustConverterAddr))
	println("[EXPECTED] dust_converter gns balance after convert:", gns.BalanceOf(dustConverterAddr))
	println("[EXPECTED] user gns delta:", gns.BalanceOf(userAddr)-beforeUserGns)
}

// Output:
// [SCENARIO] Claim dust via dust_converter
//
// [SCENARIO] 1. Setup pools and liquidity
// [EXPECTED] created pool: gno.land/r/gnoswap/gns:gno.land/r/onbloc/bar:500
// [EXPECTED] created pool: gno.land/r/gnoswap/gns:gno.land/r/onbloc/baz:500
// [EXPECTED] liquidity: 3858461 amount0: 1000000 amount1: 1000000
// [EXPECTED] liquidity: 3858461 amount0: 1000000 amount1: 1000000
//
// [SCENARIO] 2. Transfer dust to dust_converter
// [INFO] Transferring bar dust to dust_converter
// [INFO] Transferring baz dust to dust_converter
// [INFO] Transferring gns dust to dust_converter
// [EXPECTED] dust_converter bar balance: 3
// [EXPECTED] dust_converter baz balance: 4
// [EXPECTED] dust_converter gns balance: 2
//
// [SCENARIO] 3. Convert dust to GNS
// [EXPECTED] totalGnsOut: 5
// [EXPECTED] dust_converter bar balance after convert: 0
// [EXPECTED] dust_converter baz balance after convert: 0
// [EXPECTED] dust_converter gns balance after convert: 0
// [EXPECTED] user gns delta: 5
