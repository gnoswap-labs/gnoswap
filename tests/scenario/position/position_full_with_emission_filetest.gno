// position full with emission test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/gnoswap/v1/position"
)

var (
	adminAddr, _  = access.GetAddress(access.ROLE_ADMIN)
	adminRealm    = std.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(access.ROLE_POOL)
	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)
	routerRealm   = std.NewUserRealm(routerAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = std.NewUserRealm(aliceAddr)
	bobAddr    = testutils.TestAddress("bob")
	bobRealm   = std.NewUserRealm(bobAddr)

	token0Path = "gno.land/r/demo/wugnot"
	token1Path = "gno.land/r/gnoswap/v1/gns"
	fee        = uint32(3000)
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool and emission")
	initPoolAndEmission()
	println()

	ufmt.Println("[SCENARIO] 2. Mint position for Alice")
	mintAlicePosition()
	println()

	ufmt.Println("[SCENARIO] 3. Check initial emission state")
	checkInitialEmissionState()
	println()

	ufmt.Println("[SCENARIO] 4. Execute swaps to generate fees")
	executeSwaps()
	println()

	ufmt.Println("[SCENARIO] 5. Wait for emission period")
	waitForEmissionPeriod()
	println()

	ufmt.Println("[SCENARIO] 6. Collect fees and emission rewards")
	collectFeesAndRewards()
	println()

	ufmt.Println("[SCENARIO] 7. Verify final balances")
	verifyFinalBalances()
	println()
}

func initPoolAndEmission() {
	testing.SetRealm(std.NewCodeRealm(consts.STAKER_PATH))
	emission.RegisterGnsChangeCallback(cross)

	testing.SetRealm(adminRealm)

	defaultTokenAmount := int64(50000000)

	ufmt.Println("[INFO] Distributing GNS tokens")
	gns.Transfer(cross, aliceAddr, defaultTokenAmount)
	gns.Transfer(cross, bobAddr, defaultTokenAmount)

	ufmt.Println("[INFO] Distributing WUGNOT tokens")

	mintedGnotCoin := std.Coins{{"ugnot", 100000000000000}}
	distributedGnotCoin := std.Coins{{"ugnot", defaultTokenAmount}}

	testing.IssueCoins(adminAddr, mintedGnotCoin)

	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminAddr, consts.WUGNOT_ADDR, std.Coins{{"ugnot", defaultTokenAmount * 3}})
	testing.SetOriginSend(std.Coins{{"ugnot", defaultTokenAmount * 3}})
	wugnot.Deposit(cross)

	wugnot.Transfer(cross, aliceAddr, defaultTokenAmount)

	banker.SendCoins(adminAddr, consts.WUGNOT_ADDR, distributedGnotCoin)
	banker.SendCoins(adminAddr, aliceAddr, distributedGnotCoin)

	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Printf("[INFO] Initial GNS balance of Alice: %d\n", gns.BalanceOf(aliceAddr))
	ufmt.Printf("[INFO] Initial WUGNOT balance of Alice: %d\n", wugnot.BalanceOf(aliceAddr))

	ufmt.Println("[INFO] Creating pool")
	pool.CreatePool(
		cross,
		token0Path,
		token1Path,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	ufmt.Println("[INFO] Setting up emission rewards")
}

func mintAlicePosition() {
	testing.SetRealm(aliceRealm)
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Minting position for Alice")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		token0Path,
		token1Path,
		fee,
		-6960,
		6960,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func checkInitialEmissionState() {
	testing.SetRealm(adminRealm)
	pos, _ := position.GetPosition(1)

	ufmt.Printf("[EXPECTED] Initial position liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Initial emission rewards should be 0\n")
}

func executeSwaps() {
	testing.SetRealm(adminRealm)
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	testing.SetRealm(routerRealm)
	ufmt.Println("[INFO] Executing swap WUGNOT -> GNS")
	amount0, amount1 := pool.Swap(
		cross,
		token0Path,
		token1Path,
		fee,
		adminAddr,
		true,
		"10000000",
		consts.MIN_PRICE,
		adminAddr,
	)

	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", amount1)
}

func waitForEmissionPeriod() {
	ufmt.Println("[INFO] Waiting for emission period")
	testing.SkipHeights(100)
}

func collectFeesAndRewards() {
	testing.SetRealm(aliceRealm)
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Collecting fees and rewards")
	_, fee0, fee1, emission0, emission1, _ := position.CollectFee(cross, 1, false)

	ufmt.Printf("[EXPECTED] Collected fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Collected fee1 should be %s\n", fee1)
	ufmt.Printf("[EXPECTED] Collected emission0 should be %s\n", emission0)
	ufmt.Printf("[EXPECTED] Collected emission1 should be %s\n", emission1)
}

func verifyFinalBalances() {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Checking final balances")
	aliceWugnotBalance := wugnot.BalanceOf(aliceAddr)
	aliceGnsBalance := gns.BalanceOf(aliceAddr)

	ufmt.Printf("[EXPECTED] Alice final WUGNOT balance should be %d\n", aliceWugnotBalance)
	ufmt.Printf("[EXPECTED] Alice final GNS balance should be %d\n", aliceGnsBalance)
}

// Output:
// [SCENARIO] 1. Initialize pool and emission
// [INFO] Distributing GNS tokens
// [INFO] Distributing WUGNOT tokens
// [INFO] Initial GNS balance of Alice: 50000000
// [INFO] Initial WUGNOT balance of Alice: 50000000
// [INFO] Creating pool
// [INFO] Setting up emission rewards
//
// [SCENARIO] 2. Mint position for Alice
// [INFO] Minting position for Alice
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 170132354
// [EXPECTED] Amount0 should be 50000000
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 3. Check initial emission state
// [EXPECTED] Initial position liquidity should be 170132354
// [EXPECTED] Initial emission rewards should be 0
//
// [SCENARIO] 4. Execute swaps to generate fees
// [INFO] Executing swap WUGNOT -> GNS
// [EXPECTED] Swap amount0 should be 10000000
// [EXPECTED] Swap amount1 should be -9418086
//
// [SCENARIO] 5. Wait for emission period
// [INFO] Waiting for emission period
//
// [SCENARIO] 6. Collect fees and emission rewards
// [INFO] Collecting fees and rewards
// [EXPECTED] Collected fee0 should be 29700
// [EXPECTED] Collected fee1 should be 0
// [EXPECTED] Collected emission0 should be gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000
// [EXPECTED] Collected emission1 should be 29999
//
// [SCENARIO] 7. Verify final balances
// [INFO] Checking final balances
// [EXPECTED] Alice final WUGNOT balance should be 29700
// [EXPECTED] Alice final GNS balance should be 0
