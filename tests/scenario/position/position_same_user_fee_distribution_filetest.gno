// position same user fee distribution

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

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee     = uint32(3000)
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint positions with same range")
	mintSameRangePositions()
	println()

	ufmt.Println("[SCENARIO] 3. Mint positions with different ranges")
	mintDifferentRangePositions()
	println()

	ufmt.Println("[SCENARIO] 4. Execute swaps")
	executeSwaps()
	println()

	ufmt.Println("[SCENARIO] 5. Check fee distribution for same range")
	checkSameRangeFees()
	println()

	ufmt.Println("[SCENARIO] 6. Check fee distribution for different ranges")
	checkDifferentRangeFees()
	println()

	ufmt.Println("[SCENARIO] 7. Verify final balances")
	verifyFinalBalances()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFeeByAdmin(cross, 0)

	testing.SetRealm(adminRealm)

	defaultTokenAmount := int64(10000000000)

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
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
}

func mintSameRangePositions() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Minting first position in same range")
	positionId1, liquidity1, amount01, amount11 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee,
		-960,
		960,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position 1 ID should be %d\n", positionId1)
	ufmt.Printf("[EXPECTED] Position 1 liquidity should be %s\n", liquidity1)
	ufmt.Printf("[EXPECTED] Position 1 amount0 should be %s\n", amount01)
	ufmt.Printf("[EXPECTED] Position 1 amount1 should be %s\n", amount11)

	ufmt.Println("[INFO] Minting second position in same range")
	positionId2, liquidity2, amount02, amount12 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee,
		-960,
		960,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position 2 ID should be %d\n", positionId2)
	ufmt.Printf("[EXPECTED] Position 2 liquidity should be %s\n", liquidity2)
	ufmt.Printf("[EXPECTED] Position 2 amount0 should be %s\n", amount02)
	ufmt.Printf("[EXPECTED] Position 2 amount1 should be %s\n", amount12)
}

func mintDifferentRangePositions() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Minting position in lower range")
	positionId3, liquidity3, amount03, amount13 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee,
		-1980,
		0,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position 3 ID should be %d\n", positionId3)
	ufmt.Printf("[EXPECTED] Position 3 liquidity should be %s\n", liquidity3)
	ufmt.Printf("[EXPECTED] Position 3 amount0 should be %s\n", amount03)
	ufmt.Printf("[EXPECTED] Position 3 amount1 should be %s\n", amount13)

	ufmt.Println("[INFO] Minting position in upper range")
	positionId4, liquidity4, amount04, amount14 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee,
		0,
		1980,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position 4 ID should be %d\n", positionId4)
	ufmt.Printf("[EXPECTED] Position 4 liquidity should be %s\n", liquidity4)
	ufmt.Printf("[EXPECTED] Position 4 amount0 should be %s\n", amount04)
	ufmt.Printf("[EXPECTED] Position 4 amount1 should be %s\n", amount14)
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
		fee,
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
		fee,
		adminAddr,
		false,
		"10000000",
		consts.MAX_PRICE,
		adminAddr,
	)

	ufmt.Printf("[EXPECTED] Swap2 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap2 amount1 should be %s\n", amount1)
}

func checkSameRangeFees() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Collecting fees from position 1")
	_, fee01, fee11, _, _, _ := position.CollectFee(cross, 1, false)

	ufmt.Printf("[EXPECTED] Position 1 fee0 should be %s\n", fee01)
	ufmt.Printf("[EXPECTED] Position 1 fee1 should be %s\n", fee11)

	ufmt.Println("[INFO] Collecting fees from position 2")
	_, fee02, fee12, _, _, _ := position.CollectFee(cross, 2, false)

	ufmt.Printf("[EXPECTED] Position 2 fee0 should be %s\n", fee02)
	ufmt.Printf("[EXPECTED] Position 2 fee1 should be %s\n", fee12)
}

func checkDifferentRangeFees() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Collecting fees from position 3")
	_, fee03, fee13, _, _, _ := position.CollectFee(cross, 3, false)

	ufmt.Printf("[EXPECTED] Position 3 fee0 should be %s\n", fee03)
	ufmt.Printf("[EXPECTED] Position 3 fee1 should be %s\n", fee13)

	ufmt.Println("[INFO] Collecting fees from position 4")
	_, fee04, fee14, _, _, _ := position.CollectFee(cross, 4, false)

	ufmt.Printf("[EXPECTED] Position 4 fee0 should be %s\n", fee04)
	ufmt.Printf("[EXPECTED] Position 4 fee1 should be %s\n", fee14)
}

func verifyFinalBalances() {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Checking final balances")
	aliceBarBalance := bar.BalanceOf(aliceAddr)
	aliceFooBalance := foo.BalanceOf(aliceAddr)

	ufmt.Printf("[EXPECTED] Alice BAR balance should be %d\n", aliceBarBalance)
	ufmt.Printf("[EXPECTED] Alice FOO balance should be %d\n", aliceFooBalance)
}

// Output:
// [SCENARIO] 1. Initialize pool
// [INFO] Distributing Bar tokens
// [INFO] Distributing Foo tokens
// [INFO] Initial Bar balance of Alice: 10000000000
// [INFO] Initial Foo balance of Alice: 10000000000
// [INFO] Creating pool
//
// [SCENARIO] 2. Mint positions with same range
// [INFO] Minting first position in same range
// [EXPECTED] Position 1 ID should be 1
// [EXPECTED] Position 1 liquidity should be 1066918731
// [EXPECTED] Position 1 amount0 should be 50000000
// [EXPECTED] Position 1 amount1 should be 50000000
// [INFO] Minting second position in same range
// [EXPECTED] Position 2 ID should be 2
// [EXPECTED] Position 2 liquidity should be 1066918731
// [EXPECTED] Position 2 amount0 should be 50000000
// [EXPECTED] Position 2 amount1 should be 50000000
//
// [SCENARIO] 3. Mint positions with different ranges
// [INFO] Minting position in lower range
// [EXPECTED] Position 3 ID should be 3
// [EXPECTED] Position 3 liquidity should be 530488169
// [EXPECTED] Position 3 amount0 should be 0
// [EXPECTED] Position 3 amount1 should be 50000000
// [INFO] Minting position in upper range
// [EXPECTED] Position 4 ID should be 4
// [EXPECTED] Position 4 liquidity should be 530488169
// [EXPECTED] Position 4 amount0 should be 50000000
// [EXPECTED] Position 4 amount1 should be 0
//
// [SCENARIO] 4. Execute swaps
// [INFO] Executing swap BAR -> FOO
// [EXPECTED] Swap1 amount0 should be 10000000
// [EXPECTED] Swap1 amount1 should be -9932830
// [INFO] Executing swap FOO -> BAR
// [EXPECTED] Swap2 amount0 should be -10007165
// [EXPECTED] Swap2 amount1 should be 10000000
//
// [SCENARIO] 5. Check fee distribution for same range
// [INFO] Collecting fees from position 1
// [EXPECTED] Position 1 fee0 should be 11893
// [EXPECTED] Position 1 fee1 should be 11893
// [INFO] Collecting fees from position 2
// [EXPECTED] Position 2 fee0 should be 11893
// [EXPECTED] Position 2 fee1 should be 11893
//
// [SCENARIO] 6. Check fee distribution for different ranges
// [INFO] Collecting fees from position 3
// [EXPECTED] Position 3 fee0 should be 5914
// [EXPECTED] Position 3 fee1 should be 5892
// [INFO] Collecting fees from position 4
// [EXPECTED] Position 4 fee0 should be 0
// [EXPECTED] Position 4 fee1 should be 22
//
// [SCENARIO] 7. Verify final balances
// [INFO] Checking final balances
// [EXPECTED] Alice BAR balance should be 9850029700
// [EXPECTED] Alice FOO balance should be 9850029700
