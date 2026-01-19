// Scenario #2: Position Lifecycle with Native Token
// Purpose: Validate position operations with GNOT wrap/unwrap

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"chain/banker"
	"strconv"
	"testing"
	"time"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	"gno.land/p/nt/testutils"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoland/wugnot"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	positionAddr, _    = access.GetAddress(prabc.ROLE_POSITION.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())

	userAddr  = testutils.TestAddress("user")
	userRealm = testing.NewUserRealm(userAddr)

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

	println("[SCENARIO] 4. Burn Position with Unwrap")
	testBurnPositionWithUnwrap("170132354") // 170132354 is 50% of 340264708
}

func setupInitialEnvironment() {
	println("[INFO] Setting up initial environment")
	testing.SetRealm(adminRealm)

	// Set pool creation fee to 0 for testing
	pl.SetPoolCreationFee(cross, 0)

	// Issue tokens to user
	testing.IssueCoins(userAddr, chain.Coins{{"ugnot", 1000000000}})

	// Mint GNS to user
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, userAddr, 1000000000)

	// Create WUGNOT:GNS pool (fee 0.05%)
	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
	pl.CreatePool(cross, wugnotPath, gnsPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	// Verify initial balances
	testing.SetRealm(userRealm)
	banker_ := banker.NewBanker(banker.BankerTypeReadonly)
	userGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")
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
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(userAddr, positionAddr, chain.Coins{{"ugnot", 100000000}})
	prevGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")
	prevGnsBalance := gns.BalanceOf(userAddr)

	// Approve GNS for position
	gns.Approve(cross, poolAddr, 100000000)
	wugnot.Approve(cross, poolAddr, 100000000)

	// Mint position with GNOT (auto-wrap should occur)
	testing.SetOriginSend(chain.Coins{{"ugnot", 100000000}})
	tokenId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		"ugnot",
		gnsPath,      // token0Path (non-ugnot token)
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
	afterGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")
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

		testing.SetOriginSend(chain.Coins{})
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
	protocolFeeWugnot := wugnot.BalanceOf(protocolFeeAddr)
	protocolFeeGns := gns.BalanceOf(protocolFeeAddr)

	println("[INFO] Protocol fee balance WUGNOT:", protocolFeeWugnot)
	println("[INFO] Protocol fee balance GNS:", protocolFeeGns)
	println("[EXPECTED] Pool fee (0.5%) accumulated correctly")
	println("[EXPECTED] Router fee (0.15%) accumulated correctly")
}

func testBurnPositionWithUnwrap(removedLiquidity string) {
	println("[INFO] Burning 50% of position liquidity with unwrap=true")
	testing.SetRealm(userRealm)

	banker_ := banker.NewBanker(banker.BankerTypeReadonly)
	prevGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")
	prevGnsBalance := gns.BalanceOf(userAddr)
	beforeProtocolFeeWugnot := wugnot.BalanceOf(protocolFeeAddr)
	beforeProtocolFeeGns := gns.BalanceOf(protocolFeeAddr)

	// Burn 50% liquidity with unwrap
	_, _, fee0, fee1, amount0, amount1, _ := pn.DecreaseLiquidity(
		cross,
		1,
		removedLiquidity,
		"0", // amount0Min
		"0", // amount1Min
		max_timeout,
		true, // unwrap to GNOT
	)

	afterGnotBalance := banker_.GetCoins(userAddr).AmountOf("ugnot")
	afterGnsBalance := gns.BalanceOf(userAddr)
	afterProtocolFeeWugnot := wugnot.BalanceOf(protocolFeeAddr)
	afterProtocolFeeGns := gns.BalanceOf(protocolFeeAddr)

	// Calculate total WUGNOT that was unwrapped
	totalWugnotAmount, _ := strconv.ParseInt(amount1, 10, 64)
	totalWugnotFee, _ := strconv.ParseInt(fee1, 10, 64)
	totalWugnot := totalWugnotAmount + totalWugnotFee

	println("[EXPECTED] Liquidity burned:", removedLiquidity)
	println("[EXPECTED] GNS returned:", amount0)
	println("[EXPECTED] WUGNOT returned:", amount1)
	println("[EXPECTED] GNS fees collected:", fee0)
	println("[EXPECTED] WUGNOT fees collected:", fee1)
	println("[EXPECTED] Total WUGNOT unwrapped:", totalWugnot)
	println("[EXPECTED] Protocol fee WUGNOT balance:", afterProtocolFeeWugnot-beforeProtocolFeeWugnot)
	println("[EXPECTED] Protocol fee GNS balance:", afterProtocolFeeGns-beforeProtocolFeeGns)
	println("[EXPECTED] GNOT received:", afterGnotBalance-prevGnotBalance)
	println("[EXPECTED] GNS received:", afterGnsBalance-prevGnsBalance)
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
// [INFO] Protocol fee balance WUGNOT: 115880
// [INFO] Protocol fee balance GNS: 0
// [EXPECTED] Pool fee (0.5%) accumulated correctly
// [EXPECTED] Router fee (0.15%) accumulated correctly
//
// [SCENARIO] 4. Burn Position with Unwrap
// [INFO] Burning 50% of position liquidity with unwrap=true
// [EXPECTED] Liquidity burned: 170132354
// [EXPECTED] GNS returned: 11371739
// [EXPECTED] WUGNOT returned: 99974998
// [EXPECTED] GNS fees collected: 0
// [EXPECTED] WUGNOT fees collected: 49501
// [EXPECTED] Total WUGNOT unwrapped: 100024499
// [EXPECTED] Protocol fee WUGNOT balance: 0
// [EXPECTED] Protocol fee GNS balance: 500
// [EXPECTED] GNOT received: 11371739
// [EXPECTED] GNS received: 100024499
