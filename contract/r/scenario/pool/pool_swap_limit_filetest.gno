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
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

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

	println("[SCENARIO] 2. Create Pool And Mint Positions")
	createPool(wugnotPath, gnsPath, 3000, 0)
	// 1. 활성 거래용 포지션 (좁은 범위)
	mintPosition(wugnotPath, gnsPath, 3000, -6960, 6960, "100000000", "100000000")
	// 2. 극단적 가격 이동 대비 전체 범위 포지션 (미리 추가)
	//    MIN_TICK까지 이동 후에도 역방향 스왑이 가능하도록 함
	mintPosition(wugnotPath, gnsPath, 3000, -887220, 887220, "50000000000000", "50000000000000")
	println()

	println("[SCENARIO] 3. ExactInSwapRoute - move tick to MIN_TICK")
	exactInSingleSwapRouteBy(
		"ugnot",
		gnsPath,
		"50000000000000", // 전체 범위 유동성을 소진할 만큼 큰 금액
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000",
		"100",
		"1",
	)
	println()

	println("[SCENARIO] 4. ExactInSwapRoute reverse direction for normalize pool price")
	exactInSingleSwapRouteBy(
		gnsPath,
		"ugnot",
		"50000000000000", // 역방향 스왑으로 복구
		"gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:3000",
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

func exactInSingleSwapRouteBy(
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

	specifiedAmountInt, _ := strconv.ParseInt(specifiedAmount, 10, 64)

	testing.SetRealm(adminRealm)
	if inputToken == "ugnot" {
		sendBanker := banker.NewBanker(banker.BankerTypeRealmSend)
		sendBanker.SendCoins(adminAddr, routerAddr, chain.Coins{{"ugnot", specifiedAmountInt}})
		testing.SetOriginSend(chain.Coins{{"ugnot", specifiedAmountInt}})
	} else {
		testing.SetOriginSend(chain.Coins{})
	}

	// current sqrtPriceX96 is 76228162514264337593543950336
	inputTokenAmount, outputTokenAmount := router.ExactInSingleSwapRoute(
		cross,
		inputToken,
		outputToken,
		specifiedAmount,
		routeQueryString,
		minAmountOut,
		"0",
		int64(9999999999),
		"",
	)

	afterGNOTBalance := banker_.GetCoins(adminAddr).AmountOf("ugnot")
	afterGNSBalance := gns.BalanceOf(adminAddr)

	testing.SetRealm(adminRealm)
	ufmt.Printf("[EXPECTED] pool current tick: %d\n", pool.GetSlot0Tick("gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000"))

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
// [SCENARIO] 2. Create Pool And Mint Positions
// [EXPECTED] created gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000 pool at tick 0
// [INFO] Minting position
// [EXPECTED] positionId: 1
// [EXPECTED] liquidity: 340264708
// [EXPECTED] amount0: 100000000
// [EXPECTED] amount1: 100000000
// [INFO] Minting position
// [EXPECTED] positionId: 2
// [EXPECTED] liquidity: 50000000000000
// [EXPECTED] amount0: 50000000000000
// [EXPECTED] amount1: 50000000000000
//
// [SCENARIO] 3. ExactInSwapRoute - move tick to MIN_TICK
// [INFO] ExactInSwapRoute
// [INFO] inputToken: ugnot
// [INFO] outputToken: gno.land/r/gnoswap/gns
// [INFO] specifiedAmount: 50000000000000
// [INFO] routeQueryString: gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000
// [INFO] queryRatios: 100
// [INFO] minAmountOut: 1
// [EXPECTED] pool current tick: -13834
// [EXPECTED] inputTokenAmount(GNS): 50000000000000
// [EXPECTED] outputTokenAmount(GNOT): -24925064391572
// [EXPECTED] GNS balance changed: 24925064391572
// [EXPECTED] GNOT balance changed: -50000000000000
//
// [SCENARIO] 4. ExactInSwapRoute reverse direction for normalize pool price
// [INFO] ExactInSwapRoute
// [INFO] inputToken: gno.land/r/gnoswap/gns
// [INFO] outputToken: ugnot
// [INFO] specifiedAmount: 50000000000000
// [INFO] routeQueryString: gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:3000
// [INFO] queryRatios: 100
// [INFO] minAmountOut: 1
// [EXPECTED] pool current tick: 8079
// [EXPECTED] inputTokenAmount(GNS): 50000000000000
// [EXPECTED] outputTokenAmount(GNOT): -66366924850056
// [EXPECTED] GNS balance changed: -50000000000000
// [EXPECTED] GNOT balance changed: 66366924850056
