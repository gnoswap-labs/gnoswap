// position mint swap burn

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/gnoswap/v1/position"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _  = access.GetAddress(access.ROLE_ADMIN)
	adminRealm    = std.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(access.ROLE_POOL)
	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)
	routerRealm   = std.NewUserRealm(routerAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = std.NewUserRealm(aliceAddr)

	barPath        = "gno.land/r/onbloc/bar"
	fooPath        = "gno.land/r/onbloc/foo"
	fee500  uint32 = 500
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint initial position")
	mintPosition()
	println()

	ufmt.Println("[SCENARIO] 3. Check initial state")
	checkInitialState()
	println()

	ufmt.Println("[SCENARIO] 4. Execute swaps")
	executeSwaps()
	println()

	ufmt.Println("[SCENARIO] 5. Collect fees")
	collectFees()
	println()

	ufmt.Println("[SCENARIO] 6. Burn position")
	burnPosition()
	println()

	ufmt.Println("[SCENARIO] 7. Verify final state")
	verifyFinalState()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFeeByAdmin(cross, 0)

	testing.SetRealm(adminRealm)

	defaultTokenAmount := int64(100000000)

	ufmt.Println("[INFO] Distributing Bar tokens")
	bar.Transfer(cross, aliceAddr, defaultTokenAmount)

	ufmt.Println("[INFO] Distributing Foo tokens")
	foo.Transfer(cross, aliceAddr, defaultTokenAmount)

	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Printf("[INFO] Initial Bar balance of Alice: %d\n", bar.BalanceOf(aliceAddr))
	ufmt.Printf("[INFO] Initial Foo balance of Alice: %d\n", foo.BalanceOf(aliceAddr))

	ufmt.Println("[INFO] Creating pool")
	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		fee500,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
}

func mintPosition() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Minting position")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-1000,
		1000,
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

func checkInitialState() {
	testing.SetRealm(adminRealm)
	pos, _ := position.GetPosition(1)

	ufmt.Printf("[EXPECTED] Initial liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Initial token0 balance should be %s\n", pos.Token0Balance().ToString())
	ufmt.Printf("[EXPECTED] Initial token1 balance should be %s\n", pos.Token1Balance().ToString())
}

func executeSwaps() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

	testing.SetRealm(routerRealm)
	ufmt.Println("[INFO] Executing swap BAR -> FOO")
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"10000000",
		consts.MIN_PRICE,
		adminAddr,
	)

	ufmt.Printf("[EXPECTED] Swap1 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap1 amount1 should be %s\n", amount1)

	ufmt.Println("[INFO] Executing swap FOO -> BAR")
	amount0, amount1 = pool.Swap(
		cross,
		fooPath,
		barPath,
		fee500,
		adminAddr,
		false,
		"10000000",
		consts.MAX_PRICE,
		adminAddr,
	)

	ufmt.Printf("[EXPECTED] Swap2 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap2 amount1 should be %s\n", amount1)
}

func collectFees() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Collecting fees")
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1, false)

	ufmt.Printf("[EXPECTED] Collected fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Collected fee1 should be %s\n", fee1)
}

func burnPosition() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Decreasing all liquidity")
	_, liquidity, _, _, amount0, amount1, _ := position.DecreaseLiquidity(
		cross,
		1,
		"1025258313",
		"0",
		"0",
		time.Now().Unix()+3600,
		true,
	)

	ufmt.Printf("[EXPECTED] Removed liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 removed should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 removed should be %s\n", amount1)
}

func verifyFinalState() {
	testing.SetRealm(adminRealm)
	pos, _ := position.GetPosition(1)

	ufmt.Printf("[EXPECTED] Position should be burned\n")
	ufmt.Printf("[EXPECTED] Final liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Final token0 balance should be %s\n", pos.Token0Balance().ToString())
	ufmt.Printf("[EXPECTED] Final token1 balance should be %s\n", pos.Token1Balance().ToString())
}

// Output:
// [SCENARIO] 1. Initialize pool
// [INFO] Distributing Bar tokens
// [INFO] Distributing Foo tokens
// [INFO] Initial Bar balance of Alice: 100000000
// [INFO] Initial Foo balance of Alice: 100000000
// [INFO] Creating pool
//
// [SCENARIO] 2. Mint initial position
// [INFO] Minting position
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 1025258313
// [EXPECTED] Amount0 should be 50000000
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 3. Check initial state
// [EXPECTED] Initial liquidity should be 1025258313
// [EXPECTED] Initial token0 balance should be 50000000
// [EXPECTED] Initial token1 balance should be 50000000
//
// [SCENARIO] 4. Execute swaps
// [INFO] Executing swap BAR -> FOO
// [EXPECTED] Swap1 amount0 should be 10000000
// [EXPECTED] Swap1 amount1 should be -9898501
// [INFO] Executing swap FOO -> BAR
// [EXPECTED] Swap2 amount0 should be -10091487
// [EXPECTED] Swap2 amount1 should be 10000000
//
// [SCENARIO] 5. Collect fees
// [INFO] Collecting fees
// [EXPECTED] Collected fee0 should be 4950
// [EXPECTED] Collected fee1 should be 4950
//
// [SCENARIO] 6. Burn position
// [INFO] Decreasing all liquidity
// [EXPECTED] Removed liquidity should be 1025258313
// [EXPECTED] Amount0 removed should be 49903512
// [EXPECTED] Amount1 removed should be 50096496
//
// [SCENARIO] 7. Verify final state
// [EXPECTED] Position should be burned
// [EXPECTED] Final liquidity should be 0
// [EXPECTED] Final token0 balance should be 0
// [EXPECTED] Final token1 balance should be 0
