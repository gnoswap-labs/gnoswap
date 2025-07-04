package main

import (
	"std"
	"testing"
	"time"

	"gno.land/r/gnoswap/v1/access"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"

	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	fooPath = "gno.land/r/onbloc/foo"
	quxPath = "gno.land/r/onbloc/qux"

	min_tick    int32 = -887220
	max_tick    int32 = 887220
	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

const (
	FEE_MEDIUM uint32 = 3000
)

func main() {
	println("[SCENARIO] #5 ExactOut Router Test")
	println("[INFO] Starting scenario: Single pool ExactOut swap test")

	println("[INFO] Setting up pool and position")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*2)

	println("[INFO] Creating bar-baz pool (fee: 3000)")
	pl.CreatePool(cross, barPath, bazPath, 3000, "79228162514264337593543950336")

	println("[INFO] Approving tokens for pool operations")
	bar.Approve(cross, poolAddr, max_approve)
	baz.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in bar-baz pool")
	pn.Mint(cross, barPath, bazPath, uint32(3000), int32(-887220), int32(887220), "1000000", "1000000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	println("[INFO] Approving tokens for swap")
	bar.Approve(cross, routerAddr, 1000000)
	baz.Approve(cross, routerAddr, 1000000)

	println("[INFO] Checking balances before swap")
	token0Before := bar.BalanceOf(adminAddr)
	token1Before := baz.BalanceOf(adminAddr)

	println("[INFO] admin bar balance:", token0Before)
	println("[INFO] admin baz balance:", token1Before)

	println("[INFO] Executing ExactOut swap (bar → 1 baz)")
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		barPath, // inputToken
		bazPath, // outputToken
		"1",     // amountSpecified
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000", // strRouteArr
		"100", // quoteArr
		"3",   // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[INFO] Checking balances after swap")
	token0After := bar.BalanceOf(adminAddr)
	token1After := baz.BalanceOf(adminAddr)

	println("[EXPECTED] amountIn:", amountIn, "expected: 3")
	println("[EXPECTED] amountOut:", amountOut, "expected: -1")

	println("[EXPECTED] admin bar balance change:", token0After, "expected:", token0Before-3)
	println("[EXPECTED] admin baz balance change:", token1After, "expected:", token1Before+1)

	println("[INFO] Scenario completed")
}

// Output:
// [SCENARIO] #5 ExactOut Router Test
// [INFO] Starting scenario: Single pool ExactOut swap test
// [INFO] Setting up pool and position
// [INFO] Approving pool creation fee
// [INFO] Creating bar-baz pool (fee: 3000)
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in bar-baz pool
// [INFO] Approving tokens for swap
// [INFO] Checking balances before swap
// [INFO] admin bar balance: 99999999000000
// [INFO] admin baz balance: 99999999000000
// [INFO] Executing ExactOut swap (bar → 1 baz)
// [INFO] Checking balances after swap
// [EXPECTED] amountIn: 3 expected: 3
// [EXPECTED] amountOut: -1 expected: -1
// [EXPECTED] admin bar balance change: 99999998999997 expected: 99999998999997
// [EXPECTED] admin baz balance change: 99999999000001 expected: 99999999000001
// [INFO] Scenario completed
