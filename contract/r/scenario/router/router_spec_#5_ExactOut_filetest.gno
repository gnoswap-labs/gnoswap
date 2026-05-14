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

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
	btcPath = "gno.land/r/gnoswap/test_token/btc"
	solPath = "gno.land/r/gnoswap/test_token/sol"

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

	println("[INFO] Creating atom-atone pool (fee: 3000)")
	pl.CreatePool(cross, atomPath, atonePath, 3000, "79228162514264337593543950336")

	println("[INFO] Approving tokens for pool operations")
	atom.Approve(cross, poolAddr, max_approve)
	atone.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in atom-atone pool")
	pn.Mint(cross, atomPath, atonePath, uint32(3000), int32(-887220), int32(887220), "1000000", "1000000", "0", "0", max_timeout, adminAddr, "")

	println("[INFO] Approving tokens for swap")
	atom.Approve(cross, routerAddr, 1000000)
	atone.Approve(cross, routerAddr, 1000000)

	println("[INFO] Checking balances before swap")
	token0Before := atom.BalanceOf(adminAddr)
	token1Before := atone.BalanceOf(adminAddr)

	println("[INFO] admin atom balance:", token0Before)
	println("[INFO] admin atone balance:", token1Before)

	println("[INFO] Executing ExactOut swap (atom → 1 atone)")
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		atomPath, // inputToken
		atonePath, // outputToken
		"1",     // amountSpecified
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:3000", // strRouteArr
		"100", // quoteArr
		"3",   // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[INFO] Checking balances after swap")
	token0After := atom.BalanceOf(adminAddr)
	token1After := atone.BalanceOf(adminAddr)

	println("[EXPECTED] amountIn:", amountIn, "expected: 3")
	println("[EXPECTED] amountOut:", amountOut, "expected: -1")

	println("[EXPECTED] admin atom balance change:", token0After, "expected:", token0Before-3)
	println("[EXPECTED] admin atone balance change:", token1After, "expected:", token1Before+1)

	println("[INFO] Scenario completed")
}

// Output:
// [SCENARIO] #5 ExactOut Router Test
// [INFO] Starting scenario: Single pool ExactOut swap test
// [INFO] Setting up pool and position
// [INFO] Approving pool creation fee
// [INFO] Creating atom-atone pool (fee: 3000)
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in atom-atone pool
// [INFO] Approving tokens for swap
// [INFO] Checking balances before swap
// [INFO] admin atom balance: 299999999000000
// [INFO] admin atone balance: 139999999000000
// [INFO] Executing ExactOut swap (atom → 1 atone)
// [INFO] Checking balances after swap
// [EXPECTED] amountIn: 3 expected: 3
// [EXPECTED] amountOut: -1 expected: -1
// [EXPECTED] admin atom balance change: 299999998999997 expected: 299999998999997
// [EXPECTED] admin atone balance change: 139999999000001 expected: 139999999000001
// [INFO] Scenario completed
