// position decrease liquidity with GNOT/GNS pool

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/gnoswap/v1/position"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1

	GNOT        string = "gnot"
	GNS_PATH    string = "gno.land/r/gnoswap/gns"
	WUGNOT_PATH string = "gno.land/r/demo/wugnot"
)

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = std.NewUserRealm(adminAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())
	routerRealm     = std.NewUserRealm(routerAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())

	fee3000 uint32 = 3000 // 0.3% fee tier
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize GNOT/GNS 0.3% pool")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint position with native token")
	mintPosition()
	println()

	ufmt.Println("[SCENARIO] 3. Check position state before decrease")
	checkPositionBeforeDecrease()
	println()

	ufmt.Println("[SCENARIO] 4. Execute swap to generate fees")
	executeSwap()
	println()

	ufmt.Println("[SCENARIO] 5. Decrease liquidity without unwrapping (unwrapResult=false)")
	decreaseLiquidityNoUnwrap()
	println()

	ufmt.Println("[SCENARIO] 6. Decrease liquidity with unwrapping (unwrapResult=true)")
	decreaseLiquidityWithUnwrap()
	println()

	ufmt.Println("[SCENARIO] 7. Check final balances")
	checkFinalBalances()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	ufmt.Println("[INFO] Creating GNOT/GNS 0.3% pool")
	pool.CreatePool(
		cross,
		GNOT,
		GNS_PATH,
		fee3000,
		"79228162514264337593543950336", // price 1:1
	)
}

func mintPosition() {
	testing.SetRealm(adminRealm)

	// Approve tokens
	gns.Approve(cross, poolAddr, INT64_MAX)
	wugnot.Approve(cross, poolAddr, INT64_MAX)
	wugnot.Approve(cross, positionAddr, INT64_MAX)

	// Issue GNOT to position contract for operations
	testing.IssueCoins(positionAddr, std.Coins{{"ugnot", 500000000}})

	// Set origin send to simulate GNOT transfer from user
	testing.SetOriginSend(std.Coins{{"ugnot", 100000000}})

	ufmt.Println("[INFO] Minting position with native token")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		GNOT,
		GNS_PATH,
		fee3000,
		-6000,       // tickLower
		6000,        // tickUpper
		"100000000", // 100 GNOT
		"100000000", // 100 GNS
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)
	testing.SetOriginSend(std.Coins{{"ugnot", 0}})

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 (GNOT) should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 (GNS) should be %s\n", amount1)
}

func checkPositionBeforeDecrease() {
	testing.SetRealm(adminRealm)
	pos, _ := position.GetPosition(1)

	ufmt.Printf("[EXPECTED] Position liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Position tickLower should be %d\n", pos.TickLower())
	ufmt.Printf("[EXPECTED] Position tickUpper should be %d\n", pos.TickUpper())

	// Check unclaimed fees
	fee0, fee1 := position.UnclaimedFee(1)
	ufmt.Printf("[EXPECTED] Unclaimed fee0 (GNOT) should be %s\n", fee0.ToString())
	ufmt.Printf("[EXPECTED] Unclaimed fee1 (GNS) should be %s\n", fee1.ToString())
}

func executeSwap() {
	testing.SetRealm(adminRealm)

	// Wrap some GNOT for swap
	testing.SetOriginSend(std.Coins{{"ugnot", 10000000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(std.Coins{{"ugnot", 0}})

	wugnot.Approve(cross, poolAddr, INT64_MAX)
	wugnot.Approve(cross, routerAddr, INT64_MAX)

	p := pool.GetPool(WUGNOT_PATH, GNS_PATH, fee3000)
	ufmt.Printf("[INFO] Tick before swap: %d\n", p.Slot0Tick())

	// Set router context
	func() {
		ctx := testing.GetContext()
		ctx.CurrentRealm = routerRealm
		ctx.OriginCaller = adminAddr
		testing.SetContext(ctx)
	}()

	ufmt.Println("[INFO] Executing swap to generate fees")
	amount0, amount1 := pool.Swap(
		cross,
		WUGNOT_PATH,
		GNS_PATH,
		fee3000,
		adminAddr,
		true,
		"10000000", // Swap 10 WUGNOT for GNS
		MIN_PRICE,
		adminAddr,
	)

	p = pool.GetPool(WUGNOT_PATH, GNS_PATH, fee3000)
	ufmt.Printf("[INFO] Tick after swap: %d\n", p.Slot0Tick())
	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", amount1)
}

func decreaseLiquidityNoUnwrap() {
	testing.SetRealm(adminRealm)

	// Get current balances before decrease
	banker := std.NewBanker(std.BankerTypeRealmSend)
	ugnotBefore := banker.GetCoins(adminAddr).AmountOf("ugnot")
	wugnotBefore := wugnot.BalanceOf(adminAddr)
	gnsBefore := gns.BalanceOf(adminAddr)

	ufmt.Printf("[INFO] Balances before decrease (no unwrap):\n")
	ufmt.Printf("  UGNOT: %d\n", ugnotBefore)
	ufmt.Printf("  WUGNOT: %d\n", wugnotBefore)
	ufmt.Printf("  GNS: %d\n", gnsBefore)

	pos, _ := position.GetPosition(1)
	liquidityToRemove := pos.Liquidity().ToString()
	ufmt.Printf("[INFO] Removing 100%% liquidity: %s\n", liquidityToRemove)

	// First decrease - without unwrap
	_, liquidity, fee0, fee1, amount0, amount1, _ := position.DecreaseLiquidity(
		cross,
		1,
		liquidityToRemove,
		"0",
		"0",
		9999999999,
		false, // Don't unwrap
	)

	ufmt.Printf("[EXPECTED] Removed liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Fee0 (GNOT) should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Fee1 (GNS) should be %s\n", fee1)
	ufmt.Printf("[EXPECTED] Amount0 (GNOT) removed should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 (GNS) removed should be %s\n", amount1)

	// Check balances after decrease
	ugnotAfter := banker.GetCoins(adminAddr).AmountOf("ugnot")
	wugnotAfter := wugnot.BalanceOf(adminAddr)
	gnsAfter := gns.BalanceOf(adminAddr)

	ufmt.Printf("[INFO] Balances after decrease (no unwrap):\n")
	ufmt.Printf("  UGNOT: %d (change: %d)\n", ugnotAfter, ugnotAfter-ugnotBefore)
	ufmt.Printf("  WUGNOT: %d (change: %d)\n", wugnotAfter, wugnotAfter-wugnotBefore)
	ufmt.Printf("  GNS: %d (change: %d)\n", gnsAfter, gnsAfter-gnsBefore)

	ufmt.Printf("[EXPECTED] UGNOT balance should not change\n")
	ufmt.Printf("[EXPECTED] WUGNOT balance should increase\n")
	ufmt.Printf("[EXPECTED] GNS balance should increase\n")
}

func decreaseLiquidityWithUnwrap() {
	testing.SetRealm(adminRealm)

	// Mint another position for testing unwrap
	testing.SetOriginSend(std.Coins{{"ugnot", 50000000}})
	positionId, liquidity, _, _ := position.Mint(
		cross,
		GNOT,
		GNS_PATH,
		fee3000,
		-6000,
		6000,
		"50000000",
		"50000000",
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)
	testing.SetOriginSend(std.Coins{{"ugnot", 0}})

	ufmt.Printf("[INFO] Created new position %d with liquidity %s\n", positionId, liquidity)

	// Get current balances before decrease
	banker := std.NewBanker(std.BankerTypeRealmSend)
	ugnotBefore := banker.GetCoins(adminAddr).AmountOf("ugnot")
	wugnotBefore := wugnot.BalanceOf(adminAddr)
	gnsBefore := gns.BalanceOf(adminAddr)

	ufmt.Printf("[INFO] Balances before decrease (with unwrap):\n")
	ufmt.Printf("  UGNOT: %d\n", ugnotBefore)
	ufmt.Printf("  WUGNOT: %d\n", wugnotBefore)
	ufmt.Printf("  GNS: %d\n", gnsBefore)

	// Decrease with unwrap
	_, removedLiquidity, fee0, fee1, amount0, amount1, _ := position.DecreaseLiquidity(
		cross,
		positionId,
		liquidity, // Remove all liquidity
		"0",
		"0",
		9999999999,
		true, // Unwrap WUGNOT to GNOT
	)

	ufmt.Printf("[EXPECTED] Removed liquidity should be %s\n", removedLiquidity)
	ufmt.Printf("[EXPECTED] Fee0 (GNOT) should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Fee1 (GNS) should be %s\n", fee1)
	ufmt.Printf("[EXPECTED] Amount0 (GNOT) removed should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 (GNS) removed should be %s\n", amount1)

	// Check balances after decrease
	ugnotAfter := banker.GetCoins(adminAddr).AmountOf("ugnot")
	wugnotAfter := wugnot.BalanceOf(adminAddr)
	gnsAfter := gns.BalanceOf(adminAddr)

	ufmt.Printf("[INFO] Balances after decrease (with unwrap):\n")
	ufmt.Printf("  UGNOT: %d (change: %d)\n", ugnotAfter, ugnotAfter-ugnotBefore)
	ufmt.Printf("  WUGNOT: %d (change: %d)\n", wugnotAfter, wugnotAfter-wugnotBefore)
	ufmt.Printf("  GNS: %d (change: %d)\n", gnsAfter, gnsAfter-gnsBefore)

	ufmt.Printf("[EXPECTED] UGNOT balance should increase (from unwrap)\n")
	ufmt.Printf("[EXPECTED] WUGNOT balance should not change\n")
	ufmt.Printf("[EXPECTED] GNS balance should increase\n")
}

func checkFinalBalances() {
	testing.SetRealm(adminRealm)

	banker := std.NewBanker(std.BankerTypeRealmSend)
	ugnotFinal := banker.GetCoins(adminAddr).AmountOf("ugnot")
	wugnotFinal := wugnot.BalanceOf(adminAddr)
	gnsFinal := gns.BalanceOf(adminAddr)

	ufmt.Println("[INFO] Final balances:")
	ufmt.Printf("  UGNOT: %d\n", ugnotFinal)
	ufmt.Printf("  WUGNOT: %d\n", wugnotFinal)
	ufmt.Printf("  GNS: %d\n", gnsFinal)

	// Check both positions are cleared
	pos1, _ := position.GetPosition(1)
	pos2, _ := position.GetPosition(2)

	ufmt.Printf("[EXPECTED] Position 1 liquidity should be 0, got %s\n", pos1.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Position 2 liquidity should be 0, got %s\n", pos2.Liquidity().ToString())
}

// Output:
// [SCENARIO] 1. Initialize GNOT/GNS 0.3% pool
// [INFO] Creating GNOT/GNS 0.3% pool
//
// [SCENARIO] 2. Mint position with native token
// [INFO] Minting position with native token
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 385846133
// [EXPECTED] Amount0 (GNOT) should be 100000000
// [EXPECTED] Amount1 (GNS) should be 100000000
//
// [SCENARIO] 3. Check position state before decrease
// [EXPECTED] Position liquidity should be 385846133
// [EXPECTED] Position tickLower should be -6000
// [EXPECTED] Position tickUpper should be 6000
// [EXPECTED] Unclaimed fee0 (GNOT) should be 0
// [EXPECTED] Unclaimed fee1 (GNS) should be 0
//
// [SCENARIO] 4. Execute swap to generate fees
// [INFO] Tick before swap: 0
// [INFO] Executing swap to generate fees
// [INFO] Tick after swap: -511
// [EXPECTED] Swap amount0 should be 10000000
// [EXPECTED] Swap amount1 should be -9718871
//
// [SCENARIO] 5. Decrease liquidity without unwrapping (unwrapResult=false)
// [INFO] Balances before decrease (no unwrap):
//   UGNOT: 0
//   WUGNOT: 0
//   GNS: 99999909718871
// [INFO] Removing 100% liquidity: 385846133
// [EXPECTED] Removed liquidity should be 385846133
// [EXPECTED] Fee0 (GNOT) should be 29700
// [EXPECTED] Fee1 (GNS) should be 0
// [EXPECTED] Amount0 (GNOT) removed should be 109969999
// [EXPECTED] Amount1 (GNS) removed should be 90281128
// [INFO] Balances after decrease (no unwrap):
//   UGNOT: 0 (change: 0)
//   WUGNOT: 109999699 (change: 109999699)
//   GNS: 99999999999999 (change: 90281128)
// [EXPECTED] UGNOT balance should not change
// [EXPECTED] WUGNOT balance should increase
// [EXPECTED] GNS balance should increase
//
// [SCENARIO] 6. Decrease liquidity with unwrapping (unwrapResult=true)
// [INFO] Created new position 2 with liquidity 175432451
// [INFO] Balances before decrease (with unwrap):
//   UGNOT: 0
//   WUGNOT: 109999699
//   GNS: 99999958951927
// [EXPECTED] Removed liquidity should be 175432451
// [EXPECTED] Fee0 (GNOT) should be 0
// [EXPECTED] Fee1 (GNS) should be 0
// [EXPECTED] Amount0 (GNOT) removed should be 49999999
// [EXPECTED] Amount1 (GNS) removed should be 41048071
// [INFO] Balances after decrease (with unwrap):
//   UGNOT: 49999999 (change: 49999999)
//   WUGNOT: 109999699 (change: 0)
//   GNS: 99999999999998 (change: 41048071)
// [EXPECTED] UGNOT balance should increase (from unwrap)
// [EXPECTED] WUGNOT balance should not change
// [EXPECTED] GNS balance should increase
//
// [SCENARIO] 7. Check final balances
// [INFO] Final balances:
//   UGNOT: 49999999
//   WUGNOT: 109999699
//   GNS: 99999999999998
// [EXPECTED] Position 1 liquidity should be 0, got 0
// [EXPECTED] Position 2 liquidity should be 0, got 0
