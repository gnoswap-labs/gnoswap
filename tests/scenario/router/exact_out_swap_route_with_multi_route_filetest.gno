// exact out swap route with multi route

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"

	"gno.land/r/demo/wugnot"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)

	wugnotPath = "gno.land/r/demo/wugnot"
	gnsPath    = "gno.land/r/gnoswap/v1/gns"
)

var t *testing.T

func main() {
	println("[SCENARIO] 1. Initialize Setup")
	initializeSetup()

	println("[SCENARIO] 2. Create Pool And Mint Position (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:500)")
	createPool(wugnotPath, gnsPath, 500, 0)
	mintPosition(wugnotPath, gnsPath, 500, -6960, 6960, "100000000", "100000000")
	println()

	println("[SCENARIO] 3. Create Pool And Mint Position (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000)")
	createPool(wugnotPath, gnsPath, 3000, 100)
	mintPosition(wugnotPath, gnsPath, 3000, -6960, 6960, "100000000", "100000000")
	println()

	println("[SCENARIO] 4. Create Pool And Mint Position (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:10000)")
	createPool(wugnotPath, gnsPath, 10000, -100)
	mintPosition(wugnotPath, gnsPath, 10000, -7000, 7000, "100000000", "100000000")
	println()

	println("[SCENARIO] 5. ExactOutSwapRoute multi route (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:500,gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000,gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:10000)")
	exactOutSwapRouteBy(
		consts.GNOT,
		gnsPath,
		"1001502",
		"gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:500,gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000,gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:10000",
		"40,40,20",
		"10000000",
	)
	println()
}

func initializeSetup() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFeeByAdmin(cross, 0)

	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 100000000000000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 100000000000000}})
	testing.SetRealm(adminRealm)
	wugnot.Deposit(cross)

	println("[INFO] GNS Balance of admin:", gns.BalanceOf(adminAddr))
	println("[INFO] WUGNOT Balance of admin:", wugnot.BalanceOf(adminAddr))

	gns.Approve(cross, poolAddr, consts.INT64_MAX)
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, routerAddr, consts.INT64_MAX)
	wugnot.Approve(cross, routerAddr, consts.INT64_MAX)
}

func createPool(token0Path string, token1Path string, fee uint32, startTick int32) {
	testing.SetRealm(adminRealm)
	pool.CreatePool(
		cross,
		token0Path,
		token1Path,
		fee,
		common.TickMathGetSqrtRatioAtTick(startTick).ToString(),
	)

	ufmt.Printf("[EXPECTED] created %s:%s:%d pool at tick %d\n", token0Path, token1Path, fee, startTick)
}

func mintPosition(token0Path string, token1Path string, fee uint32, minTick, maxTick int32, amount0 string, amount1 string) {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Minting position")
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross,
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
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] positionId: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s\n", amount0)
	ufmt.Printf("[EXPECTED] amount1: %s\n", amount1)
}

func exactOutSwapRouteBy(
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

	amountUint64, _ := strconv.ParseUint(amountInMax, 10, 64)
	testing.SetOriginSend(std.Coins{{"ugnot", int64(amountUint64)}})

	banker := std.NewBanker(std.BankerTypeRealmIssue)
	banker.SendCoins(adminAddr, routerAddr, std.Coins{{"ugnot", int64(amountUint64)}})

	inputTokenAmount, outputTokenAmount := router.ExactOutSwapRoute(
		cross,
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
// [SCENARIO] 2. Create Pool And Mint Position (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:500)
// [EXPECTED] created gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:500 pool at tick 0
// [INFO] Minting position
// [EXPECTED] positionId: 1
// [EXPECTED] liquidity: 340264708
// [EXPECTED] amount0: 100000000
// [EXPECTED] amount1: 100000000
//
// [SCENARIO] 3. Create Pool And Mint Position (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000)
// [EXPECTED] created gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000 pool at tick 100
// [INFO] Minting position
// [EXPECTED] positionId: 2
// [EXPECTED] liquidity: 334558813
// [EXPECTED] amount0: 96654566
// [EXPECTED] amount1: 100000000
//
// [SCENARIO] 4. Create Pool And Mint Position (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:10000)
// [EXPECTED] created gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:10000 pool at tick -100
// [INFO] Minting position
// [EXPECTED] positionId: 3
// [EXPECTED] liquidity: 332987194
// [EXPECTED] amount0: 100000000
// [EXPECTED] amount1: 96670281
//
// [SCENARIO] 5. ExactOutSwapRoute multi route (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:500,gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000,gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:10000)
// [INFO] ExactOutSwapRoute
// [INFO] inputToken: gnot
// [INFO] outputToken: gno.land/r/gnoswap/v1/gns
// [INFO] specifiedAmount: 1001502
// [INFO] routeQueryString: gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:500,gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000,gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:10000
// [INFO] queryRatios: 40,40,20
// [INFO] amountInMax: 10000000
// [EXPECTED] inputTokenAmount: 1004040
// [EXPECTED] outputTokenAmount: -1000000
