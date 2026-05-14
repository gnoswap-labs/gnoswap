// position same user fee distribution

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())
	routerRealm   = testing.NewUserRealm(routerAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	btcPath = "gno.land/r/gnoswap/test_token/btc"
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
	pool.SetPoolCreationFee(cross, 0)

	testing.SetRealm(adminRealm)

	defaultTokenAmount := int64(10000000000)

	ufmt.Println("[INFO] Distributing Atom tokens")
	atom.Transfer(cross, aliceAddr, defaultTokenAmount)

	ufmt.Println("[INFO] Distributing Btc tokens")
	btc.Transfer(cross, aliceAddr, defaultTokenAmount)

	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Printf("[INFO] Initial Atom balance of Alice: %d\n", atom.BalanceOf(aliceAddr))
	ufmt.Printf("[INFO] Initial Btc balance of Alice: %d\n", btc.BalanceOf(aliceAddr))

	ufmt.Println("[INFO] Creating pool")
	pool.CreatePool(
		cross,
		atomPath,
		btcPath,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
}

func mintSameRangePositions() {
	testing.SetRealm(aliceRealm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting first position in same range")
	positionId1, liquidity1, amount01, amount11 := position.Mint(
		cross,
		atomPath,
		btcPath,
		fee,
		-960,
		960,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
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
		atomPath,
		btcPath,
		fee,
		-960,
		960,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
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
	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting position in lower range")
	positionId3, liquidity3, amount03, amount13 := position.Mint(
		cross,
		atomPath,
		btcPath,
		fee,
		-1980,
		0,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
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
		atomPath,
		btcPath,
		fee,
		0,
		1980,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
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
	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	ufmt.Println("[INFO] Executing swap ATOM -> BTC")
	amount0, amount1 := pool.Swap(
		cross,
		atomPath,
		btcPath,
		fee,
		adminAddr,
		true,
		"10000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atomPath, btcPath, amount0Delta, amount1Delta, true)
		},
	)

	ufmt.Printf("[EXPECTED] Swap1 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap1 amount1 should be %s\n", amount1)

	ufmt.Println("[INFO] Executing swap BTC -> ATOM")
	amount0, amount1 = pool.Swap(
		cross,
		atomPath,
		btcPath,
		fee,
		adminAddr,
		false,
		"10000000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atomPath, btcPath, amount0Delta, amount1Delta, false)
		},
	)

	ufmt.Printf("[EXPECTED] Swap2 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap2 amount1 should be %s\n", amount1)
}

func checkSameRangeFees() {
	testing.SetRealm(aliceRealm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Collecting fees from position 1")
	_, fee01, fee11, _, _, _ := position.CollectFee(cross, 1)

	ufmt.Printf("[EXPECTED] Position 1 fee0 should be %s\n", fee01)
	ufmt.Printf("[EXPECTED] Position 1 fee1 should be %s\n", fee11)

	ufmt.Println("[INFO] Collecting fees from position 2")
	_, fee02, fee12, _, _, _ := position.CollectFee(cross, 2)

	ufmt.Printf("[EXPECTED] Position 2 fee0 should be %s\n", fee02)
	ufmt.Printf("[EXPECTED] Position 2 fee1 should be %s\n", fee12)
}

func checkDifferentRangeFees() {
	testing.SetRealm(aliceRealm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Collecting fees from position 3")
	_, fee03, fee13, _, _, _ := position.CollectFee(cross, 3)

	ufmt.Printf("[EXPECTED] Position 3 fee0 should be %s\n", fee03)
	ufmt.Printf("[EXPECTED] Position 3 fee1 should be %s\n", fee13)

	ufmt.Println("[INFO] Collecting fees from position 4")
	_, fee04, fee14, _, _, _ := position.CollectFee(cross, 4)

	ufmt.Printf("[EXPECTED] Position 4 fee0 should be %s\n", fee04)
	ufmt.Printf("[EXPECTED] Position 4 fee1 should be %s\n", fee14)
}

func verifyFinalBalances() {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Checking final balances")
	aliceAtomBalance := atom.BalanceOf(aliceAddr)
	aliceBtcBalance := btc.BalanceOf(aliceAddr)

	ufmt.Printf("[EXPECTED] Alice ATOM balance should be %d\n", aliceAtomBalance)
	ufmt.Printf("[EXPECTED] Alice BTC balance should be %d\n", aliceBtcBalance)
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, zeroForOne bool) error {
	testing.SetRealm(adminRealm)

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	}

	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] 1. Initialize pool
// [INFO] Distributing Atom tokens
// [INFO] Distributing Btc tokens
// [INFO] Initial Atom balance of Alice: 10000000000
// [INFO] Initial Btc balance of Alice: 10000000000
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
// [INFO] Executing swap ATOM -> BTC
// [EXPECTED] Swap1 amount0 should be 10000000
// [EXPECTED] Swap1 amount1 should be -9932830
// [INFO] Executing swap BTC -> ATOM
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
// [EXPECTED] Alice ATOM balance should be 9850029700
// [EXPECTED] Alice BTC balance should be 9850029700
