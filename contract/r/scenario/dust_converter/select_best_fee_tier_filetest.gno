// PKGPATH: gno.land/r/demo/main
package main

import (
	"strconv"
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
	gnsPath = "gno.land/r/gnoswap/gns"

	feeLow  uint32 = 500
	feeHigh uint32 = 3000
)

func main() {
	println("[SCENARIO] Select best fee tier by liquidity")
	println()

	println("[SCENARIO] 1. Setup pools with different liquidity")
	setupPools()
	println()

	println("[SCENARIO] 2. Convert dust and verify selected tier")
	convertAndVerify()
	println()
}

func setupPools() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	createPool(barPath, gnsPath, feeLow)
	createPool(barPath, gnsPath, feeHigh)

	bar.Approve(cross, poolAddr, 1_000_000_000)
	gns.Approve(cross, poolAddr, 1_000_000_000)

	mintPosition(barPath, gnsPath, feeLow, "1000", "1000")
	mintPosition(barPath, gnsPath, feeHigh, "1000000", "1000000")
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
	ufmt.Printf("[EXPECTED] fee:%d liquidity:%s amount0:%s amount1:%s\n", fee, liquidity, amt0, amt1)
}

func convertAndVerify() {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, dustConverterAddr, 1000)

	lowPath := pool.GetPoolPath(barPath, gnsPath, feeLow)
	highPath := pool.GetPoolPath(barPath, gnsPath, feeHigh)

	lowBefore0, lowBefore1 := getBalances(lowPath)
	highBefore0, highBefore1 := getBalances(highPath)

	testing.SetRealm(userRealm)
	totalGnsOut := dc.ConvertDustToGns(
		cross,
		gnsPath,
		barPath+":1000",
		time.Now().Add(time.Hour).Unix(),
		userAddr,
	)

	lowAfter0, lowAfter1 := getBalances(lowPath)
	highAfter0, highAfter1 := getBalances(highPath)

	println("[EXPECTED] totalGnsOut:", totalGnsOut)
	println("[EXPECTED] low fee pool delta0:", lowAfter0-lowBefore0, "delta1:", lowAfter1-lowBefore1)
	println("[EXPECTED] high fee pool delta0:", highAfter0-highBefore0, "delta1:", highAfter1-highBefore1)
}

func getBalances(poolPath string) (int64, int64) {
	b0, b1 := pool.GetBalances(poolPath)
	v0, err := strconv.ParseInt(b0, 10, 64)
	if err != nil {
		panic(err)
	}
	v1, err := strconv.ParseInt(b1, 10, 64)
	if err != nil {
		panic(err)
	}
	return v0, v1
}

// Output:
// [SCENARIO] Select best fee tier by liquidity
//
// [SCENARIO] 1. Setup pools with different liquidity
// [EXPECTED] created pool: gno.land/r/gnoswap/gns:gno.land/r/onbloc/bar:500
// [EXPECTED] created pool: gno.land/r/gnoswap/gns:gno.land/r/onbloc/bar:3000
// [EXPECTED] fee:500 liquidity:3858 amount0:1000 amount1:1000
// [EXPECTED] fee:3000 liquidity:3858461 amount0:1000000 amount1:1000000
//
// [SCENARIO] 2. Convert dust and verify selected tier
// [EXPECTED] totalGnsOut: 995
// [EXPECTED] low fee pool delta0: 0 delta1: 0
// [EXPECTED] high fee pool delta0: -996 delta1: 1000
