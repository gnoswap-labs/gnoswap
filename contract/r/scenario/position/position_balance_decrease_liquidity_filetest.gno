// position decrease liquidity balance check

// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"testing"

	"gno.land/p/nt/ufmt"

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

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	INT64_MAX int64  = 9223372036854775807
	MIN_PRICE string = "4295128740"
	fee500    uint32 = 500
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint and increase position")
	mintAndIncreasePosition()
	println()

	ufmt.Println("[SCENARIO] 3. Execute swap to generate fees")
	executeSwap()
	println()

	ufmt.Println("[SCENARIO] 4. Decrease liquidity and check balances")
	testDecreaseLiquidityAndBalance()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	ufmt.Println("[INFO] Creating pool at tick 10000")
	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		fee500,
		"130621891405341611593710811006",
	)
}

func mintAndIncreasePosition() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting initial position")
	positionId, liquidity, _, _ := position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		8000,
		12000,
		"50000000",
		"50000000",
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)

	ufmt.Println("[INFO] Increasing liquidity")
	_, liquidityAdded, _, _, _ := position.IncreaseLiquidity(
		cross,
		1,
		"50000000",
		"50000000",
		"0",
		"0",
		9999999999,
	)

	ufmt.Printf("[EXPECTED] Liquidity added should be %s\n", liquidityAdded)

	pos, _ := position.GetPosition(1)
	ufmt.Printf("[EXPECTED] Total liquidity should be %s\n", pos.Liquidity().ToString())
}

func executeSwap() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	ufmt.Println("[INFO] Executing swap to generate fees")
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"20000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, true)
		},
	)

	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", amount1)
}

func testDecreaseLiquidityAndBalance() {
	testing.SetRealm(adminRealm)

	barBalanceBefore := bar.BalanceOf(adminAddr)
	fooBalanceBefore := foo.BalanceOf(adminAddr)
	pos, _ := position.GetPosition(1)
	liquidityBefore := pos.Liquidity().ToString()

	ufmt.Printf("[EXPECTED] User BAR balance before operations should be %d\n", barBalanceBefore)
	ufmt.Printf("[EXPECTED] User FOO balance before operations should be %d\n", fooBalanceBefore)
	ufmt.Printf("[EXPECTED] Position liquidity before decrease should be %s\n", liquidityBefore)

	ufmt.Println("[INFO] Collecting fees")
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1, false)
	ufmt.Printf("[EXPECTED] Collected fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Collected fee1 should be %s\n", fee1)

	barBalanceAfterFee := bar.BalanceOf(adminAddr)
	fooBalanceAfterFee := foo.BalanceOf(adminAddr)

	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Decreasing liquidity by 100000000")
	_, liquidity, _, _, amount0, amount1, _ := position.DecreaseLiquidity(
		cross,
		1,
		"100000000",
		"0",
		"0",
		9999999999,
		false,
	)

	ufmt.Printf("[EXPECTED] Removed liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 withdrawn should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 withdrawn should be %s\n", amount1)

	barBalanceAfter := bar.BalanceOf(adminAddr)
	fooBalanceAfter := foo.BalanceOf(adminAddr)
	pos, _ = position.GetPosition(1)
	liquidityAfter := pos.Liquidity().ToString()

	ufmt.Printf("[EXPECTED] User BAR balance after decrease should be %d\n", barBalanceAfter)
	ufmt.Printf("[EXPECTED] User FOO balance after decrease should be %d\n", fooBalanceAfter)
	ufmt.Printf("[EXPECTED] Position liquidity after decrease should be %s\n", liquidityAfter)

	barChange := barBalanceAfter - barBalanceAfterFee
	fooChange := fooBalanceAfter - fooBalanceAfterFee

	ufmt.Printf("[EXPECTED] BAR balance increased by %d from decrease\n", barChange)
	ufmt.Printf("[EXPECTED] FOO balance increased by %d from decrease\n", fooChange)

	ufmt.Printf("[EXPECTED] Position token0 balance should be %s\n", pos.Token0Balance().ToString())
	ufmt.Printf("[EXPECTED] Position token1 balance should be %s\n", pos.Token1Balance().ToString())

	poolInfo := pool.GetPool(barPath, fooPath, fee500)
	ufmt.Printf("[EXPECTED] Pool token0 balance should be %s\n", poolInfo.BalanceToken0().ToString())
	ufmt.Printf("[EXPECTED] Pool token1 balance should be %s\n", poolInfo.BalanceToken1().ToString())
	ufmt.Printf("[EXPECTED] Pool liquidity should be %s\n", poolInfo.Liquidity().ToString())

	// Validate token conservation and correctness
	validateDecreaseLiquidityBalances(barChange, fooChange, barBalanceAfterFee, barBalanceAfter, fooBalanceAfterFee, fooBalanceAfter)
}

func validateDecreaseLiquidityBalances(barChange, fooChange, barBefore, barAfter, fooBefore, fooAfter int64) {
	// User should gain tokens when decreasing liquidity
	if barChange <= 0 {
		panic(ufmt.Sprintf("[ERROR] BAR balance should increase (change: %d)", barChange))
	}
	if fooChange <= 0 {
		panic(ufmt.Sprintf("[ERROR] FOO balance should increase (change: %d)", fooChange))
	}

	// Verify arithmetic consistency
	if barBefore+barChange != barAfter {
		panic(ufmt.Sprintf("[ERROR] BAR balance arithmetic inconsistent: %d + %d != %d", barBefore, barChange, barAfter))
	}
	if fooBefore+fooChange != fooAfter {
		panic(ufmt.Sprintf("[ERROR] FOO balance arithmetic inconsistent: %d + %d != %d", fooBefore, fooChange, fooAfter))
	}

	ufmt.Println("[EXPECTED] Decrease liquidity balance validation passed")
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, zeroForOne bool) error {
	testing.SetRealm(adminRealm)

	const wugnotPath = "gno.land/r/gnoland/wugnot"
	const ugnotDenom = "ugnot"

	if zeroForOne {
		if token0Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount0Delta}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	} else {
		if token1Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount1Delta}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] 1. Initialize pool
// [INFO] Creating pool at tick 10000
//
// [SCENARIO] 2. Mint and increase position
// [INFO] Minting initial position
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 318704392
// [INFO] Increasing liquidity
// [EXPECTED] Liquidity added should be 318704392
// [EXPECTED] Total liquidity should be 637408784
//
// [SCENARIO] 3. Execute swap to generate fees
// [INFO] Executing swap to generate fees
// [EXPECTED] Swap amount0 should be 20000000
// [EXPECTED] Swap amount1 should be -51664436
//
// [SCENARIO] 4. Decrease liquidity and check balances
// [EXPECTED] User BAR balance before operations should be 99999943210216
// [EXPECTED] User FOO balance before operations should be 99999951664436
// [EXPECTED] Position liquidity before decrease should be 637408784
// [INFO] Collecting fees
// [EXPECTED] Collected fee0 should be 9900
// [EXPECTED] Collected fee1 should be 0
// [INFO] Decreasing liquidity by 100000000
// [EXPECTED] Removed liquidity should be 100000000
// [EXPECTED] Amount0 withdrawn should be 8907907
// [EXPECTED] Amount1 withdrawn should be 7583134
// [EXPECTED] User BAR balance after decrease should be 99999952128023
// [EXPECTED] User FOO balance after decrease should be 99999959247570
// [EXPECTED] Position liquidity after decrease should be 537408784
// [EXPECTED] BAR balance increased by 8907907 from decrease
// [EXPECTED] FOO balance increased by 7583134 from decrease
// [EXPECTED] Position token0 balance should be 47871876
// [EXPECTED] Position token1 balance should be 40752429
// [EXPECTED] Pool token0 balance should be 47871878
// [EXPECTED] Pool token1 balance should be 40752430
// [EXPECTED] Pool liquidity should be 537408784
// [EXPECTED] Decrease liquidity balance validation passed
