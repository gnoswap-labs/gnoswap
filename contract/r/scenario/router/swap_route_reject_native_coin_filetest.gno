// Verify that sending native coins (ugnot) via SetOriginSend is rejected
// by the router with "handle native coin is not allowed" error.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"testing"
	"time"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
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
	"gno.land/r/gnoswap/test_token/sol"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	wugnotPath = "gno.land/r/gnoland/wugnot"
	solPath    = "gno.land/r/gnoswap/test_token/sol"

	maxInt64 int64 = 9223372036854775807
)

func main() {
	// 1. Setup
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 100000000000000}})
	testing.IssueCoins(testing.NewCodeRealm(wugnotPath).Address(), chain.Coins{{"ugnot", 100000000000000}})

	// Deposit wugnot for pool creation
	testing.SetOriginSend(chain.Coins{{"ugnot", 100000000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(chain.Coins{})

	// Approve tokens
	wugnot.Approve(cross, poolAddr, maxInt64)
	sol.Approve(cross, poolAddr, maxInt64)
	wugnot.Approve(cross, routerAddr, maxInt64)
	sol.Approve(cross, routerAddr, maxInt64)

	// 2. Create wugnot/sol pool and mint position
	pool.CreatePool(
		cross,
		wugnotPath,
		solPath,
		3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	pn.Mint(
		cross,
		wugnotPath,
		solPath,
		3000,
		-887220,
		887220,
		"50000",
		"50000",
		"0",
		"0",
		9999999999,
		adminAddr,
		"",
	)

	// 3. Attempt swap with native coins - should panic
	testing.SetOriginSend(chain.Coins{{"ugnot", 12345}})

	router.ExactOutSwapRoute(
		cross,
		"ugnot",    // inputToken (native coin)
		solPath,    // outputToken
		"3",        // amountSpecified
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/test_token/sol:3000", // strRouteArr
		"100",      // quoteArr
		"12345",    // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"",         // referrer
	)
}

// Error:
// [GNOSWAP-COMMON-006] handle native coin is not allowed
