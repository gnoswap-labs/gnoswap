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
	"gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
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

	println("[SCENARIO] 3. ExactInSwapRoute (GNOT -> GNS -> WUGNOT)")
	exactInSwapRouteBy(
		"gnot",
		wugnotPath,
		"10000",
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500",
		"100",
		"1",
	)
	println()

	println("[SCENARIO] 4. ExactOutSwapRoute (GNOT -> GNS -> WUGNOT)")
	exactOutSwapRouteBy(
		"gnot",
		wugnotPath,
		"10000",
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500",
		"100",
		"100000",
	)
	println()

	println("[SCENARIO] 5. ExactInSwapRoute (WUGNOT -> GNS -> GNOT)")
	exactInSwapRouteBy(
		wugnotPath,
		"gnot",
		"10000",
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500",
		"100",
		"1",
	)
	println()

	println("[SCENARIO] 6. ExactOutSwapRoute (WUGNOT -> GNS -> GNOT)")
	exactOutSwapRouteBy(
		wugnotPath,
		"gnot",
		"10000",
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500",
		"100",
		"100000",
	)
	println()

	println("[SCENARIO] 7. ExactInSwapRoute (GNOT -> GNS -> GNOT)")
	exactInSwapRouteBy(
		"gnot",
		"gnot",
		"10000",
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500",
		"100",
		"1",
	)
	println()

	println("[SCENARIO] 8. ExactOutSwapRoute (GNOT -> GNS -> GNOT)")
	exactOutSwapRouteBy(
		"gnot",
		"gnot",
		"10000",
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500",
		"100",
		"100000",
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

func exactInSwapRouteBy(
	inputToken string,
	outputToken string,
	specifiedAmount string,
	routeQueryString string,
	queryRatios string,
	minAmountOut string,
) {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] ExactInSwapRoute")
	ufmt.Println("[INFO] inputToken:", inputToken)
	ufmt.Println("[INFO] outputToken:", outputToken)
	ufmt.Println("[INFO] specifiedAmount:", specifiedAmount)
	ufmt.Println("[INFO] routeQueryString:", routeQueryString)
	ufmt.Println("[INFO] queryRatios:", queryRatios)
	ufmt.Println("[INFO] minAmountOut:", minAmountOut)

	banker_ := banker.NewBanker(banker.BankerTypeReadonly)
	beforeGNOTBalance := banker_.GetCoins(adminAddr).AmountOf("ugnot")
	beforeGNSBalance := gns.BalanceOf(adminAddr)
	beforeWUGNOTBalance := wugnot.BalanceOf(adminAddr)

	specifiedAmountInt, _ := strconv.ParseInt(specifiedAmount, 10, 64)

	if inputToken == "gnot" {
		sendBanker := banker.NewBanker(banker.BankerTypeRealmSend)
		sendBanker.SendCoins(adminAddr, routerAddr, chain.Coins{{"ugnot", specifiedAmountInt}})
		testing.SetOriginSend(chain.Coins{{"ugnot", specifiedAmountInt}})
	} else {
		testing.SetOriginSend(chain.Coins{})
	}

	testing.SetRealm(adminRealm)

	// current sqrtPriceX96 is 76228162514264337593543950336
	inputTokenAmount, outputTokenAmount := router.ExactInSwapRoute(
		cross,
		inputToken,
		outputToken,
		specifiedAmount,
		routeQueryString,
		"100",
		minAmountOut,
		int64(9999999999),
		"",
	)

	afterGNOTBalance := banker_.GetCoins(adminAddr).AmountOf("ugnot")
	afterGNSBalance := gns.BalanceOf(adminAddr)
	afterWUGNOTBalance := wugnot.BalanceOf(adminAddr)

	ufmt.Printf("[EXPECTED] inputTokenAmount: %s (%s)\n", inputTokenAmount, inputToken)
	ufmt.Printf("[EXPECTED] outputTokenAmount: %s (%s)\n", outputTokenAmount, outputToken)
	ufmt.Printf("[EXPECTED] GNS balance changed: %d\n", afterGNSBalance-beforeGNSBalance)
	ufmt.Printf("[EXPECTED] GNOT balance changed: %d\n", afterGNOTBalance-beforeGNOTBalance)
	ufmt.Printf("[EXPECTED] WUGNOT balance changed: %d\n", afterWUGNOTBalance-beforeWUGNOTBalance)
}

func exactOutSwapRouteBy(
	inputToken string,
	outputToken string,
	specifiedAmount string,
	routeQueryString string,
	queryRatios string,
	maxAmountIn string,
) {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] ExactOutSwapRoute")
	ufmt.Println("[INFO] inputToken:", inputToken)
	ufmt.Println("[INFO] outputToken:", outputToken)
	ufmt.Println("[INFO] specifiedAmount:", specifiedAmount)
	ufmt.Println("[INFO] routeQueryString:", routeQueryString)
	ufmt.Println("[INFO] queryRatios:", queryRatios)
	ufmt.Println("[INFO] maxAmountIn:", maxAmountIn)

	banker_ := banker.NewBanker(banker.BankerTypeReadonly)
	beforeGNOTBalance := banker_.GetCoins(adminAddr).AmountOf("ugnot")
	beforeGNSBalance := gns.BalanceOf(adminAddr)
	beforeWUGNOTBalance := wugnot.BalanceOf(adminAddr)

	if inputToken == "gnot" {
		maxAmountInInt, _ := strconv.ParseInt(maxAmountIn, 10, 64)
		sendBanker := banker.NewBanker(banker.BankerTypeRealmSend)
		sendBanker.SendCoins(adminAddr, routerAddr, chain.Coins{{"ugnot", maxAmountInInt}})
		testing.SetOriginSend(chain.Coins{{"ugnot", maxAmountInInt}})
	} else {
		testing.SetOriginSend(chain.Coins{})
	}

	testing.SetRealm(adminRealm)

	// current sqrtPriceX96 is 76228162514264337593543950336
	inputTokenAmount, outputTokenAmount := router.ExactOutSwapRoute(
		cross,
		inputToken,
		outputToken,
		specifiedAmount,
		routeQueryString,
		"100",
		maxAmountIn,
		int64(9999999999),
		"",
	)

	afterGNOTBalance := banker_.GetCoins(adminAddr).AmountOf("ugnot")
	afterGNSBalance := gns.BalanceOf(adminAddr)
	afterWUGNOTBalance := wugnot.BalanceOf(adminAddr)

	ufmt.Printf("[EXPECTED] inputTokenAmount: %s (%s)\n", inputTokenAmount, inputToken)
	ufmt.Printf("[EXPECTED] outputTokenAmount: %s (%s)\n", outputTokenAmount, outputToken)
	ufmt.Printf("[EXPECTED] GNS balance changed: %d\n", afterGNSBalance-beforeGNSBalance)
	ufmt.Printf("[EXPECTED] GNOT balance changed: %d\n", afterGNOTBalance-beforeGNOTBalance)
	ufmt.Printf("[EXPECTED] WUGNOT balance changed: %d\n", afterWUGNOTBalance-beforeWUGNOTBalance)
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
// [SCENARIO] 3. ExactInSwapRoute (GNOT -> GNS -> WUGNOT)
// [INFO] ExactInSwapRoute
// [INFO] inputToken: gnot
// [INFO] outputToken: gno.land/r/gnoland/wugnot
// [INFO] specifiedAmount: 10000
// [INFO] routeQueryString: gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500
// [INFO] queryRatios: 100
// [INFO] minAmountOut: 1
// [EXPECTED] inputTokenAmount: 10000 (gnot)
// [EXPECTED] outputTokenAmount: -9975 (gno.land/r/gnoland/wugnot)
// [EXPECTED] GNS balance changed: 0
// [EXPECTED] GNOT balance changed: -10000
// [EXPECTED] WUGNOT balance changed: 9975
//
// [SCENARIO] 4. ExactOutSwapRoute (GNOT -> GNS -> WUGNOT)
// [INFO] ExactOutSwapRoute
// [INFO] inputToken: gnot
// [INFO] outputToken: gno.land/r/gnoland/wugnot
// [INFO] specifiedAmount: 10000
// [INFO] routeQueryString: gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500
// [INFO] queryRatios: 100
// [INFO] maxAmountIn: 100000
// [EXPECTED] inputTokenAmount: 10029 (gnot)
// [EXPECTED] outputTokenAmount: -10001 (gno.land/r/gnoland/wugnot)
// [EXPECTED] GNS balance changed: 0
// [EXPECTED] GNOT balance changed: -10029
// [EXPECTED] WUGNOT balance changed: 10001
//
// [SCENARIO] 5. ExactInSwapRoute (WUGNOT -> GNS -> GNOT)
// [INFO] ExactInSwapRoute
// [INFO] inputToken: gno.land/r/gnoland/wugnot
// [INFO] outputToken: gnot
// [INFO] specifiedAmount: 10000
// [INFO] routeQueryString: gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500
// [INFO] queryRatios: 100
// [INFO] minAmountOut: 1
// [EXPECTED] inputTokenAmount: 10000 (gno.land/r/gnoland/wugnot)
// [EXPECTED] outputTokenAmount: -9975 (gnot)
// [EXPECTED] GNS balance changed: 0
// [EXPECTED] GNOT balance changed: 9975
// [EXPECTED] WUGNOT balance changed: -10000
//
// [SCENARIO] 6. ExactOutSwapRoute (WUGNOT -> GNS -> GNOT)
// [INFO] ExactOutSwapRoute
// [INFO] inputToken: gno.land/r/gnoland/wugnot
// [INFO] outputToken: gnot
// [INFO] specifiedAmount: 10000
// [INFO] routeQueryString: gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500
// [INFO] queryRatios: 100
// [INFO] maxAmountIn: 100000
// [EXPECTED] inputTokenAmount: 10029 (gno.land/r/gnoland/wugnot)
// [EXPECTED] outputTokenAmount: -10001 (gnot)
// [EXPECTED] GNS balance changed: 0
// [EXPECTED] GNOT balance changed: 10001
// [EXPECTED] WUGNOT balance changed: -10029
//
// [SCENARIO] 7. ExactInSwapRoute (GNOT -> GNS -> GNOT)
// [INFO] ExactInSwapRoute
// [INFO] inputToken: gnot
// [INFO] outputToken: gnot
// [INFO] specifiedAmount: 10000
// [INFO] routeQueryString: gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500
// [INFO] queryRatios: 100
// [INFO] minAmountOut: 1
// [EXPECTED] inputTokenAmount: 10000 (gnot)
// [EXPECTED] outputTokenAmount: -9975 (gnot)
// [EXPECTED] GNS balance changed: 0
// [EXPECTED] GNOT balance changed: -25
// [EXPECTED] WUGNOT balance changed: 0
//
// [SCENARIO] 8. ExactOutSwapRoute (GNOT -> GNS -> GNOT)
// [INFO] ExactOutSwapRoute
// [INFO] inputToken: gnot
// [INFO] outputToken: gnot
// [INFO] specifiedAmount: 10000
// [INFO] routeQueryString: gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500
// [INFO] queryRatios: 100
// [INFO] maxAmountIn: 100000
// [EXPECTED] inputTokenAmount: 10029 (gnot)
// [EXPECTED] outputTokenAmount: -10001 (gnot)
// [EXPECTED] GNS balance changed: 0
// [EXPECTED] GNOT balance changed: -28
// [EXPECTED] WUGNOT balance changed: 0
