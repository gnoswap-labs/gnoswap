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
	mintPosition(wugnotPath, gnsPath, 500, -6960, 6960, "100000000", "100000000")
	println()

	println("[SCENARIO] 4. Create Pool And Mint Position (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:10000)")
	createPool(wugnotPath, gnsPath, 10000, -100)
	mintPosition(wugnotPath, gnsPath, 500, -6960, 6960, "100000000", "100000000")
	println()

	println("[SCENARIO] 5. ExactOutSwapRoute")
	exactOutSwapRouteByMultiRoutes()
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

func exactOutSwapRouteByMultiRoutes() {
	testing.SetRealm(adminRealm)

	inputToken := consts.GNOT
	outputToken := gnsPath
	specifiedAmount := "1001502"
	routeQueryString := "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:500,gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000,gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:10000"
	queryRatios := "40,40,20"
	amountInMax := "1000"
	deadline := int64(9999999999)

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
		deadline,
		"",
	)

	ufmt.Printf("[EXPECTED] inputTokenAmount: %s\n", inputTokenAmount)
	ufmt.Printf("[EXPECTED] outputTokenAmount: %s\n", outputTokenAmount)
}
