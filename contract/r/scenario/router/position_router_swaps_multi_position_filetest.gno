// position router swaps multi position

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"
)

var t *testing.T

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())
	routerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/router")

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	btcPath = "gno.land/r/gnoswap/test_token/btc"
	fee     = uint32(500)
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint initial position")
	mintPosition(-6930, 6930, 1_000_000_000, 1_000_000_000)
	mintPosition(-6930, 6930, 3_000_000_000, 3_000_000_000)
	mintPosition(-1050, 950, 1_000_000_000, 1_000_000_000)
	mintPosition(-887270, 887270, 5_000_000_000, 5_000_000_000)
	mintPosition(-44260, -19070, 1_000_000_000, 1_000_000_000)
	mintPosition(62160, 69060, 1_000_000_000, 1_000_000_000)
	println()

	testing.SkipHeights(1)

	ufmt.Println("[SCENARIO] 3. Execute exact in swap with almost all")
	executeExactInRouterSwaps()

	ufmt.Println("[SCENARIO] 4. Execute exact out swap with almost all")
	executeExactOutRouterSwaps()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.SetRealm(adminRealm)

	defaultTokenAmount := int64(100_000_000_000_000)

	ufmt.Println("[INFO] Distributing Atom tokens")
	atom.Transfer(cross, aliceAddr, defaultTokenAmount)

	ufmt.Println("[INFO] Distributing Btc tokens")
	btc.Transfer(cross, aliceAddr, defaultTokenAmount)

	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Printf("[INFO] Initial Atom balance of Alice: %d\n", atom.BalanceOf(aliceAddr))
	ufmt.Printf("[INFO] Initial Btc balance of Alice: %d\n", btc.BalanceOf(aliceAddr))

	ufmt.Println("[INFO] Creating pool")
	pool.CreatePool(
		cross,
		atomPath,
		btcPath,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
}

func mintPosition(tickLower, tickUpper int32, token0Amount, token1Amount int64) {
	testing.SetRealm(aliceRealm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting position")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		atomPath,
		btcPath,
		fee,
		tickLower,
		tickUpper,
		ufmt.Sprintf("%d", token0Amount),
		ufmt.Sprintf("%d", token1Amount),
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func executeExactInRouterSwaps() {
	testing.SetRealm(aliceRealm)
	atom.Approve(cross, routerAddr, INT64_MAX)
	btc.Approve(cross, routerAddr, INT64_MAX)

	// set current realm and origin caller
	ufmt.Println("[INFO] Executing first swap BTC -> ATOM")
	poolPath := "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/btc:500"
	ufmt.Printf("[INFO] Pool balance of ATOM: %d\n", pool.GetBalanceToken0(poolPath))
	ufmt.Printf("[INFO] Pool balance of BTC: %d\n", pool.GetBalanceToken1(poolPath))

	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		btcPath,         // inputToken
		atomPath,         // outputToken
		"1000000000000", // amountSpecified
		"gno.land/r/gnoswap/test_token/btc:gno.land/r/gnoswap/test_token/atom:500", // strRouteArr
		"100", // quoteArr
		"1",   // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	ufmt.Printf("[EXPECTED] Swap amountIn should be %s\n", amountIn)
	ufmt.Printf("[EXPECTED] Swap amountOut should be %s\n", amountOut)
}

func executeExactOutRouterSwaps() {
	testing.SetRealm(aliceRealm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	// set current realm and origin caller
	ufmt.Println("[INFO] Executing first swap BTC -> ATOM")
	dryAmountIn, dryAmountOut, success := router.DrySwapRoute(
		btcPath,
		atomPath,
		"10983000000",
		"EXACT_OUT",
		"gno.land/r/gnoswap/test_token/btc:gno.land/r/gnoswap/test_token/atom:500",
		"100",
		"1",
	)

	ufmt.Printf("[EXPECTED] Dry swap amountIn should be %s\n", dryAmountIn)
	ufmt.Printf("[EXPECTED] Dry swap amountOut should be %s\n", dryAmountOut)
	ufmt.Printf("[EXPECTED] Dry swap success should be %T\n", success)

	uassert.AbortsWithMessage(t, "[GNOSWAP-POOL-020] overflow", func() {
		router.ExactOutSwapRoute(
			cross,
			btcPath,       // outputToken
			atomPath,       // inputToken
			"10982000000", // amountSpecified
			"gno.land/r/gnoswap/test_token/btc:gno.land/r/gnoswap/test_token/atom:500", // strRouteArr
			"100", // quoteArr
			"1",   // tokenAmountLimit
			time.Now().Add(time.Hour).Unix(),
			"", // referrer
		)
	})
}

// Output:
// [SCENARIO] 1. Initialize pool
// [INFO] Distributing Atom tokens
// [INFO] Distributing Btc tokens
// [INFO] Initial Atom balance of Alice: 100000000000000
// [INFO] Initial Btc balance of Alice: 100000000000000
// [INFO] Creating pool
//
// [SCENARIO] 2. Mint initial position
// [INFO] Minting position
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 3414963133
// [EXPECTED] Amount0 should be 1000000000
// [EXPECTED] Amount1 should be 1000000000
// [INFO] Minting position
// [EXPECTED] Position ID should be 2
// [EXPECTED] Liquidity should be 10244889400
// [EXPECTED] Amount0 should be 3000000000
// [EXPECTED] Amount1 should be 3000000000
// [INFO] Minting position
// [EXPECTED] Position ID should be 3
// [EXPECTED] Liquidity should be 19552945993
// [EXPECTED] Amount0 should be 907007633
// [EXPECTED] Amount1 should be 1000000000
// [INFO] Minting position
// [EXPECTED] Position ID should be 4
// [EXPECTED] Liquidity should be 5000000000
// [EXPECTED] Amount0 should be 5000000000
// [EXPECTED] Amount1 should be 5000000000
// [INFO] Minting position
// [EXPECTED] Position ID should be 5
// [EXPECTED] Liquidity should be 3622873019
// [EXPECTED] Amount0 should be 0
// [EXPECTED] Amount1 should be 1000000000
// [INFO] Minting position
// [EXPECTED] Position ID should be 6
// [EXPECTED] Liquidity should be 76680150089
// [EXPECTED] Amount0 should be 1000000000
// [EXPECTED] Amount1 should be 0
//
// [SCENARIO] 3. Execute exact in swap with almost all
// [INFO] Executing first swap BTC -> ATOM
// [INFO] Pool balance of ATOM: 10907007633
// [INFO] Pool balance of BTC: 11000000000
// [EXPECTED] Swap amountIn should be 1000000000000
// [EXPECTED] Swap amountOut should be -10804908355
// [SCENARIO] 4. Execute exact out swap with almost all
// [INFO] Executing first swap BTC -> ATOM
// [EXPECTED] Dry swap amountIn should be 0
// [EXPECTED] Dry swap amountOut should be 0
// [EXPECTED] Dry swap success should be bool
