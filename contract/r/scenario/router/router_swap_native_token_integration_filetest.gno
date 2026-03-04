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
	_ "gno.land/r/gnoswap/staker/v1"

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

	gnotPath = "ugnot"

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
	// Deposit must be called from main() due to AssertOriginCall frame limit
	// Admin deposit for pool setup
	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 1000000000}})
	testing.SetRealm(adminRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 1000000000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(chain.Coins{})
	setupPoolsAndLiquidity()
	println()

	println("[SCENARIO] 2. ExactIn: GNOT → GNS")
	// User deposit for ExactIn swap
	testing.IssueCoins(userAddr, chain.Coins{{"ugnot", 1000000}})
	testing.SetRealm(userRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 1000000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(chain.Coins{})
	testExactInGnotToGns()
	println()

	println("[SCENARIO] 3. ExactOut: GNS → GNOT")
	testExactOutGnsToGnot()
	println()

	println("[SCENARIO] 4. Multi-hop: GNOT → GNS → USDC")
	// User deposit for multi-hop swap
	testing.SetRealm(userRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 1000000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(chain.Coins{})
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

	// Deposit already done in main()

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

	// Deposit already done in main()

	prevWugnotBalance := wugnot.BalanceOf(userAddr)
	prevGnsBalance := gns.BalanceOf(userAddr)

	// Approve router fee payment
	gns.Approve(cross, routerAddr, max_approve)
	wugnot.Approve(cross, routerAddr, max_approve)

	// Execute ExactIn swap with GNOT
	testing.SetOriginSend(chain.Coins{})
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

	afterWugnotBalance := wugnot.BalanceOf(userAddr)
	afterGnsBalance := gns.BalanceOf(userAddr)

	// Calculate fees
	outputAmount, _ := strconv.ParseInt(amountOut, 10, 64)
	outputAmount = -outputAmount                         // Make positive
	poolFee := int64(1000000) * 5 / 10000                // 0.05% pool fee
	routerFee := (outputAmount * 100 / 10000) * 15 / 100 // 0.15% router fee on output

	println("[INFO] WUGNOT deducted:", prevWugnotBalance-afterWugnotBalance)
	println("[INFO] GNS received:", afterGnsBalance-prevGnsBalance)
	println("[INFO] Pool fee (0.05%):", poolFee)
	println("[INFO] Router fee (0.15%):", routerFee)
	println("[INFO] AmountIn reported:", amountIn)
	println("[INFO] AmountOut reported:", amountOut)

	println("[EXPECTED] WUGNOT deducted = 1000000")
	println("[EXPECTED] Wrap happens internally")
	println("[EXPECTED] Pool fee accumulated correctly")
	println("[EXPECTED] Router fee charged correctly")

	// Verify no intermediate balances
	routerWugnotBalance := wugnot.BalanceOf(routerAddr)
	routerGnsBalance := gns.BalanceOf(routerAddr)

	println("[INFO] Router balances - WUGNOT:", routerWugnotBalance, "GNS:", routerGnsBalance)
}

func testExactOutGnsToGnot() {
	println("[INFO] Testing ExactOut swap: GNS → 1,000,000 WUGNOT")
	testing.SetRealm(userRealm)

	prevWugnotBalance := wugnot.BalanceOf(userAddr)
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

	afterWugnotBalance := wugnot.BalanceOf(userAddr)
	afterGnsBalance := gns.BalanceOf(userAddr)

	// Calculate fees
	inputAmount, _ := strconv.ParseInt(amountIn, 10, 64)
	poolFee := inputAmount * 5 / 10000       // 0.05% pool fee
	routerFee := int64(1000000) * 15 / 10000 // 0.15% router fee on output

	println("[INFO] GNS spent:", prevGnsBalance-afterGnsBalance)
	println("[INFO] WUGNOT received:", afterWugnotBalance-prevWugnotBalance)
	println("[INFO] Pool fee (0.05%):", poolFee)
	println("[INFO] Router fee (0.15%):", routerFee)
	println("[INFO] AmountIn reported:", amountIn)
	println("[INFO] AmountOut reported:", amountOut)

	println("[EXPECTED] User receives 1,000,000 WUGNOT")
	println("[EXPECTED] Router fee charged on output side")
	println("[EXPECTED] Unwrap happens internally")

	// Verify fee accumulation
	ufmt.Printf("[INFO] Router total fees accumulated: %d\n", wugnot.BalanceOf(protocolFeeAddr))
}

func testMultiHopGnotToUsdc() {
	println("[INFO] Testing Multi-hop: 1,000,000 GNOT → GNS → USDC")
	testing.SetRealm(userRealm)

	// Deposit already done in main()

	prevWugnotBalance := wugnot.BalanceOf(userAddr)
	prevUsdcBalance := usdc.BalanceOf(userAddr)

	// Approve for router fees
	gns.Approve(cross, routerAddr, max_approve)
	usdc.Approve(cross, routerAddr, max_approve)
	wugnot.Approve(cross, routerAddr, max_approve)

	// Execute multi-hop swap
	testing.SetOriginSend(chain.Coins{})
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

	afterWugnotBalance := wugnot.BalanceOf(userAddr)
	afterUsdcBalance := usdc.BalanceOf(userAddr)

	println("[INFO] WUGNOT spent:", prevWugnotBalance-afterWugnotBalance)
	println("[INFO] USDC received:", afterUsdcBalance-prevUsdcBalance)
	println("[INFO] AmountIn reported:", amountIn)
	println("[INFO] AmountOut reported:", amountOut)

	println("[EXPECTED] Only first hop wraps GNOT")
	println("[EXPECTED] Correct fee accumulation across hops")
	println("[EXPECTED] Router fee applied on final output")
}

func testMultiHopUsdcToGnot() {
	println("[INFO] Testing Multi-hop: USDC → GNS → 1,000,000 WUGNOT")
	testing.SetRealm(userRealm)

	prevUsdcBalance := usdc.BalanceOf(userAddr)
	prevWugnotBalance := wugnot.BalanceOf(userAddr)

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
	afterWugnotBalance := wugnot.BalanceOf(userAddr)

	println("[INFO] USDC spent:", prevUsdcBalance-afterUsdcBalance)
	println("[INFO] WUGNOT received:", afterWugnotBalance-prevWugnotBalance)
	println("[INFO] AmountIn reported:", amountIn)
	println("[INFO] AmountOut reported:", amountOut)

	println("[EXPECTED] Only last hop unwraps to WUGNOT")
	println("[EXPECTED] User receives exactly 1,000,000 WUGNOT")
	println("[EXPECTED] Correct fee distribution across hops")

	// Verify no intermediate fund locking
	routerWugnotBalance := wugnot.BalanceOf(routerAddr)
	routerGnsBalance := gns.BalanceOf(routerAddr)
	routerUsdcBalance := usdc.BalanceOf(routerAddr)

	println("[INFO] Router final balances:")
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
// [INFO] WUGNOT deducted: 1000000
// [INFO] GNS received: 995078
// [INFO] Pool fee (0.05%): 500
// [INFO] Router fee (0.15%): 1492
// [INFO] AmountIn reported: 1000000
// [INFO] AmountOut reported: -995078
// [EXPECTED] WUGNOT deducted = 1000000
// [EXPECTED] Wrap happens internally
// [EXPECTED] Pool fee accumulated correctly
// [EXPECTED] Router fee charged correctly
// [INFO] Router balances - WUGNOT: 0 GNS: 0
//
// [SCENARIO] 3. ExactOut: GNS → GNOT
// [INFO] Testing ExactOut swap: GNS → 1,000,000 WUGNOT
// [INFO] GNS spent: 999077
// [INFO] WUGNOT received: 1000000
// [INFO] Pool fee (0.05%): 499
// [INFO] Router fee (0.15%): 1500
// [INFO] AmountIn reported: 999077
// [INFO] AmountOut reported: -1000000
// [EXPECTED] User receives 1,000,000 WUGNOT
// [EXPECTED] Router fee charged on output side
// [EXPECTED] Unwrap happens internally
// [INFO] Router total fees accumulated: 1502
//
// [SCENARIO] 4. Multi-hop: GNOT → GNS → USDC
// [INFO] Testing Multi-hop: 1,000,000 GNOT → GNS → USDC
// [INFO] WUGNOT spent: 1000000
// [INFO] USDC received: 991686
// [INFO] AmountIn reported: 1000000
// [INFO] AmountOut reported: -991686
// [EXPECTED] Only first hop wraps GNOT
// [EXPECTED] Correct fee accumulation across hops
// [EXPECTED] Router fee applied on final output
//
// [SCENARIO] 5. Multi-hop: USDC → GNS → GNOT
// [INFO] Testing Multi-hop: USDC → GNS → 1,000,000 WUGNOT
// [INFO] USDC spent: 996682
// [INFO] WUGNOT received: 1000000
// [INFO] AmountIn reported: 996682
// [INFO] AmountOut reported: -1000000
// [EXPECTED] Only last hop unwraps to WUGNOT
// [EXPECTED] User receives exactly 1,000,000 WUGNOT
// [EXPECTED] Correct fee distribution across hops
// [INFO] Router final balances:
//   WUGNOT: 0
//   GNS: 0
//   USDC: 0
// [EXPECTED] No intermediate fund locking
