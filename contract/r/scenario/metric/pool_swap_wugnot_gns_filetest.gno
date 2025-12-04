// PKGPATH: gno.land/r/demo/main

// Gas and performance metrics for pool swap scenario
// Test cases based on tests/integration/testdata/pool/swap_wugnot_gns_tokens.txtar
package main

import (
	"chain"
	"chain/banker"
	"testing"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/gnoland/wugnot"

	"gno.land/r/gnoswap/scenario/metric"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _     = access.GetAddress(prabc.ROLE_POOL.String())
	positionAddr, _ = access.GetAddress(prabc.ROLE_POSITION.String())

	wugnotPath = "gno.land/r/gnoland/wugnot"
	gnsPath    = "gno.land/r/gnoswap/gns"

	maxInt64 int64 = 9223372036854775807
)

var t *testing.T

func main() {
	initializeSwapSetup()

	createPool500Metric()
	mintPosition500Metric()
	swapGnsToWugnotMetric()
}

func initializeSwapSetup() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 1000000000000000}})
	testing.SetOriginSend(chain.Coins{{"ugnot", 100000000000000}})
	testing.SetRealm(adminRealm)
	wugnot.Deposit(cross)

	gns.Approve(cross, poolAddr, maxInt64)
	wugnot.Approve(cross, poolAddr, maxInt64)
	gns.Approve(cross, positionAddr, maxInt64)
	wugnot.Approve(cross, positionAddr, maxInt64)
}

func createPool500Metric() {
	testing.SetRealm(adminRealm)

	metric.PrintMetricsBy("CreatePool (wugnot:gns:500)", func() {
		pool.CreatePool(
			cross,
			wugnotPath,
			gnsPath,
			500,
			common.TickMathGetSqrtRatioAtTick(0).ToString(),
		)
	})
}

func mintPosition500Metric() {
	testing.SetRealm(adminRealm)

	metric.PrintMetricsBy("Mint Position (fee:500, wide range)", func() {
		banker_ := banker.NewBanker(banker.BankerTypeRealmIssue)
		banker_.SendCoins(adminAddr, positionAddr, chain.Coins{{"ugnot", 50000000}})
		testing.SetOriginSend(chain.Coins{{"ugnot", 50000000}})

		position.Mint(
			cross,
			gnsPath,
			"ugnot",
			500,
			-887220,
			887220,
			"50000000",
			"50000000",
			"1",
			"1",
			9999999999,
			adminAddr,
			adminAddr,
			"",
		)
	})
}

func swapGnsToWugnotMetric() {
	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, maxInt64)

	metric.PrintMetricsBy("Swap (gns -> wugnot, fee:500)", func() {
		testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
		pool.Swap(
			cross,
			wugnotPath,
			gnsPath,
			500,
			adminAddr,
			false,
			"60283363",
			"1461446703485210103287273052203988822378723970341",
			adminAddr,
			func(cur realm, amount0Delta, amount1Delta int64) error {
				testing.SetRealm(adminRealm)
				common.SafeGRC20Transfer(cross, gnsPath, poolAddr, amount1Delta)
				return nil
			},
		)
	})
}
