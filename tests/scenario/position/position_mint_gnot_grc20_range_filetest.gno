// position mint GNOT/GRC20 range

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

	token0Path = "gno.land/r/demo/wugnot"
	token1Path = "gno.land/r/gnoswap/v1/gns"
	fee        = uint32(3000)
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool with GNOT/GNS pair")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint in-range position")
	mintInRangePosition()
	println()

	ufmt.Println("[SCENARIO] 3. Check in-range position state")
	checkInRangePosition()
	println()

	ufmt.Println("[SCENARIO] 4. Mint out-range position")
	mintOutRangePosition()
	println()

	ufmt.Println("[SCENARIO] 5. Check out-range position state")
	checkOutRangePosition()
	println()

	ufmt.Println("[SCENARIO] 6. Execute swap to test ranges")
	executeSwap()
	println()

	ufmt.Println("[SCENARIO] 7. Verify final positions")
	verifyFinalPositions()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFeeByAdmin(cross, 0)

	testing.SetRealm(adminRealm)

	defaultTokenAmount := int64(100000000)

	ufmt.Println("[INFO] Distributing GNS tokens")
	gns.Transfer(cross, aliceAddr, defaultTokenAmount)

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

	ufmt.Println("[INFO] Creating GNOT/GNS pool at tick 0")
	pool.CreatePool(
		cross,
		token0Path,
		token1Path,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
}

func mintInRangePosition() {
	testing.SetRealm(aliceRealm)
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Minting in-range position")
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

func checkInRangePosition() {
	testing.SetRealm(adminRealm)
	pos, _ := position.GetPosition(1)

	ufmt.Printf("[EXPECTED] Position liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Position should be in range\n")
	ufmt.Printf("[EXPECTED] Token0 balance should be %s\n", pos.Token0Balance().ToString())
	ufmt.Printf("[EXPECTED] Token1 balance should be %s\n", pos.Token1Balance().ToString())
}

func mintOutRangePosition() {
	testing.SetRealm(aliceRealm)
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Minting out-range position")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		token0Path,
		token1Path,
		fee,
		4980,
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

func checkOutRangePosition() {
	testing.SetRealm(adminRealm)
	pos, _ := position.GetPosition(2)

	ufmt.Printf("[EXPECTED] Position liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Position should be out of range\n")
	ufmt.Printf("[EXPECTED] Token0 balance should be %s\n", pos.Token0Balance().ToString())
	ufmt.Printf("[EXPECTED] Token1 balance should be %s\n", pos.Token1Balance().ToString())
}

func executeSwap() {
	testing.SetRealm(adminRealm)
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, poolAddr, consts.INT64_MAX)

	testing.SetRealm(routerRealm)
	ufmt.Println("[INFO] Executing swap to test ranges")
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

func verifyFinalPositions() {
	testing.SetRealm(adminRealm)

	pos1fee0, pos1fee1 := position.UnclaimedFee(1)
	pos2fee0, pos2fee1 := position.UnclaimedFee(2)

	ufmt.Println("[INFO] Checking final position states")
	ufmt.Printf("[EXPECTED] Position 1 should still be in range\n")
	ufmt.Printf("[EXPECTED] Position 1 should have fee0: %s\n", pos1fee0.ToString())
	ufmt.Printf("[EXPECTED] Position 1 should have fee1: %s\n", pos1fee1.ToString())
	ufmt.Printf("[EXPECTED] Position 2 should remain out of range\n")
	ufmt.Printf("[EXPECTED] Position 2 should have no fee0: %s\n", pos2fee0.ToString())
	ufmt.Printf("[EXPECTED] Position 2 should have no fee1: %s\n", pos2fee1.ToString())
}

// Output:
// [SCENARIO] 1. Initialize pool with GNOT/GNS pair
// [INFO] Distributing GNS tokens
// [INFO] Distributing WUGNOT tokens
// [INFO] Initial GNS balance of Alice: 100000000
// [INFO] Initial WUGNOT balance of Alice: 100000000
// [INFO] Creating GNOT/GNS pool at tick 0
//
// [SCENARIO] 2. Mint in-range position
// [INFO] Minting in-range position
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 170132354
// [EXPECTED] Amount0 should be 50000000
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 3. Check in-range position state
// [EXPECTED] Position liquidity should be 170132354
// [EXPECTED] Position should be in range
// [EXPECTED] Token0 balance should be 50000000
// [EXPECTED] Token1 balance should be 50000000
//
// [SCENARIO] 4. Mint out-range position
// [INFO] Minting out-range position
// [EXPECTED] Position ID should be 2
// [EXPECTED] Liquidity should be 680471001
// [EXPECTED] Amount0 should be 50000000
// [EXPECTED] Amount1 should be 0
//
// [SCENARIO] 5. Check out-range position state
// [EXPECTED] Position liquidity should be 680471001
// [EXPECTED] Position should be out of range
// [EXPECTED] Token0 balance should be 50000000
// [EXPECTED] Token1 balance should be 0
//
// [SCENARIO] 6. Execute swap to test ranges
// [INFO] Executing swap to test ranges
// [EXPECTED] Swap amount0 should be 10000000
// [EXPECTED] Swap amount1 should be -9418086
//
// [SCENARIO] 7. Verify final positions
// [INFO] Checking final position states
// [EXPECTED] Position 1 should still be in range
// [EXPECTED] Position 1 should have fee0: 29999
// [EXPECTED] Position 1 should have fee1: 0
// [EXPECTED] Position 2 should remain out of range
// [EXPECTED] Position 2 should have no fee0: 0
// [EXPECTED] Position 2 should have no fee1: 0
