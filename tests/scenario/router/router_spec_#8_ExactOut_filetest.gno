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
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	fooPath = "gno.land/r/onbloc/foo"

	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

func main() {
	println("[SCENARIO] #8 ExactOut Router Test")
	println("[INFO] Starting scenario: Multi-hop ExactOut swap test (foo → baz → bar)")

	println("[INFO] Setting up pools and positions")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*2)

	println("[INFO] Creating bar-baz pool (fee: 3000)")
	pl.CreatePool(cross, barPath, bazPath, 3000, "79228162514264337593543950336")
	println("[INFO] Creating baz-foo pool (fee: 3000)")
	pl.CreatePool(cross, bazPath, fooPath, 3000, "79228162514264337593543950336")

	println("[INFO] Approving tokens for pool operations")
	bar.Approve(cross, poolAddr, max_approve)
	baz.Approve(cross, poolAddr, max_approve)
	foo.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in bar-baz pool")
	pn.Mint(cross, barPath, bazPath, uint32(3000), int32(-887220), int32(887220), "1000000", "1000000", "0", "0", max_timeout, adminAddr, adminAddr, "")
	println("[INFO] Minting position in baz-foo pool")
	pn.Mint(cross, bazPath, fooPath, uint32(3000), int32(-887220), int32(887220), "1000000", "1000000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	println("[INFO] Approving tokens for swap")
	bar.Approve(cross, routerAddr, 1000000)
	foo.Approve(cross, routerAddr, 1000000)

	println("[INFO] Checking balances before swap")
	token0Before := bar.BalanceOf(adminAddr)
	token2Before := foo.BalanceOf(adminAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		fooPath, // inputToken
		barPath, // outputToken
		"1",     // amountSpecified
		"gno.land/r/onbloc/foo:gno.land/r/onbloc/baz:3000*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:3000", // strRouteArr
		"100", // quoteArr
		"5",   // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	token0After := bar.BalanceOf(adminAddr)
	token2After := foo.BalanceOf(adminAddr)

	println("[EXPECTED] amountIn:", amountIn, "expected: 5")
	println("[EXPECTED] amountOut:", amountOut, "expected: -1")

	println("[EXPECTED] admin bar balance change:", token0After, "expected:", token0Before+1)
	println("[EXPECTED] admin foo balance change:", token2After, "expected:", token2Before-5)

	println("[INFO] Scenario completed")
}

// Output:
// [SCENARIO] #8 ExactOut Router Test
// [INFO] Starting scenario: Multi-hop ExactOut swap test (foo → baz → bar)
// [INFO] Setting up pools and positions
// [INFO] Approving pool creation fee
// [INFO] Creating bar-baz pool (fee: 3000)
// [INFO] Creating baz-foo pool (fee: 3000)
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in bar-baz pool
// [INFO] Minting position in baz-foo pool
// [INFO] Approving tokens for swap
// [INFO] Checking balances before swap
// [EXPECTED] amountIn: 5 expected: 5
// [EXPECTED] amountOut: -1 expected: -1
// [EXPECTED] admin bar balance change: 99999999000001 expected: 99999999000001
// [EXPECTED] admin foo balance change: 99999998999995 expected: 99999998999995
// [INFO] Scenario completed
