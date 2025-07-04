// position mint and balance check

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
	ufmt.Println("[SCENARIO] 1. Initialize tokens and pool")
	initTokensAndPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint first position with Alice")
	mintAlicePosition()
	println()

	ufmt.Println("[SCENARIO] 3. Mint second position with Bob")
	mintBobPosition()
	println()

	ufmt.Println("[SCENARIO] 4. Check pool balances")
	checkPoolBalances()
	println()

	ufmt.Println("[SCENARIO] 5. Compare position balances")
	comparePositionBalances()
	println()
}

func initTokensAndPool() {
	testing.SetRealm(adminRealm)

	defaultTokenAmount := int64(1000000000000)

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
	wugnot.Transfer(cross, bobAddr, defaultTokenAmount)

	banker.SendCoins(adminAddr, consts.WUGNOT_ADDR, distributedGnotCoin)
	banker.SendCoins(adminAddr, aliceAddr, distributedGnotCoin)
	banker.SendCoins(adminAddr, bobAddr, distributedGnotCoin)

	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Printf("[INFO] Initial GNS balance of Alice: %d\n", gns.BalanceOf(aliceAddr))
	ufmt.Printf("[INFO] Initial GNS balance of Bob: %d\n", gns.BalanceOf(bobAddr))
	ufmt.Printf("[INFO] Initial WUGNOT balance of Alice: %d\n", wugnot.BalanceOf(aliceAddr))
	ufmt.Printf("[INFO] Initial WUGNOT balance of Bob: %d\n", wugnot.BalanceOf(bobAddr))

	ufmt.Printf("[INFO] Creating %s:%s:%d pool (tick: %d)\n", token0Path, token1Path, fee, 1)
	pool.CreatePool(
		cross,
		token0Path,
		token1Path,
		fee,
		common.TickMathGetSqrtRatioAtTick(1).ToString(),
	)
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

func mintBobPosition() {
	testing.SetRealm(bobRealm)
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Minting position for Bob")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		token0Path,
		token1Path,
		fee,
		-2160,
		11760,
		"99999999",
		"23027406",
		"0",
		"0",
		time.Now().Unix()+3600,
		bobAddr,
		bobAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func checkPoolBalances() {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Checking pool balances")
	poolInfo := pool.GetPool(token0Path, token1Path, fee)

	ufmt.Printf("[EXPECTED] Pool token0 balance should be %s\n", poolInfo.BalanceToken0().ToString())
	ufmt.Printf("[EXPECTED] Pool token1 balance should be %s\n", poolInfo.BalanceToken1().ToString())
	ufmt.Printf("[EXPECTED] Pool liquidity should be %s\n", poolInfo.Liquidity().ToString())
}

func comparePositionBalances() {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Comparing position balances")
	pos1, _ := position.GetPosition(1)
	pos2, _ := position.GetPosition(2)

	ufmt.Printf("[EXPECTED] Position 1 token0 balance should be %s\n", pos1.Token0Balance().ToString())
	ufmt.Printf("[EXPECTED] Position 1 token1 balance should be %s\n", pos1.Token1Balance().ToString())
	ufmt.Printf("[EXPECTED] Position 2 token0 balance should be %s\n", pos2.Token0Balance().ToString())
	ufmt.Printf("[EXPECTED] Position 2 token1 balance should be %s\n", pos2.Token1Balance().ToString())
	ufmt.Printf("[EXPECTED] Sum of positions should match pool balances\n")
}

// Output:
// [SCENARIO] 1. Initialize tokens and pool
// [INFO] Distributing GNS tokens
// [INFO] Distributing WUGNOT tokens
// [INFO] Initial GNS balance of Alice: 1000000000000
// [INFO] Initial GNS balance of Bob: 1000000000000
// [INFO] Initial WUGNOT balance of Alice: 1000000000000
// [INFO] Initial WUGNOT balance of Bob: 1000000000000
// [INFO] Creating gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000 pool (tick: 1)
//
// [SCENARIO] 2. Mint first position with Alice
// [INFO] Minting position for Alice
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 170103415
// [EXPECTED] Amount0 should be 49982991
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 3. Mint second position with Bob
// [INFO] Minting position for Bob
// [EXPECTED] Position ID should be 2
// [EXPECTED] Liquidity should be 224838465
// [EXPECTED] Amount0 should be 99939940
// [EXPECTED] Amount1 should be 23027406
//
// [SCENARIO] 4. Check pool balances
// [INFO] Checking pool balances
// [EXPECTED] Pool token0 balance should be 149922931
// [EXPECTED] Pool token1 balance should be 73027406
// [EXPECTED] Pool liquidity should be 394941880
//
// [SCENARIO] 5. Compare position balances
// [INFO] Comparing position balances
// [EXPECTED] Position 1 token0 balance should be 49982991
// [EXPECTED] Position 1 token1 balance should be 50000000
// [EXPECTED] Position 2 token0 balance should be 99939940
// [EXPECTED] Position 2 token1 balance should be 23027406
// [EXPECTED] Sum of positions should match pool balances
