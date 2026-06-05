// exact out swap route with single route

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"gno.land/p/gnoswap/gnsmath"
	"chain"
	"testing"

	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoland/wugnot"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	wugnotPath = "gno.land/r/gnoland/wugnot"
	gnsPath    = "gno.land/r/gnoswap/gns"

	maxInt64 int64 = 9223372036854775807
)

var t *testing.T

func main(cur realm) {
	println("[SCENARIO] 1. Initialize Setup")
	testing.SetRealm(adminRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 100000000000000}})
	wugnot.Deposit(cross(cur))
	testing.SetOriginSend(chain.Coins{})
	initializeSetup(cur)

	println("[SCENARIO] 2. Create Pool And Mint Position (gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500)")
	createPool(cur, wugnotPath, gnsPath, 500, 0)
	mintPosition(cur, wugnotPath, gnsPath, 500, -6960, 6960, "100000000", "100000000")
	println()

	println("[SCENARIO] 3. Create Pool And Mint Position (gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000)")
	createPool(cur, wugnotPath, gnsPath, 3000, 100)
	mintPosition(cur, wugnotPath, gnsPath, 500, -6960, 6960, "100000000", "100000000")
	println()

	println("[SCENARIO] 4. Create Pool And Mint Position (gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:10000)")
	createPool(cur, wugnotPath, gnsPath, 10000, -100)
	mintPosition(cur, wugnotPath, gnsPath, 500, -6960, 6960, "100000000", "100000000")
	println()

	println("[SCENARIO] 5. ExactOutSwapRoute")
	exactOutSwapRouteBy(cur,
		wugnotPath,
		gnsPath,
		"1001502",
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500",
		"100",
		"10000000",
	)
	println()
}

func initializeSetup(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)

	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 100000000000000}})

	println("[INFO] GNS Balance of admin:", gns.BalanceOf(adminAddr))
	println("[INFO] WUGNOT Balance of admin:", wugnot.BalanceOf(adminAddr))

	gns.Approve(cross(cur), poolAddr, maxInt64)
	wugnot.Approve(cross(cur), poolAddr, maxInt64)
	gns.Approve(cross(cur), routerAddr, maxInt64)
	wugnot.Approve(cross(cur), routerAddr, maxInt64)
}

func createPool(cur realm, token0Path string, token1Path string, fee uint32, startTick int32) {
	testing.SetRealm(adminRealm)
	pool.CreatePool(
		cross(cur),
		token0Path,
		token1Path,
		fee,
		gnsmath.TickMathGetSqrtRatioAtTick(startTick).ToString(),
	)

	ufmt.Printf("[EXPECTED] created %s:%s:%d pool at tick %d\n", token0Path, token1Path, fee, startTick)
}

func mintPosition(cur realm, token0Path string, token1Path string, fee uint32, minTick, maxTick int32, amount0 string, amount1 string) {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Minting position")
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross(cur),
		wugnotPath,
		gnsPath,
		fee,
		minTick,
		maxTick,
		amount0,
		amount1,
		"0",
		"0",
		9999999999,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] positionId: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s\n", amount0)
	ufmt.Printf("[EXPECTED] amount1: %s\n", amount1)
}

func exactOutSwapRouteBy(cur realm,
	inputToken string,
	outputToken string,
	specifiedAmount string,
	routeQueryString string,
	queryRatios string,
	amountInMax string,
) {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] ExactOutSwapRoute")
	ufmt.Println("[INFO] inputToken:", inputToken)
	ufmt.Println("[INFO] outputToken:", outputToken)
	ufmt.Println("[INFO] specifiedAmount:", specifiedAmount)
	ufmt.Println("[INFO] routeQueryString:", routeQueryString)
	ufmt.Println("[INFO] queryRatios:", queryRatios)
	ufmt.Println("[INFO] amountInMax:", amountInMax)

	inputTokenAmount, outputTokenAmount := router.ExactOutSwapRoute(
		cross(cur),
		inputToken,
		outputToken,
		specifiedAmount,
		routeQueryString,
		queryRatios,
		amountInMax,
		int64(9999999999),
		"",
	)

	ufmt.Printf("[EXPECTED] inputTokenAmount: %s\n", inputTokenAmount)
	ufmt.Printf("[EXPECTED] outputTokenAmount: %s\n", outputTokenAmount)
}

// Output:
// [SCENARIO] 1. Initialize Setup
// [INFO] GNS Balance of admin: 100000000000000
// [INFO] WUGNOT Balance of admin: 100000000000000
// [SCENARIO] 2. Create Pool And Mint Position (gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500)
// [EXPECTED] created gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500 pool at tick 0
// [INFO] Minting position
// [EXPECTED] positionId: 1
// [EXPECTED] liquidity: 340264708
// [EXPECTED] amount0: 100000000
// [EXPECTED] amount1: 100000000
//
// [SCENARIO] 3. Create Pool And Mint Position (gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000)
// [EXPECTED] created gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000 pool at tick 100
// [INFO] Minting position
// [EXPECTED] positionId: 2
// [EXPECTED] liquidity: 340264708
// [EXPECTED] amount0: 100000000
// [EXPECTED] amount1: 100000000
//
// [SCENARIO] 4. Create Pool And Mint Position (gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:10000)
// [EXPECTED] created gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:10000 pool at tick -100
// [INFO] Minting position
// [EXPECTED] positionId: 3
// [EXPECTED] liquidity: 340264708
// [EXPECTED] amount0: 100000000
// [EXPECTED] amount1: 100000000
//
// [SCENARIO] 5. ExactOutSwapRoute
// [INFO] ExactOutSwapRoute
// [INFO] inputToken: gno.land/r/gnoland/wugnot
// [INFO] outputToken: gno.land/r/gnoswap/gns
// [INFO] specifiedAmount: 1001502
// [INFO] routeQueryString: gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500
// [INFO] queryRatios: 100
// [INFO] amountInMax: 10000000
// [EXPECTED] inputTokenAmount: 1004496
// [EXPECTED] outputTokenAmount: -1001502
