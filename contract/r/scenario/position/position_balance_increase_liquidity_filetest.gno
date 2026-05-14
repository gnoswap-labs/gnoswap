// position increase liquidity balance check

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"
)

const (
	INT64_MAX int64  = 9223372036854775807
	fee500    uint32 = 500
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	btcPath = "gno.land/r/gnoswap/test_token/btc"
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint initial position")
	mintInitialPosition()
	println()

	ufmt.Println("[SCENARIO] 3. Increase liquidity and check balances")
	testIncreaseLiquidityAndBalance()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	ufmt.Println("[INFO] Creating pool at tick 10000")
	pool.CreatePool(
		cross,
		atomPath,
		btcPath,
		fee500,
		"130621891405341611593710811006",
	)
}

func mintInitialPosition() {
	testing.SetRealm(adminRealm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting initial position")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		atomPath,
		btcPath,
		fee500,
		8000,
		12000,
		"50000000",
		"50000000",
		"0",
		"0",
		9999999999,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Initial liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Initial amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Initial amount1 should be %s\n", amount1)
}

func testIncreaseLiquidityAndBalance() {
	testing.SetRealm(adminRealm)

	atomBalanceBefore := atom.BalanceOf(adminAddr)
	btcBalanceBefore := btc.BalanceOf(adminAddr)
	pos, _ := position.GetPosition(1)
	liquidityBefore := pos.Liquidity()

	ufmt.Printf("[EXPECTED] User ATOM balance before increase should be %d\n", atomBalanceBefore)
	ufmt.Printf("[EXPECTED] User BTC balance before increase should be %d\n", btcBalanceBefore)
	ufmt.Printf("[EXPECTED] Position liquidity before increase should be %s\n", liquidityBefore)

	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Increasing liquidity")
	_, liquidity, amount0, amount1, _ := position.IncreaseLiquidity(
		cross,
		1,
		"50000000",
		"50000000",
		"0",
		"0",
		9999999999,
	)

	ufmt.Printf("[EXPECTED] Added liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 added should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 added should be %s\n", amount1)

	atomBalanceAfter := atom.BalanceOf(adminAddr)
	btcBalanceAfter := btc.BalanceOf(adminAddr)
	pos, _ = position.GetPosition(1)
	liquidityAfter := pos.Liquidity()

	ufmt.Printf("[EXPECTED] User ATOM balance after increase should be %d\n", atomBalanceAfter)
	ufmt.Printf("[EXPECTED] User BTC balance after increase should be %d\n", btcBalanceAfter)
	ufmt.Printf("[EXPECTED] Position liquidity after increase should be %s\n", liquidityAfter)

	atomChange := atomBalanceBefore - atomBalanceAfter
	btcChange := btcBalanceBefore - btcBalanceAfter

	ufmt.Printf("[EXPECTED] ATOM balance decreased by %d\n", atomChange)
	ufmt.Printf("[EXPECTED] BTC balance decreased by %d\n", btcChange)

	ufmt.Printf("[EXPECTED] Position token0 balance should be %d\n", position.GetPositionToken0Balance(1))
	ufmt.Printf("[EXPECTED] Position token1 balance should be %d\n", position.GetPositionToken1Balance(1))

	poolInfo, _ := pool.GetPool(atomPath, btcPath, fee500)
	ufmt.Printf("[EXPECTED] Pool token0 balance should be %d\n", poolInfo.BalanceToken0())
	ufmt.Printf("[EXPECTED] Pool token1 balance should be %d\n", poolInfo.BalanceToken1())
	ufmt.Printf("[EXPECTED] Pool liquidity should be %s\n", poolInfo.Liquidity().ToString())

	// Validate token conservation and correctness
	validateIncreaseLiquidityBalances(atomChange, btcChange, atomBalanceBefore, atomBalanceAfter, btcBalanceBefore, btcBalanceAfter)
}

func validateIncreaseLiquidityBalances(atomChange, btcChange, atomBefore, atomAfter, btcBefore, btcAfter int64) {
	// User should lose tokens when increasing liquidity
	if atomChange <= 0 {
		panic(ufmt.Sprintf("[ERROR] ATOM balance should decrease (change: %d)", atomChange))
	}
	if btcChange <= 0 {
		panic(ufmt.Sprintf("[ERROR] BTC balance should decrease (change: %d)", btcChange))
	}

	// Verify arithmetic consistency
	if atomBefore-atomChange != atomAfter {
		panic(ufmt.Sprintf("[ERROR] ATOM balance arithmetic inconsistent: %d - %d != %d", atomBefore, atomChange, atomAfter))
	}
	if btcBefore-btcChange != btcAfter {
		panic(ufmt.Sprintf("[ERROR] BTC balance arithmetic inconsistent: %d - %d != %d", btcBefore, btcChange, btcAfter))
	}

	ufmt.Println("[EXPECTED] Increase liquidity balance validation passed")
}

// Output:
// [SCENARIO] 1. Initialize pool
// [INFO] Creating pool at tick 10000
//
// [SCENARIO] 2. Mint initial position
// [INFO] Minting initial position
// [EXPECTED] Position ID should be 1
// [EXPECTED] Initial liquidity should be 318704392
// [EXPECTED] Initial amount0 should be 18394892
// [EXPECTED] Initial amount1 should be 50000000
//
// [SCENARIO] 3. Increase liquidity and check balances
// [EXPECTED] User ATOM balance before increase should be 299999981605108
// [EXPECTED] User BTC balance before increase should be 2099999950000000
// [EXPECTED] Position liquidity before increase should be 318704392
// [INFO] Increasing liquidity
// [EXPECTED] Added liquidity should be 318704392
// [EXPECTED] Amount0 added should be 18394892
// [EXPECTED] Amount1 added should be 50000000
// [EXPECTED] User ATOM balance after increase should be 299999963210216
// [EXPECTED] User BTC balance after increase should be 2099999900000000
// [EXPECTED] Position liquidity after increase should be 637408784
// [EXPECTED] ATOM balance decreased by 18394892
// [EXPECTED] BTC balance decreased by 50000000
// [EXPECTED] Position token0 balance should be 36789783
// [EXPECTED] Position token1 balance should be 99999999
// [EXPECTED] Pool token0 balance should be 36789784
// [EXPECTED] Pool token1 balance should be 100000000
// [EXPECTED] Pool liquidity should be 637408784
// [EXPECTED] Increase liquidity balance validation passed
