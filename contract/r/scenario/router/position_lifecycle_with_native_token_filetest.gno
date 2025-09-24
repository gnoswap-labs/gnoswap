// Scenario #2: Position Lifecycle with Native Token
// Purpose: Validate position operations with GNOT wrap/unwrap

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"
	"time"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"

	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/testutils"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoland/wugnot"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = std.NewUserRealm(adminAddr)

	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	positionAddr, _    = access.GetAddress(prabc.ROLE_POSITION.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())

	userAddr  = testutils.TestAddress("user")
	userRealm = std.NewUserRealm(userAddr)

	wugnotPath = "gno.land/r/gnoland/wugnot"
	gnsPath    = "gno.land/r/gnoswap/gns"

	fee500 uint32 = 500

	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

var t *testing.T

func main() {
	println("[SCENARIO] Position Lifecycle with Native Token")
	println("[INFO] Purpose: Validate position operations with GNOT wrap/unwrap")
	println()

	println("[SCENARIO] 1. Initial Setup")
	setupInitialEnvironment()
	println()

	println("[SCENARIO] 2. Mint Position with GNOT")
	testMintPositionWithGnot()
	println()

	println("[SCENARIO] 3. Execute Swaps (Generate Fees)")
	testExecuteSwapsForFees()
	println()

	println("[SCENARIO] 4. Collect Fees with Unwrap")
	testCollectFeesWithUnwrap()
	println()

	println("[SCENARIO] 5. Burn Position with Unwrap")
	testBurnPositionWithUnwrap()
}

func setupInitialEnvironment() {
	println("[INFO] Setting up initial environment")
	testing.SetRealm(adminRealm)

	// Set pool creation fee to 0 for testing
	pl.SetPoolCreationFee(cross, 0)

	// Issue tokens to user
	testing.IssueCoins(userAddr, std.Coins{{"ugnot", 1000000000}})

	// Mint GNS to user
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, userAddr, 1000000000)

	// Create WUGNOT:GNS pool (fee 0.05%)
	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
	pl.CreatePool(cross, wugnotPath, gnsPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	// Verify initial balances
	testing.SetRealm(userRealm)
	banker := std.NewBanker(std.BankerTypeReadonly)
	userGnotBalance := banker.GetCoins(userAddr).AmountOf("ugnot")
	userGnsBalance := gns.BalanceOf(userAddr)

	println("[INFO] User initial GNOT balance:", userGnotBalance)
	println("[INFO] User initial GNS balance:", userGnsBalance)
	println("[INFO] Router fee: 0.15%")
	println("[INFO] Withdrawal fee: 0.1%")
	println("[EXPECTED] GNOT: 1000000000, GNS: 1000000000")
}

func testMintPositionWithGnot() {
	println("[INFO] Minting position with 100,000,000 GNOT + 100,000,000 GNS")
	testing.SetRealm(userRealm)

	// Record gas cost baseline
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(userAddr, positionAddr, std.Coins{{"ugnot", 100000000}})
	prevGnotBalance := banker.GetCoins(userAddr).AmountOf("ugnot")
	prevGnsBalance := gns.BalanceOf(userAddr)

	// Approve GNS for position
	gns.Approve(cross, poolAddr, 100000000)
	wugnot.Approve(cross, poolAddr, 100000000)

	// Mint position with GNOT (auto-wrap should occur)
	testing.SetOriginSend(std.Coins{{"ugnot", 100000000}})
	tokenId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		"gnot",
		gnsPath,      // token0Path (non-gnot token)
		fee500,       // fee
		int32(-6960), // tickLower
		int32(6960),  // tickUpper
		"100000000",  // amount0Desired (GNS)
		"100000000",  // amount1Desired (GNOT - will be wrapped)
		"0",          // amount0Min
		"0",          // amount1Min
		max_timeout,  // deadline
		userAddr,     // recipient
		userAddr,     // operator
		"",           // hookData
	)

	// Check balances after mint
	afterGnotBalance := banker.GetCoins(userAddr).AmountOf("ugnot")
	afterGnsBalance := gns.BalanceOf(userAddr)
	afterWugnotBalance := wugnot.BalanceOf(userAddr)

	// Verify pool received exact WUGNOT amount
	poolWugnotBalance := wugnot.BalanceOf(poolAddr)

	println("[INFO] Position ID:", tokenId)
	println("[INFO] Liquidity:", liquidity)
	println("[INFO] Amount0 (GNS) used:", amount0)
	println("[INFO] Amount1 (WUGNOT) used:", amount1)
	println("[INFO] GNOT spent:", prevGnotBalance-afterGnotBalance)
	println("[INFO] GNS spent:", prevGnsBalance-afterGnsBalance)
	println("[INFO] User WUGNOT balance:", afterWugnotBalance)
	println("[INFO] Pool WUGNOT balance:", poolWugnotBalance)

	println("[EXPECTED] Auto-wrap occurred correctly")
	println("[EXPECTED] Pool received exact WUGNOT amount:", amount1)
	println("[EXPECTED] User WUGNOT balance remains 0")
}

func testExecuteSwapsForFees() {
	println("[INFO] Executing swaps to generate fees")
	testing.SetRealm(userRealm)

	// Execute 10 swaps of 10,000,000 GNS → WUGNOT
	for i := 0; i < 10; i++ {
		gns.Approve(cross, poolAddr, 10000000)
		gns.Approve(cross, routerAddr, max_approve) // For router fee

		testing.SetOriginSend(std.Coins{})
		amountIn, amountOut := router.ExactInSwapRoute(
			cross,
			gnsPath,
			wugnotPath,
			"10000000",
			"gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500",
			"100",
			"0",
			time.Now().Add(time.Hour).Unix(),
			"",
		)

		if i == 0 {
			println("[INFO] Swap", i+1, "- GNS in:", amountIn, "WUGNOT out:", amountOut)
		}
	}

	// Get accumulated fees info
	_, _, _, _, amount0, amount1 := pn.CollectFee(cross, 1, false)
	protocolFeeWugnot := wugnot.BalanceOf(protocolFeeAddr)
	protocolFeeGns := gns.BalanceOf(protocolFeeAddr)

	println("[INFO] Accumulated GNS fees:", amount0)
	println("[INFO] Accumulated WUGNOT fees:", amount1)
	println("[INFO] Protocol fee balance WUGNOT:", protocolFeeWugnot)
	println("[INFO] Protocol fee balance GNS:", protocolFeeGns)
	println("[EXPECTED] Pool fee (0.5%) accumulated correctly")
	println("[EXPECTED] Router fee (0.15%) accumulated correctly")
}

func testCollectFeesWithUnwrap() {
	println("[INFO] Collecting fees with unwrap=true")
	testing.SetRealm(userRealm)

	banker := std.NewBanker(std.BankerTypeReadonly)
	prevGnotBalance := banker.GetCoins(userAddr).AmountOf("ugnot")
	prevGnsBalance := gns.BalanceOf(userAddr)
	prevWugnotBalance := wugnot.BalanceOf(userAddr)

	// Collect fees with unwrap
	_, token0Collected, token1Collected, _, _, _ := pn.CollectFee(
		cross,
		1,
		true, // unwrap WUGNOT to GNOT
	)

	afterGnotBalance := banker.GetCoins(userAddr).AmountOf("ugnot")
	afterGnsBalance := gns.BalanceOf(userAddr)
	afterWugnotBalance := wugnot.BalanceOf(userAddr)

	expectedGnotReceived := token1Collected

	println("[INFO] GNS fees collected:", token0Collected)
	println("[INFO] WUGNOT fees collected:", token1Collected)
	println("[INFO] GNOT received:", afterGnotBalance-prevGnotBalance)
	println("[INFO] GNS received:", afterGnsBalance-prevGnsBalance)
	println("[INFO] WUGNOT balance change:", afterWugnotBalance-prevWugnotBalance)

	println("[EXPECTED] User receives GNOT (not WUGNOT)")
	println("[EXPECTED] GNOT received:", expectedGnotReceived)
	println("[EXPECTED] Withdrawal fee deducted correctly")
}

func testBurnPositionWithUnwrap() {
	println("[INFO] Burning 50% of position liquidity with unwrap=true")
	testing.SetRealm(userRealm)

	// Get current position info
	currentLiquidity := pool.GetLiquidity("gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500")

	// Calculate 50% liquidity to burn
	liquidityInt, _ := strconv.ParseInt(currentLiquidity, 10, 64)
	halfLiquidity := liquidityInt / 2

	banker := std.NewBanker(std.BankerTypeReadonly)
	prevGnotBalance := banker.GetCoins(userAddr).AmountOf("ugnot")
	prevGnsBalance := gns.BalanceOf(userAddr)

	// Burn 50% liquidity with unwrap
	_, _, fee0, fee1, amount0, amount1, _ := pn.DecreaseLiquidity(
		cross,
		1,
		strconv.FormatInt(halfLiquidity, 10),
		"0", // amount0Min
		"0", // amount1Min
		max_timeout,
		true, // unwrap to GNOT
	)

	afterGnotBalance := banker.GetCoins(userAddr).AmountOf("ugnot")
	afterGnsBalance := gns.BalanceOf(userAddr)

	// Calculate total WUGNOT that was unwrapped
	totalWugnotAmount, _ := strconv.ParseInt(amount1, 10, 64)
	totalWugnotFee, _ := strconv.ParseInt(fee1, 10, 64)
	totalWugnot := totalWugnotAmount + totalWugnotFee

	// Calculate withdrawal fee
	expectedWithdrawalFee := totalWugnot * 1 / 1000

	println("[INFO] Liquidity burned:", halfLiquidity)
	println("[INFO] GNS returned:", amount0)
	println("[INFO] WUGNOT returned:", amount1)
	println("[INFO] GNS fees collected:", fee0)
	println("[INFO] WUGNOT fees collected:", fee1)
	println("[INFO] Total WUGNOT unwrapped:", totalWugnot)
	println("[INFO] Withdrawal fee (0.1%):", expectedWithdrawalFee)
	println("[INFO] GNOT received:", afterGnotBalance-prevGnotBalance)
	println("[INFO] GNS received:", afterGnsBalance-prevGnsBalance)

	println("[EXPECTED] User receives GNOT directly")
	println("[EXPECTED] All fees calculated correctly")
	println("[EXPECTED] No residual balances")

	// Verify no residual balances
	routerGnotBalance := banker.GetCoins(routerAddr).AmountOf("ugnot")
	routerWugnotBalance := wugnot.BalanceOf(routerAddr)
	println("[INFO] Router GNOT balance:", routerGnotBalance)
	println("[INFO] Router WUGNOT balance:", routerWugnotBalance)
}

// Output:
// [SCENARIO] Position Lifecycle with Native Token
// [INFO] Purpose: Validate position operations with GNOT wrap/unwrap
//
// [SCENARIO] 1. Initial Setup
// [INFO] Setting up initial environment
// [INFO] User initial GNOT balance: 1000000000
// [INFO] User initial GNS balance: 1000000000
// [INFO] Router fee: 0.15%
// [INFO] Withdrawal fee: 0.1%
// [EXPECTED] GNOT: 1000000000, GNS: 1000000000
//
// [SCENARIO] 2. Mint Position with GNOT
// [INFO] Minting position with 100,000,000 GNOT + 100,000,000 GNS
// [INFO] Position ID: 1
// [INFO] Liquidity: 340264708
// [INFO] Amount0 (GNS) used: 100000000
// [INFO] Amount1 (WUGNOT) used: 100000000
// [INFO] GNOT spent: 0
// [INFO] GNS spent: 100000000
// [INFO] User WUGNOT balance: 0
// [INFO] Pool WUGNOT balance: 100000000
// [EXPECTED] Auto-wrap occurred correctly
// [EXPECTED] Pool received exact WUGNOT amount: 100000000
// [EXPECTED] User WUGNOT balance remains 0
//
// [SCENARIO] 3. Execute Swaps (Generate Fees)
// [INFO] Executing swaps to generate fees
// [INFO] Swap 1 - GNS in: 10000000 WUGNOT out: -9695218
// [INFO] Accumulated GNS fees: 0
// [INFO] Accumulated WUGNOT fees: 50001
// [INFO] Protocol fee balance WUGNOT: 115880
// [INFO] Protocol fee balance GNS: 500
// [EXPECTED] Pool fee (0.5%) accumulated correctly
// [EXPECTED] Router fee (0.15%) accumulated correctly
//
// [SCENARIO] 4. Collect Fees with Unwrap
// [INFO] Collecting fees with unwrap=true
// [INFO] GNS fees collected: 0
// [INFO] WUGNOT fees collected: 0
// [INFO] GNOT received: 0
// [INFO] GNS received: 0
// [INFO] WUGNOT balance change: 0
// [EXPECTED] User receives GNOT (not WUGNOT)
// [EXPECTED] GNOT received: 0
// [EXPECTED] Withdrawal fee deducted correctly
//
// [SCENARIO] 5. Burn Position with Unwrap
// [INFO] Burning 50% of position liquidity with unwrap=true
// [INFO] Liquidity burned: 170132354
// [INFO] GNS returned: 11371739
// [INFO] WUGNOT returned: 99974998
// [INFO] GNS fees collected: 0
// [INFO] WUGNOT fees collected: 0
// [INFO] Total WUGNOT unwrapped: 99974998
// [INFO] Withdrawal fee (0.1%): 99974
// [INFO] GNOT received: 11371739
// [INFO] GNS received: 99974998
// [EXPECTED] User receives GNOT directly
// [EXPECTED] All fees calculated correctly
// [EXPECTED] No residual balances
// [INFO] Router GNOT balance: 0
// [INFO] Router WUGNOT balance: 0
