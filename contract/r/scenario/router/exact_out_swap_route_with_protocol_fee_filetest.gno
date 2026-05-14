package main

import (
	"testing"
	"time"

	"gno.land/r/gnoswap/access"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	btcPath = "gno.land/r/gnoswap/test_token/btc"

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

	println("[SCENARIO] 2. Create Pool And Mint Position (gno.land/r/gnoswap/test_token/btc:gno.land/r/gnoswap/test_token/atom:3000)")
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
	println("[INFO] Creating atom-btc pool (fee: 3000)")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for pool operations")
	btc.Approve(cross, poolAddr, max_approve)
	atom.Approve(cross, poolAddr, max_approve)

	println("[INFO] Creating atom-btc pool (fee: 3000)")
	pl.CreatePool(cross, atomPath, btcPath, 3000, "79228162514264337593543950336") // encodePriceSqrt(1, 1)
}

func mintPosition() {
	println("[INFO] Minting position in atom-btc pool")
	testing.SetRealm(adminRealm)

	pn.Mint(cross, atomPath, btcPath, 3000, min_tick, max_tick, "100000000", "100000000", "0", "0", max_timeout, adminAddr, "")

	pool, _ := pl.GetPool(atomPath, btcPath, FEE_MEDIUM)
	poolLiq := pool.Liquidity()
	println("[EXPECTED] pool liquidity:", poolLiq.ToString(), "expected: 100000000")
}

func swapRouteWithBalanceCheck() {
	println("[INFO] Executing ExactOut swap")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	atom.Approve(cross, routerAddr, max_approve)
	btc.Approve(cross, routerAddr, max_approve)

	println("[INFO] Checking balances before swap")
	poolToken0Before := atom.BalanceOf(poolAddr)
	poolToken1Before := btc.BalanceOf(poolAddr)
	user1Token0Before := atom.BalanceOf(adminAddr)
	user1Token1Before := btc.BalanceOf(adminAddr)
	protocolFeeToken0Before := atom.BalanceOf(protocolFeeAddr)
	protocolFeeToken1Before := btc.BalanceOf(protocolFeeAddr)

	println("[INFO] Pool atom balance:", poolToken0Before)
	println("[INFO] Pool btc balance:", poolToken1Before)
	println("[INFO] admin atom balance:", user1Token0Before)
	println("[INFO] admin btc balance:", user1Token1Before)
	println("[INFO] protocol fee atom balance:", protocolFeeToken0Before)
	println("[INFO] protocol fee btc balance:", protocolFeeToken1Before)

	println("[INFO] Executing ExactOut swap")
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		btcPath,   // inputToken
		atomPath,   // outputToken
		"1000000", // amountSpecified
		"gno.land/r/gnoswap/test_token/btc:gno.land/r/gnoswap/test_token/atom:3000", // strRouteArr
		"100",                 // quoteArr
		"9223372036854775807", // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	poolToken0After := atom.BalanceOf(poolAddr)
	poolToken1After := btc.BalanceOf(poolAddr)
	user1Token0After := atom.BalanceOf(adminAddr)
	user1Token1After := btc.BalanceOf(adminAddr)
	protocolFeeToken0After := atom.BalanceOf(protocolFeeAddr)
	protocolFeeToken1After := btc.BalanceOf(protocolFeeAddr)

	println("[EXPECTED] amountIn:", amountIn)
	println("[EXPECTED] amountOut:", amountOut)
	println("[EXPECTED] admin atom balance change:", user1Token0After-user1Token0Before)
	println("[EXPECTED] admin btc balance change:", user1Token1After-user1Token1Before)
	println("[EXPECTED] pool atom balance change:", poolToken0After-poolToken0Before)
	println("[EXPECTED] pool btc balance change:", poolToken1After-poolToken1Before)
	println("[EXPECTED] protocol fee atom balance change:", protocolFeeToken0After-protocolFeeToken0Before)
	println("[EXPECTED] protocol fee btc balance change:", protocolFeeToken1After-protocolFeeToken1Before)
}

// Output:
// [SCENARIO] 1. Initialize Setup
// [INFO] Starting scenario: Single pool ExactIn swap test
// [INFO] Approving pool creation fee
//
// [SCENARIO] 2. Create Pool And Mint Position (gno.land/r/gnoswap/test_token/btc:gno.land/r/gnoswap/test_token/atom:3000)
// [INFO] Creating atom-btc pool (fee: 3000)
// [INFO] Approving tokens for pool operations
// [INFO] Creating atom-btc pool (fee: 3000)
// [INFO] Minting position in atom-btc pool
// [EXPECTED] pool liquidity: 100000000 expected: 100000000
//
// [SCENARIO] 3. Swap Route With Balance Check
// [INFO] Executing ExactOut swap
// [INFO] Approving tokens for swap
// [INFO] Checking balances before swap
// [INFO] Pool atom balance: 100000000
// [INFO] Pool btc balance: 100000000
// [INFO] admin atom balance: 299999900000000
// [INFO] admin btc balance: 2099999900000000
// [INFO] protocol fee atom balance: 0
// [INFO] protocol fee btc balance: 0
// [INFO] Executing ExactOut swap
// [EXPECTED] amountIn: 1014679
// [EXPECTED] amountOut: -1000000
// [EXPECTED] admin atom balance change: 1000000
// [EXPECTED] admin btc balance change: -1014679
// [EXPECTED] pool atom balance change: -1001502
// [EXPECTED] pool btc balance change: 1014679
// [EXPECTED] protocol fee atom balance change: 1502
// [EXPECTED] protocol fee btc balance change: 0
