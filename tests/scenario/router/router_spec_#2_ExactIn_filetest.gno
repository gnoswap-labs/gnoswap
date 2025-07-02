package main

import (
	"std"
	"testing"
	"time"

	"gno.land/r/gnoswap/v1/access"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/v1/gns"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)

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
	println("[SCENARIO] #2 ExactIn Router Test")
	println("[INFO] Starting scenario: Single pool ExactIn swap test")

	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())

	token0Path := "gno.land/r/onbloc/foo"

	println("[INFO] Approving tokens for pool operations")
	foo.Approve(cross, poolAddr, max_approve)
	bar.Approve(cross, poolAddr, max_approve)

	println("[INFO] Creating bar-foo pool (fee: 3000)")
	pl.CreatePool(cross, barPath, token0Path, 3000, "79228162514264337593543950336") // encodePriceSqrt(1, 1)

	println("[INFO] Minting position in bar-foo pool")
	pn.Mint(cross, barPath, token0Path, 3000, min_tick, max_tick, "1000000", "1000000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	pool := pl.GetPool(barPath, token0Path, FEE_MEDIUM)
	poolLiq := pool.Liquidity()
	println("[EXPECTED] pool liquidity:", poolLiq.ToString(), "expected: 1000000")

	println("[INFO] Approving tokens for swap")
	bar.Approve(cross, routerAddr, max_approve)
	foo.Approve(cross, routerAddr, max_approve)

	println("[INFO] Checking balances before swap")
	poolToken0Before := bar.BalanceOf(poolAddr)
	poolToken1Before := foo.BalanceOf(poolAddr)
	user1Token0Before := bar.BalanceOf(adminAddr)
	user1Token1Before := foo.BalanceOf(adminAddr)

	println("[INFO] Pool bar balance:", poolToken0Before)
	println("[INFO] Pool foo balance:", poolToken1Before)
	println("[INFO] admin bar balance:", user1Token0Before)
	println("[INFO] admin foo balance:", user1Token1Before)

	println("[INFO] Executing ExactIn swap (3 bar → foo)")
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		barPath, // inputToken
		fooPath, // outputToken
		"3",     // amountSpecified
		"gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:3000", // strRouteArr
		"100", // quoteArr
		"1",   // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 3")
	println("[EXPECTED] amountOut:", amountOut, "expected: -1")

	println("[INFO] Checking balances after swap")
	poolToken0After := bar.BalanceOf(poolAddr)
	poolToken1After := foo.BalanceOf(poolAddr)
	user1Token0After := bar.BalanceOf(adminAddr)
	user1Token1After := foo.BalanceOf(adminAddr)

	println("[EXPECTED] admin bar balance change:", user1Token0After, "expected:", user1Token0Before+1)
	println("[EXPECTED] admin foo balance change:", user1Token1After, "expected:", user1Token1Before-3)
	println("[EXPECTED] pool bar balance change:", poolToken0After, "expected:", poolToken0Before-1)
	println("[EXPECTED] pool foo balance change:", poolToken1After, "expected:", poolToken1Before+3)

	println("[INFO] Scenario completed")
}

// Output:
// [SCENARIO] #2 ExactIn Router Test
// [INFO] Starting scenario: Single pool ExactIn swap test
// [INFO] Approving pool creation fee
// [INFO] Approving tokens for pool operations
// [INFO] Creating bar-foo pool (fee: 3000)
// [INFO] Minting position in bar-foo pool
// [EXPECTED] pool liquidity: 1000000 expected: 1000000
// [INFO] Approving tokens for swap
// [INFO] Checking balances before swap
// [INFO] Pool bar balance: 1000000
// [INFO] Pool foo balance: 1000000
// [INFO] admin bar balance: 99999999000000
// [INFO] admin foo balance: 99999999000000
// [INFO] Executing ExactIn swap (3 bar → foo)
// [EXPECTED] amountIn: 3 expected: 3
// [EXPECTED] amountOut: -1 expected: -1
// [INFO] Checking balances after swap
// [EXPECTED] admin bar balance change: 99999999000001 expected: 99999999000001
// [EXPECTED] admin foo balance change: 99999998999997 expected: 99999998999997
// [EXPECTED] pool bar balance change: 999999 expected: 999999
// [EXPECTED] pool foo balance change: 1000003 expected: 1000003
// [INFO] Scenario completed
