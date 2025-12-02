// exact out swap route with single route

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"chain/banker"
	"strconv"
	"testing"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"
	_ "gno.land/r/gnoswap/router/v1"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoland/wugnot"

	"gno.land/r/gnoswap/scenario/metric"
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

func main() {
	initializeSetup()

	createPool(wugnotPath, gnsPath, 500, 0)
	mintPosition(wugnotPath, gnsPath, 500, -6960, 6960, "100000000", "100000000")

	createPool(wugnotPath, gnsPath, 3000, 100)
	mintPosition(wugnotPath, gnsPath, 500, -6960, 6960, "100000000", "100000000")

	createPool(wugnotPath, gnsPath, 10000, -100)
	mintPosition(wugnotPath, gnsPath, 500, -6960, 6960, "100000000", "100000000")

	exactOutSwapRouteBy(
		gnsPath,
		wugnotPath,
		"1001502",
		"gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500",
		"100",
		"10000000",
	)
}

func initializeSetup() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.IssueCoins(chain.PackageAddress("gno.land/r/gnoland/wugnot"), chain.Coins{{"ugnot", 100000000000000}})
	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 100000000000000}})
	testing.SetOriginSend(chain.Coins{{"ugnot", 100000000000000}})
	testing.SetRealm(adminRealm)
	wugnot.Deposit(cross)

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
}

func mintPosition(token0Path string, token1Path string, fee uint32, minTick, maxTick int32, amount0 string, amount1 string) {
	testing.SetRealm(adminRealm)

	testing.SetOriginSend(chain.Coins{})
	_, _, _, _ = pn.Mint(
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

	amountUint64, _ := strconv.ParseUint(amountInMax, 10, 64)
	gns.Approve(cross, routerAddr, int64(amountUint64))

	banker.NewBanker(banker.BankerTypeReadonly)

	testing.SetOriginSend(chain.Coins{})

	metric.PrintMetricsBy("Router Exact Out Swap Route", func() {
		_, _ = router.ExactOutSwapRoute(
			cross,
			inputToken,
			"ugnot",
			specifiedAmount,
			routeQueryString,
			queryRatios,
			amountInMax,
			int64(9999999999),
			"",
		)
	})
}
