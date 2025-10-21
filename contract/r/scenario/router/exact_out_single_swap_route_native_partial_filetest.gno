// exact in swap route with native token

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"chain/banker"
	"strconv"
	"testing"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/router"
	"gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoland/wugnot"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	wugnotPath = "gno.land/r/gnoland/wugnot"
	gnsPath    = "gno.land/r/gnoswap/gns"

	maxInt64 int64 = 9223372036854775807
)

var t *testing.T

func main() {
	println("[SCENARIO] 1. Initialize Setup")
	initializeSetup()
	println()

	println("[SCENARIO] 2. Create Pool And Mint Position (gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500) with unbalance position balance")
	createPool(wugnotPath, gnsPath, 500, 0)
	mintPosition(wugnotPath, gnsPath, 500, -6960, 6960, "100000000", "100000000")
	println()

	println("[SCENARIO] 3. ExactOutSwapRoute")
	exactOutSingleSwapRouteBy(
		"gnot",
		gnsPath,
		"10000000",
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500",
		"100",
		"100000000",
	)
	println()
}

func initializeSetup() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 100000000000000}})
	testing.SetOriginSend(chain.Coins{{"ugnot", 100000000000000}})
	testing.SetRealm(adminRealm)
	wugnot.Deposit(cross)

	testing.IssueCoins(testing.NewCodeRealm(wugnotPath).Address(), chain.Coins{{"ugnot", 100000000000000}})

	println("[INFO] GNS Balance of admin:", gns.BalanceOf(adminAddr))
	println("[INFO] WUGNOT Balance of admin:", wugnot.BalanceOf(adminAddr))

	gns.Approve(cross, poolAddr, maxInt64)
	wugnot.Approve(cross, poolAddr, maxInt64)

	gns.Approve(cross, routerAddr, maxInt64)
	wugnot.Approve(cross, routerAddr, maxInt64)
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

	testing.SetOriginSend(chain.Coins{})
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

func exactOutSingleSwapRouteBy(
	inputToken string,
	outputToken string,
	specifiedAmount string,
	routeQueryString string,
	queryRatios string,
	maxAmountOut string,
) {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] ExactOutSwapRoute")
	ufmt.Println("[INFO] inputToken:", inputToken)
	ufmt.Println("[INFO] outputToken:", outputToken)
	ufmt.Println("[INFO] specifiedAmount:", specifiedAmount)
	ufmt.Println("[INFO] routeQueryString:", routeQueryString)
	ufmt.Println("[INFO] queryRatios:", queryRatios)
	ufmt.Println("[INFO] maxAmountOut:", maxAmountOut)

	banker_ := banker.NewBanker(banker.BankerTypeReadonly)
	beforeGNOTBalance := banker_.GetCoins(adminAddr).AmountOf("ugnot")
	beforeGNSBalance := gns.BalanceOf(adminAddr)

	maxAmountOutInt, _ := strconv.ParseInt(maxAmountOut, 10, 64)

	sendBanker := banker.NewBanker(banker.BankerTypeRealmSend)
	sendBanker.SendCoins(adminAddr, routerAddr, chain.Coins{{"ugnot", maxAmountOutInt}})
	testing.SetOriginSend(chain.Coins{{"ugnot", maxAmountOutInt}})
	testing.SetRealm(adminRealm)

	// current sqrtPriceX96 is 76228162514264337593543950336
	inputTokenAmount, outputTokenAmount := router.ExactOutSingleSwapRoute(
		cross,
		inputToken,
		outputToken,
		specifiedAmount,
		routeQueryString,
		maxAmountOut,
		common.TickMathGetSqrtRatioAtTick(-10).ToString(),
		int64(9999999999),
		"",
	)

	afterGNOTBalance := banker_.GetCoins(adminAddr).AmountOf("ugnot")
	afterGNSBalance := gns.BalanceOf(adminAddr)

	ufmt.Printf("[EXPECTED] pool current tick: %d\n", pool.GetSlot0Tick(routeQueryString))
	ufmt.Printf("[EXPECTED] inputTokenAmount(GNS): %s\n", inputTokenAmount)
	ufmt.Printf("[EXPECTED] outputTokenAmount(GNOT): %s\n", outputTokenAmount)
	ufmt.Printf("[EXPECTED] GNS balance changed: %d\n", afterGNSBalance-beforeGNSBalance)
	ufmt.Printf("[EXPECTED] GNOT balance changed: %d\n", afterGNOTBalance-beforeGNOTBalance)
}

// Output:
// [SCENARIO] 1. Initialize Setup
// [INFO] GNS Balance of admin: 100000000000000
// [INFO] WUGNOT Balance of admin: 100000000000000
//
// [SCENARIO] 2. Create Pool And Mint Position (gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500) with unbalance position balance
// [EXPECTED] created gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500 pool at tick 0
// [INFO] Minting position
// [EXPECTED] positionId: 1
// [EXPECTED] liquidity: 340264708
// [EXPECTED] amount0: 100000000
// [EXPECTED] amount1: 100000000
//
// [SCENARIO] 3. ExactOutSwapRoute
// [INFO] ExactOutSwapRoute
// [INFO] inputToken: gnot
// [INFO] outputToken: gno.land/r/gnoswap/gns
// [INFO] specifiedAmount: 10000000
// [INFO] routeQueryString: gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500
// [INFO] queryRatios: 100
// [INFO] maxAmountOut: 100000000
// [EXPECTED] pool current tick: -10
// [EXPECTED] inputTokenAmount(GNS): 170253
// [EXPECTED] outputTokenAmount(GNOT): -169826
// [EXPECTED] GNS balance changed: 169826
// [EXPECTED] GNOT balance changed: -170253
