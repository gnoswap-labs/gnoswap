// position decrease liquidity with multiple positions (simulating position 24, 25)

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
	
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1

	GNOT        string = "gnot"
	GNS_PATH    string = "gno.land/r/gnoswap/gns"
	WUGNOT_PATH string = "gno.land/r/demo/wugnot"
	BAR_PATH    string = "gno.land/r/onbloc/bar"
	FOO_PATH    string = "gno.land/r/onbloc/foo"
)

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = std.NewUserRealm(adminAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())
	routerRealm     = std.NewUserRealm(routerAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())

	fee500  uint32 = 500
	fee3000 uint32 = 3000
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize multiple pools")
	initPools()
	println()

	ufmt.Println("[SCENARIO] 2. Create multiple positions to reach position ID 24, 25")
	createMultiplePositions()
	println()

	ufmt.Println("[SCENARIO] 3. Create target positions 24 and 25 with GNOT/GNS pool")
	createTargetPositions()
	println()

	ufmt.Println("[SCENARIO] 4. Execute swap to generate fees")
	executeSwap()
	println()

	ufmt.Println("[SCENARIO] 5. Test DecreaseLiquidity on position 24 (unwrapResult=false)")
	testPosition24()
	println()

	ufmt.Println("[SCENARIO] 6. Test DecreaseLiquidity on position 25 (unwrapResult=true)")
	testPosition25()
	println()

	ufmt.Println("[SCENARIO] 7. Verify final states")
	verifyFinalStates()
	println()
}

func initPools() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	// Create multiple pools
	ufmt.Println("[INFO] Creating BAR/FOO pool")
	pool.CreatePool(cross, BAR_PATH, FOO_PATH, fee500, "79228162514264337593543950336")
	
	ufmt.Println("[INFO] Creating GNOT/GNS 0.3% pool")
	pool.CreatePool(cross, GNOT, GNS_PATH, fee3000, "79228162514264337593543950336")
	
	ufmt.Println("[INFO] Creating FOO/GNS pool")
	pool.CreatePool(cross, FOO_PATH, GNS_PATH, fee500, "79228162514264337593543950336")
}

func createMultiplePositions() {
	testing.SetRealm(adminRealm)
	
	// Approve tokens for various pools
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)
	gns.Approve(cross, poolAddr, INT64_MAX)
	wugnot.Approve(cross, poolAddr, INT64_MAX)
	wugnot.Approve(cross, positionAddr, INT64_MAX)

	// Create positions in BAR/FOO pool (positions 1-10)
	for i := 1; i <= 10; i++ {
		positionId, _, _, _ := position.Mint(
			cross,
			BAR_PATH,
			FOO_PATH,
			fee500,
			-1000,
			1000,
			"1000000",
			"1000000",
			"0",
			"0",
			9999999999,
			adminAddr,
			adminAddr,
			"",
		)
		ufmt.Printf("[INFO] Created position %d in BAR/FOO pool\n", positionId)
	}

	// Create positions in FOO/GNS pool (positions 11-23)
	for i := 11; i <= 23; i++ {
		positionId, _, _, _ := position.Mint(
			cross,
			FOO_PATH,
			GNS_PATH,
			fee500,
			-2000,
			2000,
			"1000000",
			"1000000",
			"0",
			"0",
			9999999999,
			adminAddr,
			adminAddr,
			"",
		)
		ufmt.Printf("[INFO] Created position %d in FOO/GNS pool\n", positionId)
	}
}

func createTargetPositions() {
	testing.SetRealm(adminRealm)
	
	// Issue GNOT to position contract
	testing.IssueCoins(positionAddr, std.Coins{{"ugnot", 1000000000}})

	// Create position 24 with GNOT/GNS
	testing.SetOriginSend(std.Coins{{"ugnot", 200000000}})
	positionId24, liquidity24, amount0_24, amount1_24 := position.Mint(
		cross,
		GNOT,
		GNS_PATH,
		fee3000,
		-6000,
		6000,
		"200000000", // 200 GNOT
		"200000000", // 200 GNS
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)
	testing.SetOriginSend(std.Coins{{"ugnot", 0}})
	
	ufmt.Printf("[EXPECTED] Position 24 created:\n")
	ufmt.Printf("  ID: %d\n", positionId24)
	ufmt.Printf("  Liquidity: %s\n", liquidity24)
	ufmt.Printf("  Amount0 (GNOT): %s\n", amount0_24)
	ufmt.Printf("  Amount1 (GNS): %s\n", amount1_24)

	// Create position 25 with GNOT/GNS
	testing.SetOriginSend(std.Coins{{"ugnot", 150000000}})
	positionId25, liquidity25, amount0_25, amount1_25 := position.Mint(
		cross,
		GNOT,
		GNS_PATH,
		fee3000,
		-6000,
		6000,
		"150000000", // 150 GNOT
		"150000000", // 150 GNS
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)
	testing.SetOriginSend(std.Coins{{"ugnot", 0}})
	
	ufmt.Printf("[EXPECTED] Position 25 created:\n")
	ufmt.Printf("  ID: %d\n", positionId25)
	ufmt.Printf("  Liquidity: %s\n", liquidity25)
	ufmt.Printf("  Amount0 (GNOT): %s\n", amount0_25)
	ufmt.Printf("  Amount1 (GNS): %s\n", amount1_25)
}

func executeSwap() {
	testing.SetRealm(adminRealm)

	// Wrap GNOT for swap
	testing.SetOriginSend(std.Coins{{"ugnot", 20000000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(std.Coins{{"ugnot", 0}})

	wugnot.Approve(cross, poolAddr, INT64_MAX)
	wugnot.Approve(cross, routerAddr, INT64_MAX)

	// Execute swap in GNOT/GNS pool
	func() {
		ctx := testing.GetContext()
		ctx.CurrentRealm = routerRealm
		ctx.OriginCaller = adminAddr
		testing.SetContext(ctx)
	}()

	ufmt.Println("[INFO] Executing swap in GNOT/GNS pool")
	amount0, amount1 := pool.Swap(
		cross,
		WUGNOT_PATH,
		GNS_PATH,
		fee3000,
		adminAddr,
		true,
		"20000000",
		MIN_PRICE,
		adminAddr,
	)

	ufmt.Printf("[EXPECTED] Swap amount0: %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1: %s\n", amount1)
}

func testPosition24() {
	testing.SetRealm(adminRealm)
	
	// Get position 24 info
	pos24, _ := position.GetPosition(24)
	ufmt.Printf("[INFO] Position 24 before decrease:\n")
	ufmt.Printf("  Liquidity: %s\n", pos24.Liquidity().ToString())
	ufmt.Printf("  TickLower: %d\n", pos24.TickLower())
	ufmt.Printf("  TickUpper: %d\n", pos24.TickUpper())

	// Check balances before
	banker := std.NewBanker(std.BankerTypeRealmSend)
	ugnotBefore := banker.GetCoins(adminAddr).AmountOf("ugnot")
	wugnotBefore := wugnot.BalanceOf(adminAddr)
	gnsBefore := gns.BalanceOf(adminAddr)

	// Decrease liquidity without unwrap
	liquidityToRemove := pos24.Liquidity().ToString()
	_, liquidity, fee0, fee1, amount0, amount1, _ := position.DecreaseLiquidity(
		cross,
		24,
		liquidityToRemove,
		"0",
		"0",
		9999999999,
		false, // Don't unwrap
	)

	ufmt.Printf("[EXPECTED] Position 24 decrease results:\n")
	ufmt.Printf("  Removed liquidity: %s\n", liquidity)
	ufmt.Printf("  Fee0: %s\n", fee0)
	ufmt.Printf("  Fee1: %s\n", fee1)
	ufmt.Printf("  Amount0: %s\n", amount0)
	ufmt.Printf("  Amount1: %s\n", amount1)

	// Check balances after
	ugnotAfter := banker.GetCoins(adminAddr).AmountOf("ugnot")
	wugnotAfter := wugnot.BalanceOf(adminAddr)
	gnsAfter := gns.BalanceOf(adminAddr)

	ufmt.Printf("[INFO] Balance changes (position 24, unwrapResult=false):\n")
	ufmt.Printf("  UGNOT: %d -> %d (change: %d)\n", ugnotBefore, ugnotAfter, ugnotAfter-ugnotBefore)
	ufmt.Printf("  WUGNOT: %d -> %d (change: %d)\n", wugnotBefore, wugnotAfter, wugnotAfter-wugnotBefore)
	ufmt.Printf("  GNS: %d -> %d (change: %d)\n", gnsBefore, gnsAfter, gnsAfter-gnsBefore)

	ufmt.Printf("[EXPECTED] UGNOT should not change when unwrapResult=false\n")
	ufmt.Printf("[EXPECTED] WUGNOT should increase when unwrapResult=false\n")
}

func testPosition25() {
	testing.SetRealm(adminRealm)
	
	// Get position 25 info
	pos25, _ := position.GetPosition(25)
	ufmt.Printf("[INFO] Position 25 before decrease:\n")
	ufmt.Printf("  Liquidity: %s\n", pos25.Liquidity().ToString())
	ufmt.Printf("  TickLower: %d\n", pos25.TickLower())
	ufmt.Printf("  TickUpper: %d\n", pos25.TickUpper())

	// Check balances before
	banker := std.NewBanker(std.BankerTypeRealmSend)
	ugnotBefore := banker.GetCoins(adminAddr).AmountOf("ugnot")
	wugnotBefore := wugnot.BalanceOf(adminAddr)
	gnsBefore := gns.BalanceOf(adminAddr)

	// Decrease liquidity with unwrap
	liquidityToRemove := pos25.Liquidity().ToString()
	_, liquidity, fee0, fee1, amount0, amount1, _ := position.DecreaseLiquidity(
		cross,
		25,
		liquidityToRemove,
		"0",
		"0",
		9999999999,
		true, // Unwrap to GNOT
	)

	ufmt.Printf("[EXPECTED] Position 25 decrease results:\n")
	ufmt.Printf("  Removed liquidity: %s\n", liquidity)
	ufmt.Printf("  Fee0: %s\n", fee0)
	ufmt.Printf("  Fee1: %s\n", fee1)
	ufmt.Printf("  Amount0: %s\n", amount0)
	ufmt.Printf("  Amount1: %s\n", amount1)

	// Check balances after
	ugnotAfter := banker.GetCoins(adminAddr).AmountOf("ugnot")
	wugnotAfter := wugnot.BalanceOf(adminAddr)
	gnsAfter := gns.BalanceOf(adminAddr)

	ufmt.Printf("[INFO] Balance changes (position 25, unwrapResult=true):\n")
	ufmt.Printf("  UGNOT: %d -> %d (change: %d)\n", ugnotBefore, ugnotAfter, ugnotAfter-ugnotBefore)
	ufmt.Printf("  WUGNOT: %d -> %d (change: %d)\n", wugnotBefore, wugnotAfter, wugnotAfter-wugnotBefore)
	ufmt.Printf("  GNS: %d -> %d (change: %d)\n", gnsBefore, gnsAfter, gnsAfter-gnsBefore)

	ufmt.Printf("[EXPECTED] UGNOT should increase when unwrapResult=true\n")
	ufmt.Printf("[EXPECTED] WUGNOT should not change when unwrapResult=true\n")
}

func verifyFinalStates() {
	testing.SetRealm(adminRealm)
	
	// Check positions 24 and 25
	pos24, _ := position.GetPosition(24)
	pos25, _ := position.GetPosition(25)
	
	ufmt.Printf("[INFO] Final position states:\n")
	ufmt.Printf("  Position 24 liquidity: %s (should be 0)\n", pos24.Liquidity().ToString())
	ufmt.Printf("  Position 25 liquidity: %s (should be 0)\n", pos25.Liquidity().ToString())
	
	// Final balances
	banker := std.NewBanker(std.BankerTypeRealmSend)
	ugnotFinal := banker.GetCoins(adminAddr).AmountOf("ugnot")
	wugnotFinal := wugnot.BalanceOf(adminAddr)
	gnsFinal := gns.BalanceOf(adminAddr)
	
	ufmt.Printf("[INFO] Final balances:\n")
	ufmt.Printf("  UGNOT: %d\n", ugnotFinal)
	ufmt.Printf("  WUGNOT: %d\n", wugnotFinal)
	ufmt.Printf("  GNS: %d\n", gnsFinal)
}

// Output:
// [SCENARIO] 1. Initialize multiple pools
// [INFO] Creating BAR/FOO pool
// [INFO] Creating GNOT/GNS 0.3% pool
// [INFO] Creating FOO/GNS pool
//
// [SCENARIO] 2. Create multiple positions to reach position ID 24, 25
// [INFO] Created position 1 in BAR/FOO pool
// [INFO] Created position 2 in BAR/FOO pool
// [INFO] Created position 3 in BAR/FOO pool
// [INFO] Created position 4 in BAR/FOO pool
// [INFO] Created position 5 in BAR/FOO pool
// [INFO] Created position 6 in BAR/FOO pool
// [INFO] Created position 7 in BAR/FOO pool
// [INFO] Created position 8 in BAR/FOO pool
// [INFO] Created position 9 in BAR/FOO pool
// [INFO] Created position 10 in BAR/FOO pool
// [INFO] Created position 11 in FOO/GNS pool
// [INFO] Created position 12 in FOO/GNS pool
// [INFO] Created position 13 in FOO/GNS pool
// [INFO] Created position 14 in FOO/GNS pool
// [INFO] Created position 15 in FOO/GNS pool
// [INFO] Created position 16 in FOO/GNS pool
// [INFO] Created position 17 in FOO/GNS pool
// [INFO] Created position 18 in FOO/GNS pool
// [INFO] Created position 19 in FOO/GNS pool
// [INFO] Created position 20 in FOO/GNS pool
// [INFO] Created position 21 in FOO/GNS pool
// [INFO] Created position 22 in FOO/GNS pool
// [INFO] Created position 23 in FOO/GNS pool
//
// [SCENARIO] 3. Create target positions 24 and 25 with GNOT/GNS pool
// [EXPECTED] Position 24 created:
//   ID: 24
//   Liquidity: 771692266
//   Amount0 (GNOT): 200000000
//   Amount1 (GNS): 200000000
// [EXPECTED] Position 25 created:
//   ID: 25
//   Liquidity: 578769199
//   Amount0 (GNOT): 150000000
//   Amount1 (GNS): 150000000
//
// [SCENARIO] 4. Execute swap to generate fees
// [INFO] Executing swap in GNOT/GNS pool
// [EXPECTED] Swap amount0: 20000000
// [EXPECTED] Swap amount1: -19649863
//
// [SCENARIO] 5. Test DecreaseLiquidity on position 24 (unwrapResult=false)
// [INFO] Position 24 before decrease:
//   Liquidity: 771692266
//   TickLower: -6000
//   TickUpper: 6000
// [EXPECTED] Position 24 decrease results:
//   Removed liquidity: 771692266
//   Fee0: 33943
//   Fee1: 0
//   Amount0: 211394285
//   Amount1: 188771506
// [INFO] Balance changes (position 24, unwrapResult=false):
//   UGNOT: 0 -> 0 (change: 0)
//   WUGNOT: 0 -> 211428228 (change: 211428228)
//   GNS: 99999656649863 -> 99999845421369 (change: 188771506)
// [EXPECTED] UGNOT should not change when unwrapResult=false
// [EXPECTED] WUGNOT should increase when unwrapResult=false
//
// [SCENARIO] 6. Test DecreaseLiquidity on position 25 (unwrapResult=true)
// [INFO] Position 25 before decrease:
//   Liquidity: 578769199
//   TickLower: -6000
//   TickUpper: 6000
// [EXPECTED] Position 25 decrease results:
//   Removed liquidity: 578769199
//   Fee0: 25457
//   Fee1: 0
//   Amount0: 158545714
//   Amount1: 141578629
// [INFO] Balance changes (position 25, unwrapResult=true):
//   UGNOT: 0 -> 158571171 (change: 158571171)
//   WUGNOT: 211428228 -> 211428228 (change: 0)
//   GNS: 99999845421369 -> 99999986999998 (change: 141578629)
// [EXPECTED] UGNOT should increase when unwrapResult=true
// [EXPECTED] WUGNOT should not change when unwrapResult=true
//
// [SCENARIO] 7. Verify final states
// [INFO] Final position states:
//   Position 24 liquidity: 0 (should be 0)
//   Position 25 liquidity: 0 (should be 0)
// [INFO] Final balances:
//   UGNOT: 158571171
//   WUGNOT: 211428228
//   GNS: 99999986999998
