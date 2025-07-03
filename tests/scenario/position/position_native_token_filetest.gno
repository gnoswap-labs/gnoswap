// position handle native token

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"

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
	adminAddr, _    = access.GetAddress(access.ROLE_ADMIN)
	adminRealm      = std.NewUserRealm(adminAddr)
	poolAddr, _     = access.GetAddress(access.ROLE_POOL)
	routerAddr, _   = access.GetAddress(access.ROLE_ROUTER)
	routerRealm     = std.NewUserRealm(routerAddr)
	positionAddr, _ = access.GetAddress(access.ROLE_POSITION)
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool with GNOT/GNS pair")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint position with native token")
	mintPosition()
	println()

	ufmt.Println("[SCENARIO] 3. Check unclaimed fees before swap")
	checkUnclaimedFeesBeforeSwap()
	println()

	ufmt.Println("[SCENARIO] 4. Execute swap with native token")
	executeSwap()
	println()

	ufmt.Println("[SCENARIO] 5. Check unclaimed fees after swap")
	checkUnclaimedFeesAfterSwap()
	println()

	ufmt.Println("[SCENARIO] 6. Decrease liquidity without unwrapping")
	decreaseLiquidityNoUnwrap()
	println()

	ufmt.Println("[SCENARIO] 7. Decrease liquidity with unwrapping")
	decreaseLiquidityWithUnwrap()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFeeByAdmin(cross, 0)

	ufmt.Println("[INFO] Creating GNOT/GNS pool")
	pool.CreatePool(
		cross,
		consts.GNOT,
		consts.GNS_PATH,
		500,
		common.TickMathGetSqrtRatioAtTick(1).ToString(),
	)
}

func mintPosition() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, consts.INT64_MAX)
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	wugnot.Approve(cross, positionAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Issue initial GNOT")
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 50000005}})
	testing.IssueCoins(positionAddr, std.Coins{{"ugnot", 200000000}})

	ufmt.Println("[INFO] Send GNOT to position contract")
	banker := std.NewBanker(std.BankerTypeRealmIssue)
	banker.SendCoins(adminAddr, positionAddr, std.Coins{{"ugnot", 50000005}})
	testing.SetOriginSend(std.Coins{{"ugnot", 50000005}})

	ufmt.Println("[INFO] Minting position")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		consts.GNOT,
		consts.GNS_PATH,
		500,
		-8000,
		8000,
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

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
}

func checkUnclaimedFeesBeforeSwap() {
	testing.SetRealm(adminRealm)
	amount0, amount1 := position.UnclaimedFee(1)

	ufmt.Printf("[EXPECTED] Unclaimed fee0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Unclaimed fee1 should be %s\n", amount1)
}

func executeSwap() {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Wrapping GNOT for swap")
	testing.SetOriginSend(std.Coins{{"ugnot", 1234567}})
	wugnot.Deposit(cross)

	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	wugnot.Approve(cross, positionAddr, consts.INT64_MAX)
	wugnot.Approve(cross, routerAddr, consts.INT64_MAX)

	testing.SetRealm(routerRealm)
	ufmt.Println("[INFO] Executing swap")
	amount0, amount1 := pool.Swap(
		cross,
		consts.WUGNOT_PATH,
		consts.GNS_PATH,
		500,
		adminAddr,
		true,
		"1234567",
		consts.MIN_PRICE,
		adminAddr,
	)

	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", amount1)
}

func checkUnclaimedFeesAfterSwap() {
	testing.SetRealm(adminRealm)
	amount0, amount1 := position.UnclaimedFee(1)

	ufmt.Printf("[EXPECTED] Unclaimed fee0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Unclaimed fee1 should be %s\n", amount1)
}

func decreaseLiquidityNoUnwrap() {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Decreasing liquidity without unwrapping")
	_, liquidity, _, _, amount0, amount1, _ := position.DecreaseLiquidity(
		cross,
		1,
		"15164540",
		"0",
		"0",
		9999999999,
		false,
	)

	ufmt.Printf("[EXPECTED] Removed liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 removed should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 removed should be %s\n", amount1)
	ufmt.Printf("[EXPECTED] WUGNOT balance should increase\n")
	ufmt.Printf("[EXPECTED] GNOT balance should remain same\n")
}

func decreaseLiquidityWithUnwrap() {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Decreasing liquidity with unwrapping")
	_, liquidity, _, _, amount0, amount1, _ := position.DecreaseLiquidity(
		cross,
		1,
		"15164540",
		"0",
		"0",
		9999999999,
		true,
	)

	ufmt.Printf("[EXPECTED] Removed liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 removed should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 removed should be %s\n", amount1)
	ufmt.Printf("[EXPECTED] WUGNOT balance should decrease\n")
	ufmt.Printf("[EXPECTED] GNOT balance should increase\n")
}

// Output:
// [SCENARIO] 1. Initialize pool with GNOT/GNS pair
// [INFO] Creating GNOT/GNS pool
//
// [SCENARIO] 2. Mint position with native token
// [INFO] Issue initial GNOT
// [INFO] Send GNOT to position contract
// [INFO] Minting position
// [EXPECTED] Position ID should be 1
// [EXPECTED] Amount0 should be 49984837
// [EXPECTED] Amount1 should be 50000000
// [EXPECTED] Liquidity should be 151645407
//
// [SCENARIO] 3. Check unclaimed fees before swap
// [EXPECTED] Unclaimed fee0 should be %!s((unhandled))
// [EXPECTED] Unclaimed fee1 should be %!s((unhandled))
//
// [SCENARIO] 4. Execute swap with native token
// [INFO] Wrapping GNOT for swap
// [INFO] Executing swap
// [EXPECTED] Swap amount0 should be 1234567
// [EXPECTED] Swap amount1 should be -1224110
//
// [SCENARIO] 5. Check unclaimed fees after swap
// [EXPECTED] Unclaimed fee0 should be %!s((unhandled))
// [EXPECTED] Unclaimed fee1 should be %!s((unhandled))
//
// [SCENARIO] 6. Decrease liquidity without unwrapping
// [INFO] Decreasing liquidity without unwrapping
// [EXPECTED] Removed liquidity should be 15164540
// [EXPECTED] Amount0 removed should be 5121878
// [EXPECTED] Amount1 removed should be 4877588
// [EXPECTED] WUGNOT balance should increase
// [EXPECTED] GNOT balance should remain same
//
// [SCENARIO] 7. Decrease liquidity with unwrapping
// [INFO] Decreasing liquidity with unwrapping
// [EXPECTED] Removed liquidity should be 15164540
// [EXPECTED] Amount0 removed should be 5121878
// [EXPECTED] Amount1 removed should be 4877588
// [EXPECTED] WUGNOT balance should decrease
// [EXPECTED] GNOT balance should increase
