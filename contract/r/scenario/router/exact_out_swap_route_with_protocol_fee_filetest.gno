package main

import (
	"testing"
	"time"

	"gno.land/r/gnoswap/access"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	min_tick    int32 = -887220
	max_tick    int32 = 887220
	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

const (
	FEE_MEDIUM uint32 = 3000
)

func main() {
	println("[SCENARIO] 1. Initialize Setup")
	initializeSetup()
	println()

	println("[SCENARIO] 2. Create Pool And Mint Position (gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:3000)")
	createPool()
	mintPosition()
	println()

	println("[SCENARIO] 3. Swap Route With Balance Check")
	swapRouteWithBalanceCheck()
	println()
}

func initializeSetup() {
	println("[INFO] Starting scenario: Single pool ExactIn swap test")

	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
}

func createPool() {
	println("[INFO] Creating bar-foo pool (fee: 3000)")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for pool operations")
	foo.Approve(cross, poolAddr, max_approve)
	bar.Approve(cross, poolAddr, max_approve)

	println("[INFO] Creating bar-foo pool (fee: 3000)")
	pl.CreatePool(cross, barPath, fooPath, 3000, "79228162514264337593543950336") // encodePriceSqrt(1, 1)
}

func mintPosition() {
	println("[INFO] Minting position in bar-foo pool")
	testing.SetRealm(adminRealm)

	pn.Mint(cross, barPath, fooPath, 3000, min_tick, max_tick, "100000000", "100000000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	pool := pl.GetPool(barPath, fooPath, FEE_MEDIUM)
	poolLiq := pool.Liquidity()
	println("[EXPECTED] pool liquidity:", poolLiq.ToString(), "expected: 100000000")
}

func swapRouteWithBalanceCheck() {
	println("[INFO] Executing ExactOut swap")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	bar.Approve(cross, routerAddr, max_approve)
	foo.Approve(cross, routerAddr, max_approve)

	println("[INFO] Checking balances before swap")
	poolToken0Before := bar.BalanceOf(poolAddr)
	poolToken1Before := foo.BalanceOf(poolAddr)
	user1Token0Before := bar.BalanceOf(adminAddr)
	user1Token1Before := foo.BalanceOf(adminAddr)
	protocolFeeToken0Before := bar.BalanceOf(protocolFeeAddr)
	protocolFeeToken1Before := foo.BalanceOf(protocolFeeAddr)

	println("[INFO] Pool bar balance:", poolToken0Before)
	println("[INFO] Pool foo balance:", poolToken1Before)
	println("[INFO] admin bar balance:", user1Token0Before)
	println("[INFO] admin foo balance:", user1Token1Before)
	println("[INFO] protocol fee bar balance:", protocolFeeToken0Before)
	println("[INFO] protocol fee foo balance:", protocolFeeToken1Before)

	println("[INFO] Executing ExactOut swap")
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		fooPath,   // inputToken
		barPath,   // outputToken
		"1000000", // amountSpecified
		"gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:3000", // strRouteArr
		"100",                 // quoteArr
		"9223372036854775807", // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	poolToken0After := bar.BalanceOf(poolAddr)
	poolToken1After := foo.BalanceOf(poolAddr)
	user1Token0After := bar.BalanceOf(adminAddr)
	user1Token1After := foo.BalanceOf(adminAddr)
	protocolFeeToken0After := bar.BalanceOf(protocolFeeAddr)
	protocolFeeToken1After := foo.BalanceOf(protocolFeeAddr)

	println("[EXPECTED] amountIn:", amountIn)
	println("[EXPECTED] amountOut:", amountOut)
	println("[EXPECTED] admin bar balance change:", user1Token0After-user1Token0Before)
	println("[EXPECTED] admin foo balance change:", user1Token1After-user1Token1Before)
	println("[EXPECTED] pool bar balance change:", poolToken0After-poolToken0Before)
	println("[EXPECTED] pool foo balance change:", poolToken1After-poolToken1Before)
	println("[EXPECTED] protocol fee bar balance change:", protocolFeeToken0After-protocolFeeToken0Before)
	println("[EXPECTED] protocol fee foo balance change:", protocolFeeToken1After-protocolFeeToken1Before)
}

// Output:
// [SCENARIO] 1. Initialize Setup
// [INFO] Starting scenario: Single pool ExactIn swap test
// [INFO] Approving pool creation fee
//
// [SCENARIO] 2. Create Pool And Mint Position (gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:3000)
// [INFO] Creating bar-foo pool (fee: 3000)
// [INFO] Approving tokens for pool operations
// [INFO] Creating bar-foo pool (fee: 3000)
// [INFO] Minting position in bar-foo pool
// [EXPECTED] pool liquidity: 100000000 expected: 100000000
//
// [SCENARIO] 3. Swap Route With Balance Check
// [INFO] Executing ExactOut swap
// [INFO] Approving tokens for swap
// [INFO] Checking balances before swap
// [INFO] Pool bar balance: 100000000
// [INFO] Pool foo balance: 100000000
// [INFO] admin bar balance: 99999900000000
// [INFO] admin foo balance: 99999900000000
// [INFO] protocol fee bar balance: 0
// [INFO] protocol fee foo balance: 0
// [INFO] Executing ExactOut swap
// [EXPECTED] amountIn: 1013142
// [EXPECTED] amountOut: -998500
// [EXPECTED] admin bar balance change: 998500
// [EXPECTED] admin foo balance change: -1013142
// [EXPECTED] pool bar balance change: -1000000
// [EXPECTED] pool foo balance change: 1013142
// [EXPECTED] protocol fee bar balance change: 1500
// [EXPECTED] protocol fee foo balance change: 0
