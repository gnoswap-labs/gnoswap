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
	"gno.land/r/gnoswap/test_token/atone"
	"gno.land/r/gnoswap/test_token/btc"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
	btcPath = "gno.land/r/gnoswap/test_token/btc"

	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

func main() {
	println("[SCENARIO] #3 ExactIn Router Test")
	println("[INFO] Starting scenario: Multi-hop ExactIn swap test (btc → atone → atom)")

	// create pool
	println("[INFO] Setting up pools and positions")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fees")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*2)

	println("[INFO] Creating atom-atone pool (fee: 3000)")
	pl.CreatePool(cross, atomPath, atonePath, 3000, "79228162514264337593543950336")
	println("[INFO] Creating atone-btc pool (fee: 3000)")
	pl.CreatePool(cross, atonePath, btcPath, 3000, "79228162514264337593543950336")

	// position mint
	println("[INFO] Setting position minting permission")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for pool operations")
	atom.Approve(cross, poolAddr, max_approve)
	atone.Approve(cross, poolAddr, max_approve)
	btc.Approve(cross, poolAddr, max_approve)

	println("[INFO] Minting position in atom-atone pool")
	pn.Mint(cross, atomPath, atonePath, uint32(3000), int32(-887220), int32(887220), "1000000", "1000000", "0", "0", max_timeout, adminAddr, "")
	println("[INFO] Minting position in atone-btc pool")
	pn.Mint(cross, atonePath, btcPath, uint32(3000), int32(-887220), int32(887220), "1000000", "1000000", "0", "0", max_timeout, adminAddr, "")

	// exact in swap btc -> atom
	println("[INFO] Approving tokens for swap")
	atom.Approve(cross, routerAddr, 1000000)
	btc.Approve(cross, routerAddr, 1000000)

	println("[INFO] Checking balances before swap")
	token0Before := atom.BalanceOf(adminAddr)
	token2Before := btc.BalanceOf(adminAddr)

	println("[INFO] admin atom balance:", token0Before)
	println("[INFO] admin btc balance:", token2Before)

	println("[INFO] Executing ExactIn swap (5 btc → atone → atom)")
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		btcPath, // inputToken
		atomPath, // outputToken
		"5",     // amountSpecified
		"gno.land/r/gnoswap/test_token/btc:gno.land/r/gnoswap/test_token/atone:3000*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:3000", // strRouteArr
		"100", // quoteArr
		"1",   // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[INFO] Checking balances after swap")
	token0After := atom.BalanceOf(adminAddr)
	token2After := btc.BalanceOf(adminAddr)

	println("[EXPECTED] amountIn:", amountIn, "expected: 5")
	println("[EXPECTED] amountOut:", amountOut, "expected: -1")

	println("[EXPECTED] admin atom balance change:", token0After, "expected:", token0Before+1)
	println("[EXPECTED] admin btc balance change:", token2After, "expected:", token2Before-5)

	println("[INFO] Scenario completed")
}

// Output:
// [SCENARIO] #3 ExactIn Router Test
// [INFO] Starting scenario: Multi-hop ExactIn swap test (btc → atone → atom)
// [INFO] Setting up pools and positions
// [INFO] Approving pool creation fees
// [INFO] Creating atom-atone pool (fee: 3000)
// [INFO] Creating atone-btc pool (fee: 3000)
// [INFO] Setting position minting permission
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in atom-atone pool
// [INFO] Minting position in atone-btc pool
// [INFO] Approving tokens for swap
// [INFO] Checking balances before swap
// [INFO] admin atom balance: 299999999000000
// [INFO] admin btc balance: 2099999999000000
// [INFO] Executing ExactIn swap (5 btc → atone → atom)
// [INFO] Checking balances after swap
// [EXPECTED] amountIn: 5 expected: 5
// [EXPECTED] amountOut: -1 expected: -1
// [EXPECTED] admin atom balance change: 299999999000001 expected: 299999999000001
// [EXPECTED] admin btc balance change: 2099999998999995 expected: 2099999998999995
// [INFO] Scenario completed
