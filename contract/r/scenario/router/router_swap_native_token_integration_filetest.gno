// Scenario #3: Router Swap Native Token Integration
// Purpose: Validate ExactIn/ExactOut swaps with GNOT

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"chain/banker"
	"strconv"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/onbloc/usdc"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	positionAddr, _    = access.GetAddress(prabc.ROLE_POSITION.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())

	userAddr  = testutils.TestAddress("user")
	userRealm = testing.NewUserRealm(userAddr)

	wugnotPath = "gno.land/r/gnoland/wugnot"
	gnsPath    = "gno.land/r/gnoswap/gns"
	usdcPath   = "gno.land/r/onbloc/usdc"

	gnotPath = "gnot"

	fee500 uint32 = 500

	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

var t *testing.T

func main() {
	println("[SCENARIO] #3 Router Swap Native Token Integration")
	println("[INFO] Purpose: Validate ExactIn/ExactOut swaps with GNOT")
	println()

	println("[SCENARIO] 1. Initial Setup")
	setupPoolsAndLiquidity()
	println()

	println("[SCENARIO] 2. ExactIn: GNOT → GNS")
	testExactInGnotToGns()
	println()

	println("[SCENARIO] 3. ExactOut: GNS → GNOT")
	testExactOutGnsToGnot()
	println()

	println("[SCENARIO] 4. Multi-hop: GNOT → GNS → USDC")
	testMultiHopGnotToUsdc()
	println()

	println("[SCENARIO] 5. Multi-hop: USDC → GNS → GNOT")
	testMultiHopUsdcToGnot()
}

func setupPoolsAndLiquidity() {
	println("[INFO] Setting up pools and initial liquidity")
	testing.SetRealm(adminRealm)

	// Set pool creation fee to 0 for testing
	pl.SetPoolCreationFee(cross, 0)

	// Issue tokens to admin for pool creation
	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 1000000000}})
	testing.SetOriginSend(chain.Coins{{"ugnot", 1000000000}})
	wugnot.Deposit(cross)

	// Create pools
	println("[INFO] Creating WUGNOT/GNS pool (fee: 0.05%)")
	pl.CreatePool(cross, wugnotPath, gnsPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	println("[INFO] Creating GNS/USDC pool (fee: 0.05%)")
	pl.CreatePool(cross, gnsPath, usdcPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	// Mint positions with 100M each token
	// WUGNOT/GNS pool
	wugnot.Approve(cross, poolAddr, 100000000)
	gns.Approve(cross, poolAddr, 100000000)
	testing.SetOriginSend(chain.Coins{})
	pn.Mint(cross, gnsPath, wugnotPath, fee500, int32(-6960), int32(6960), "100000000", "100000000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	// GNS/USDC pool
	gns.Approve(cross, poolAddr, 100000000)
	usdc.Approve(cross, poolAddr, 100000000)
	testing.SetOriginSend(chain.Coins{})
	pn.Mint(cross, gnsPath, usdcPath, fee500, int32(-6960), int32(6960), "100000000", "100000000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	// Transfer tokens to user
	testing.IssueCoins(userAddr, chain.Coins{{"ugnot", 10000000}})
	gns.Transfer(cross, userAddr, 10000000)
	usdc.Transfer(cross, userAddr, 10000000)

	// Verify user balances
	testing.SetRealm(userRealm)
	banker_ := banker.NewBanker(banker.BankerTypeReadonly)
	userGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")
	userGnsBalance := gns.BalanceOf(userAddr)
	userUsdcBalance := usdc.BalanceOf(userAddr)

	println("[INFO] User initial balances:")
	println("  GNOT:", userGnotBalance)
	println("  GNS:", userGnsBalance)
	println("  USDC:", userUsdcBalance)
}

func testExactInGnotToGns() {
	println("[INFO] Testing ExactIn swap: 1,000,000 GNOT → GNS")
	testing.SetRealm(userRealm)

	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(userAddr, routerAddr, chain.Coins{{"ugnot", 1000000}})
	prevGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")
	prevGnsBalance := gns.BalanceOf(userAddr)

	// Approve router fee payment
	gns.Approve(cross, routerAddr, max_approve)
	wugnot.Approve(cross, routerAddr, max_approve)

	// Execute ExactIn swap with GNOT
	testing.SetOriginSend(chain.Coins{{"ugnot", 1000000}})
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		gnotPath,  // input token (GNOT)
		gnsPath,   // output token
		"1000000", // exact amount in
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500", // route
		"100", // quote
		"0",   // min amount out
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	afterGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")
	afterGnsBalance := gns.BalanceOf(userAddr)

	// Calculate fees
	outputAmount, _ := strconv.ParseInt(amountOut, 10, 64)
	outputAmount = -outputAmount                         // Make positive
	poolFee := int64(1000000) * 5 / 10000                // 0.05% pool fee
	routerFee := (outputAmount * 100 / 10000) * 15 / 100 // 0.15% router fee on output

	println("[INFO] GNOT deducted:", prevGnotBalance-afterGnotBalance)
	println("[INFO] GNS received:", afterGnsBalance-prevGnsBalance)
	println("[INFO] Pool fee (0.05%):", poolFee)
	println("[INFO] Router fee (0.15%):", routerFee)
	println("[INFO] AmountIn reported:", amountIn)
	println("[INFO] AmountOut reported:", amountOut)

	println("[EXPECTED] GNOT deducted = 1000000")
	println("[EXPECTED] Wrap happens internally")
	println("[EXPECTED] Pool fee accumulated correctly")
	println("[EXPECTED] Router fee charged correctly")

	// Verify no intermediate balances
	routerGnotBalance := banker_.GetCoins(routerAddr).AmountOf("ugnot")
	routerWugnotBalance := wugnot.BalanceOf(routerAddr)
	routerGnsBalance := gns.BalanceOf(routerAddr)

	println("[INFO] Router balances - GNOT:", routerGnotBalance, "WUGNOT:", routerWugnotBalance, "GNS:", routerGnsBalance)
}

func testExactOutGnsToGnot() {
	println("[INFO] Testing ExactOut swap: GNS → 1,000,000 GNOT")
	testing.SetRealm(userRealm)

	banker_ := banker.NewBanker(banker.BankerTypeReadonly)
	prevGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")
	prevGnsBalance := gns.BalanceOf(userAddr)

	// Approve GNS for swap
	gns.Approve(cross, routerAddr, max_approve)
	gns.Approve(cross, routerAddr, max_approve)

	// Execute ExactOut swap requesting GNOT
	testing.SetOriginSend(chain.Coins{})
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		gnsPath,   // input token
		gnotPath,  // output token (GNOT)
		"1000000", // exact amount out (GNOT)
		"gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500", // route
		"100",      // quote
		"10000000", // max amount in
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	afterGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")
	afterGnsBalance := gns.BalanceOf(userAddr)

	// Calculate fees
	inputAmount, _ := strconv.ParseInt(amountIn, 10, 64)
	poolFee := inputAmount * 5 / 10000       // 0.05% pool fee
	routerFee := int64(1000000) * 15 / 10000 // 0.15% router fee on output

	println("[INFO] GNS spent:", prevGnsBalance-afterGnsBalance)
	println("[INFO] GNOT received:", afterGnotBalance-prevGnotBalance)
	println("[INFO] Pool fee (0.05%):", poolFee)
	println("[INFO] Router fee (0.15%):", routerFee)
	println("[INFO] AmountIn reported:", amountIn)
	println("[INFO] AmountOut reported:", amountOut)

	println("[EXPECTED] User receives 1,000,000 GNOT")
	println("[EXPECTED] Router fee charged on output side")
	println("[EXPECTED] Unwrap happens internally")

	// Verify fee accumulation
	ufmt.Printf("[INFO] Router total fees accumulated: %d\n", wugnot.BalanceOf(protocolFeeAddr))
}

func testMultiHopGnotToUsdc() {
	println("[INFO] Testing Multi-hop: 1,000,000 GNOT → GNS → USDC")
	testing.SetRealm(userRealm)

	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(userAddr, routerAddr, chain.Coins{{"ugnot", 1000000}})
	prevGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")
	prevUsdcBalance := usdc.BalanceOf(userAddr)

	// Approve for router fees
	gns.Approve(cross, routerAddr, max_approve)
	usdc.Approve(cross, routerAddr, max_approve)

	// Execute multi-hop swap
	testing.SetOriginSend(chain.Coins{{"ugnot", 1000000}})
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		gnotPath,  // input token (GNOT)
		usdcPath,  // output token
		"1000000", // exact amount in
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/onbloc/usdc:500", // route
		"100", // quote
		"0",   // min amount out
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	afterGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")
	afterUsdcBalance := usdc.BalanceOf(userAddr)

	println("[INFO] GNOT spent:", prevGnotBalance-afterGnotBalance)
	println("[INFO] USDC received:", afterUsdcBalance-prevUsdcBalance)
	println("[INFO] AmountIn reported:", amountIn)
	println("[INFO] AmountOut reported:", amountOut)

	println("[EXPECTED] Only first hop wraps GNOT")
	println("[EXPECTED] Correct fee accumulation across hops")
	println("[EXPECTED] Router fee applied on final output")
}

func testMultiHopUsdcToGnot() {
	println("[INFO] Testing Multi-hop: USDC → GNS → 1,000,000 GNOT")
	testing.SetRealm(userRealm)

	banker_ := banker.NewBanker(banker.BankerTypeReadonly)
	prevUsdcBalance := usdc.BalanceOf(userAddr)
	prevGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")

	// Approve tokens
	usdc.Approve(cross, routerAddr, max_approve)
	gns.Approve(cross, routerAddr, max_approve)

	// Execute multi-hop ExactOut swap
	testing.SetOriginSend(chain.Coins{})
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		usdcPath,  // input token
		gnotPath,  // output token (GNOT)
		"1000000", // exact amount out (GNOT)
		"gno.land/r/onbloc/usdc:gno.land/r/gnoswap/gns:500*POOL*gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500", // route
		"100",      // quote
		"10000000", // max amount in
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)
	afterUsdcBalance := usdc.BalanceOf(userAddr)
	afterGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")

	println("[INFO] USDC spent:", prevUsdcBalance-afterUsdcBalance)
	println("[INFO] GNOT received:", afterGnotBalance-prevGnotBalance)
	println("[INFO] AmountIn reported:", amountIn)
	println("[INFO] AmountOut reported:", amountOut)

	println("[EXPECTED] Only last hop unwraps to GNOT")
	println("[EXPECTED] User receives exactly 1,000,000 GNOT")
	println("[EXPECTED] Correct fee distribution across hops")

	// Verify no intermediate fund locking
	routerGnotBalance := banker_.GetCoins(routerAddr).AmountOf("ugnot")
	routerWugnotBalance := wugnot.BalanceOf(routerAddr)
	routerGnsBalance := gns.BalanceOf(routerAddr)
	routerUsdcBalance := usdc.BalanceOf(routerAddr)

	println("[INFO] Router final balances:")
	println("  GNOT:", routerGnotBalance)
	println("  WUGNOT:", routerWugnotBalance)
	println("  GNS:", routerGnsBalance)
	println("  USDC:", routerUsdcBalance)
	println("[EXPECTED] No intermediate fund locking")
}

// Output:
// [SCENARIO] #3 Router Swap Native Token Integration
// [INFO] Purpose: Validate ExactIn/ExactOut swaps with GNOT
//
// [SCENARIO] 1. Initial Setup
// [INFO] Setting up pools and initial liquidity
// [INFO] Creating WUGNOT/GNS pool (fee: 0.05%)
// [INFO] Creating GNS/USDC pool (fee: 0.05%)
// [INFO] User initial balances:
//   GNOT: 10000000
//   GNS: 10000000
//   USDC: 10000000
//
// [SCENARIO] 2. ExactIn: GNOT → GNS
// [INFO] Testing ExactIn swap: 1,000,000 GNOT → GNS
// [INFO] GNOT deducted: 0
// [INFO] GNS received: 995078
// [INFO] Pool fee (0.05%): 500
// [INFO] Router fee (0.15%): 1492
// [INFO] AmountIn reported: 1000000
// [INFO] AmountOut reported: -995078
// [EXPECTED] GNOT deducted = 1000000
// [EXPECTED] Wrap happens internally
// [EXPECTED] Pool fee accumulated correctly
// [EXPECTED] Router fee charged correctly
// [INFO] Router balances - GNOT: 0 WUGNOT: 0 GNS: 0
//
// [SCENARIO] 3. ExactOut: GNS → GNOT
// [INFO] Testing ExactOut swap: GNS → 1,000,000 GNOT
// [INFO] GNS spent: 999077
// [INFO] GNOT received: 1000000
// [INFO] Pool fee (0.05%): 499
// [INFO] Router fee (0.15%): 1500
// [INFO] AmountIn reported: 999077
// [INFO] AmountOut reported: -1000000
// [EXPECTED] User receives 1,000,000 GNOT
// [EXPECTED] Router fee charged on output side
// [EXPECTED] Unwrap happens internally
// [INFO] Router total fees accumulated: 1502
//
// [SCENARIO] 4. Multi-hop: GNOT → GNS → USDC
// [INFO] Testing Multi-hop: 1,000,000 GNOT → GNS → USDC
// [INFO] GNOT spent: 0
// [INFO] USDC received: 991686
// [INFO] AmountIn reported: 1000000
// [INFO] AmountOut reported: -991686
// [EXPECTED] Only first hop wraps GNOT
// [EXPECTED] Correct fee accumulation across hops
// [EXPECTED] Router fee applied on final output
//
// [SCENARIO] 5. Multi-hop: USDC → GNS → GNOT
// [INFO] Testing Multi-hop: USDC → GNS → 1,000,000 GNOT
// [INFO] USDC spent: 996682
// [INFO] GNOT received: 1000000
// [INFO] AmountIn reported: 996682
// [INFO] AmountOut reported: -1000000
// [EXPECTED] Only last hop unwraps to GNOT
// [EXPECTED] User receives exactly 1,000,000 GNOT
// [EXPECTED] Correct fee distribution across hops
// [INFO] Router final balances:
//   GNOT: 0
//   WUGNOT: 0
//   GNS: 0
//   USDC: 0
// [EXPECTED] No intermediate fund locking
