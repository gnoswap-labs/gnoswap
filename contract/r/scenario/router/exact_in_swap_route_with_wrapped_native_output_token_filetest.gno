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
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/onbloc/bar"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

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
	barPath    = "gno.land/r/onbloc/bar"

	maxInt64 int64 = 9223372036854775807
)

var t *testing.T

func main() {
	println("[SCENARIO] 1. Initialize Setup")
	initializeSetup()
	println()

	println("[SCENARIO] 2. Create Pool And Mint Position (gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000) with unbalance position balance")
	createPool(wugnotPath, gnsPath, 3000, 0)
	mintPosition(wugnotPath, gnsPath, 3000, -6960, 6960, "100000000", "100000000")
	println()

	println("[SCENARIO] 3. Create Pool And Mint Position (gno.land/r/gnoland/wugnot:gno.land/r/onbloc/bar:3000) with unbalance position balance")
	createPool(wugnotPath, barPath, 3000, 0)
	mintPosition(wugnotPath, barPath, 3000, -6960, 6960, "100000000", "100000000")
	println()

	println("[SCENARIO] 4. Create Pool And Mint Position (gno.land/r/gnoswap/gns:gno.land/r/onbloc/bar:3000) with unbalance position balance")
	createPool(gnsPath, barPath, 3000, 0)
	mintPosition(gnsPath, barPath, 3000, -6960, 6960, "100000000", "100000000")
	println()

	println("[SCENARIO] 5. ExactInSwapRoute BAR -> GNS -> WUGNOT")
	exactInSwapRouteBy(
		barPath,
		wugnotPath,
		"1000000",
		"gno.land/r/onbloc/bar:gno.land/r/gnoswap/gns:3000*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:3000",
		"100",
		"1",
	)
	println()

	println("[SCENARIO] 6. ExactInSwapRoute BAR -> GNS -> GNOT")
	exactInSwapRouteBy(
		barPath,
		"gnot",
		"1000000",
		"gno.land/r/onbloc/bar:gno.land/r/gnoswap/gns:3000*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:3000",
		"100",
		"1",
	)
	println()

	println("[SCENARIO] 7. ExactInSwapRoute BAR -> WUGNOT -> GNS")
	exactInSwapRouteBy(
		barPath,
		gnsPath,
		"1000000",
		"gno.land/r/onbloc/bar:gno.land/r/gnoland/wugnot:3000*POOL*gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000",
		"100",
		"1",
	)
	println()

	println("[SCENARIO] 8. ExactInSwapRoute GNOT -> GNS -> BAR")
	exactInSwapRouteBy(
		"gnot",
		barPath,
		"1000000",
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000*POOL*gno.land/r/gnoswap/gns:gno.land/r/onbloc/bar:3000",
		"100",
		"1",
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
	ufmt.Println("[INFO] Minting position")

	testing.SetRealm(adminRealm)
	common.Approve(cross, token0Path, poolAddr, maxInt64)
	common.Approve(cross, token1Path, poolAddr, maxInt64)

	testing.SetOriginSend(chain.Coins{})
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		token0Path,
		token1Path,
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
	beforeWUGNOTBalance := wugnot.BalanceOf(adminAddr)
	beforeGNSBalance := gns.BalanceOf(adminAddr)
	beforeBARBalance := bar.BalanceOf(adminAddr)
	specifiedAmountInt64, _ := strconv.ParseInt(specifiedAmount, 10, 64)

	if common.IsGNOTNativePath(inputToken) {

		sendCoins := chain.Coins{{Denom: common.GNOT_DENOM, Amount: specifiedAmountInt64}}
		banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
		banker_.SendCoins(adminAddr, routerAddr, sendCoins)

		testing.SetOriginSend(sendCoins)

		common.SafeGRC20Approve(cross, common.WUGNOT_PATH, routerAddr, specifiedAmountInt64)
	} else {
		testing.SetOriginSend(chain.Coins{})

		common.SafeGRC20Approve(cross, inputToken, routerAddr, specifiedAmountInt64)
	}
	inputTokenAmount, outputTokenAmount := router.ExactInSwapRoute(
		cross,
		inputToken,
		outputToken,
		specifiedAmount,
		routeQueryString,
		queryRatios,
		minAmountOut,
		int64(9999999999),
		"",
	)

	afterGNOTBalance := banker_.GetCoins(adminAddr).AmountOf("ugnot")
	afterWUGNOTBalance := wugnot.BalanceOf(adminAddr)
	afterGNSBalance := gns.BalanceOf(adminAddr)
	afterBARBalance := bar.BalanceOf(adminAddr)

	ufmt.Printf("[EXPECTED] inputTokenAmount: %s\n", inputTokenAmount)
	ufmt.Printf("[EXPECTED] outputTokenAmount: %s\n", outputTokenAmount)
	ufmt.Printf("[EXPECTED] WUGNOT balance changed: %d\n", afterWUGNOTBalance-beforeWUGNOTBalance)
	ufmt.Printf("[EXPECTED] GNOT balance changed: %d\n", afterGNOTBalance-beforeGNOTBalance)
	ufmt.Printf("[EXPECTED] GNS balance changed: %d\n", afterGNSBalance-beforeGNSBalance)
	ufmt.Printf("[EXPECTED] BAR balance changed: %d\n", afterBARBalance-beforeBARBalance)
}

// Output:
// [SCENARIO] 1. Initialize Setup
// [INFO] GNS Balance of admin: 100000000000000
// [INFO] WUGNOT Balance of admin: 100000000000000
//
// [SCENARIO] 2. Create Pool And Mint Position (gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000) with unbalance position balance
// [EXPECTED] created gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000 pool at tick 0
// [INFO] Minting position
// [EXPECTED] positionId: 1
// [EXPECTED] liquidity: 340264708
// [EXPECTED] amount0: 100000000
// [EXPECTED] amount1: 100000000
//
// [SCENARIO] 3. Create Pool And Mint Position (gno.land/r/gnoland/wugnot:gno.land/r/onbloc/bar:3000) with unbalance position balance
// [EXPECTED] created gno.land/r/gnoland/wugnot:gno.land/r/onbloc/bar:3000 pool at tick 0
// [INFO] Minting position
// [EXPECTED] positionId: 2
// [EXPECTED] liquidity: 340264708
// [EXPECTED] amount0: 100000000
// [EXPECTED] amount1: 100000000
//
// [SCENARIO] 4. Create Pool And Mint Position (gno.land/r/gnoswap/gns:gno.land/r/onbloc/bar:3000) with unbalance position balance
// [EXPECTED] created gno.land/r/gnoswap/gns:gno.land/r/onbloc/bar:3000 pool at tick 0
// [INFO] Minting position
// [EXPECTED] positionId: 3
// [EXPECTED] liquidity: 340264708
// [EXPECTED] amount0: 100000000
// [EXPECTED] amount1: 100000000
//
// [SCENARIO] 5. ExactInSwapRoute BAR -> GNS -> WUGNOT
// [INFO] ExactInSwapRoute
// [INFO] inputToken: gno.land/r/onbloc/bar
// [INFO] outputToken: gno.land/r/gnoland/wugnot
// [INFO] specifiedAmount: 1000000
// [INFO] routeQueryString: gno.land/r/onbloc/bar:gno.land/r/gnoswap/gns:3000*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:3000
// [INFO] queryRatios: 100
// [INFO] minAmountOut: 1
// [EXPECTED] inputTokenAmount: 1000000
// [EXPECTED] outputTokenAmount: -986743
// [EXPECTED] WUGNOT balance changed: 986743
// [EXPECTED] GNOT balance changed: 0
// [EXPECTED] GNS balance changed: 0
// [EXPECTED] BAR balance changed: -1000000
//
// [SCENARIO] 6. ExactInSwapRoute BAR -> GNS -> GNOT
// [INFO] ExactInSwapRoute
// [INFO] inputToken: gno.land/r/onbloc/bar
// [INFO] outputToken: gnot
// [INFO] specifiedAmount: 1000000
// [INFO] routeQueryString: gno.land/r/onbloc/bar:gno.land/r/gnoswap/gns:3000*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:3000
// [INFO] queryRatios: 100
// [INFO] minAmountOut: 1
// [EXPECTED] inputTokenAmount: 1000000
// [EXPECTED] outputTokenAmount: -975329
// [EXPECTED] WUGNOT balance changed: 0
// [EXPECTED] GNOT balance changed: 975329
// [EXPECTED] GNS balance changed: 0
// [EXPECTED] BAR balance changed: -1000000
//
// [SCENARIO] 7. ExactInSwapRoute BAR -> WUGNOT -> GNS
// [INFO] ExactInSwapRoute
// [INFO] inputToken: gno.land/r/onbloc/bar
// [INFO] outputToken: gno.land/r/gnoswap/gns
// [INFO] specifiedAmount: 1000000
// [INFO] routeQueryString: gno.land/r/onbloc/bar:gno.land/r/gnoland/wugnot:3000*POOL*gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000
// [INFO] queryRatios: 100
// [INFO] minAmountOut: 1
// [EXPECTED] inputTokenAmount: 1000000
// [EXPECTED] outputTokenAmount: -998223
// [EXPECTED] WUGNOT balance changed: 0
// [EXPECTED] GNOT balance changed: 0
// [EXPECTED] GNS balance changed: 998223
// [EXPECTED] BAR balance changed: -1000000
//
// [SCENARIO] 8. ExactInSwapRoute GNOT -> GNS -> BAR
// [INFO] ExactInSwapRoute
// [INFO] inputToken: gnot
// [INFO] outputToken: gno.land/r/onbloc/bar
// [INFO] specifiedAmount: 1000000
// [INFO] routeQueryString: gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000*POOL*gno.land/r/gnoswap/gns:gno.land/r/onbloc/bar:3000
// [INFO] queryRatios: 100
// [INFO] minAmountOut: 1
// [EXPECTED] inputTokenAmount: 1000000
// [EXPECTED] outputTokenAmount: -1004036
// [EXPECTED] WUGNOT balance changed: 0
// [EXPECTED] GNOT balance changed: -1000000
// [EXPECTED] GNS balance changed: 0
// [EXPECTED] BAR balance changed: 1004036
