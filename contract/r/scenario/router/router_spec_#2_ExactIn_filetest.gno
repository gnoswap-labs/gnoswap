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

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

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
	println("[SCENARIO] #2 ExactIn Router Test")
	println("[INFO] Starting scenario: Single pool ExactIn swap test")

	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())

	token0Path := "gno.land/r/gnoswap/test_token/btc"

	println("[INFO] Approving tokens for pool operations")
	btc.Approve(cross, poolAddr, max_approve)
	atom.Approve(cross, poolAddr, max_approve)

	println("[INFO] Creating atom-btc pool (fee: 3000)")
	pl.CreatePool(cross, atomPath, token0Path, 3000, "79228162514264337593543950336") // encodePriceSqrt(1, 1)

	println("[INFO] Minting position in atom-btc pool")
	pn.Mint(cross, atomPath, token0Path, 3000, min_tick, max_tick, "1000000", "1000000", "0", "0", max_timeout, adminAddr, "")

	pool, _ := pl.GetPool(atomPath, token0Path, FEE_MEDIUM)
	poolLiq := pool.Liquidity()
	println("[EXPECTED] pool liquidity:", poolLiq.ToString(), "expected: 1000000")

	println("[INFO] Approving tokens for swap")
	atom.Approve(cross, routerAddr, max_approve)
	btc.Approve(cross, routerAddr, max_approve)

	println("[INFO] Checking balances before swap")
	poolToken0Before := atom.BalanceOf(poolAddr)
	poolToken1Before := btc.BalanceOf(poolAddr)
	user1Token0Before := atom.BalanceOf(adminAddr)
	user1Token1Before := btc.BalanceOf(adminAddr)

	println("[INFO] Pool atom balance:", poolToken0Before)
	println("[INFO] Pool btc balance:", poolToken1Before)
	println("[INFO] admin atom balance:", user1Token0Before)
	println("[INFO] admin btc balance:", user1Token1Before)

	println("[INFO] Executing ExactIn swap (3 atom → btc)")
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		btcPath, // inputToken
		atomPath, // outputToken
		"3",     // amountSpecified
		"gno.land/r/gnoswap/test_token/btc:gno.land/r/gnoswap/test_token/atom:3000", // strRouteArr
		"100", // quoteArr
		"1",   // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 3")
	println("[EXPECTED] amountOut:", amountOut, "expected: -1")

	println("[INFO] Checking balances after swap")
	poolToken0After := atom.BalanceOf(poolAddr)
	poolToken1After := btc.BalanceOf(poolAddr)
	user1Token0After := atom.BalanceOf(adminAddr)
	user1Token1After := btc.BalanceOf(adminAddr)

	println("[EXPECTED] admin atom balance change:", user1Token0After, "expected:", user1Token0Before+1)
	println("[EXPECTED] admin btc balance change:", user1Token1After, "expected:", user1Token1Before-3)
	println("[EXPECTED] pool atom balance change:", poolToken0After, "expected:", poolToken0Before-1)
	println("[EXPECTED] pool btc balance change:", poolToken1After, "expected:", poolToken1Before+3)

	println("[INFO] Scenario completed")
}

// Output:
// [SCENARIO] #2 ExactIn Router Test
// [INFO] Starting scenario: Single pool ExactIn swap test
// [INFO] Approving pool creation fee
// [INFO] Approving tokens for pool operations
// [INFO] Creating atom-btc pool (fee: 3000)
// [INFO] Minting position in atom-btc pool
// [EXPECTED] pool liquidity: 1000000 expected: 1000000
// [INFO] Approving tokens for swap
// [INFO] Checking balances before swap
// [INFO] Pool atom balance: 1000000
// [INFO] Pool btc balance: 1000000
// [INFO] admin atom balance: 299999999000000
// [INFO] admin btc balance: 2099999999000000
// [INFO] Executing ExactIn swap (3 atom → btc)
// [EXPECTED] amountIn: 3 expected: 3
// [EXPECTED] amountOut: -1 expected: -1
// [INFO] Checking balances after swap
// [EXPECTED] admin atom balance change: 299999999000001 expected: 299999999000001
// [EXPECTED] admin btc balance change: 2099999998999997 expected: 2099999998999997
// [EXPECTED] pool atom balance change: 999999 expected: 999999
// [EXPECTED] pool btc balance change: 1000003 expected: 1000003
// [INFO] Scenario completed
