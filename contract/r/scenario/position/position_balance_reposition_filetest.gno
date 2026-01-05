// position reposition balance check

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
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341"
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

	ufmt.Println("[SCENARIO] 2. Mint initial position")
	mintInitialPosition()
	println()

	ufmt.Println("[SCENARIO] 3. Execute swap to generate fees")
	executeSwapForFees()
	println()

	ufmt.Println("[SCENARIO] 4. Reposition (decrease full → swap → reposition)")
	testRepositionAndBalance()
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

	poolInfo := pool.GetPool(barPath, fooPath, fee500)
	ufmt.Printf("[EXPECTED] Current tick should be %d\n", poolInfo.Slot0Tick())
}

func mintInitialPosition() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting initial position (8000~12000)")
	positionId, liquidity, amount0, amount1 := position.Mint(
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
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func executeSwapForFees() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)

	poolInfo := pool.GetPool(barPath, fooPath, fee500)
	tickBefore := poolInfo.Slot0Tick()

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

	testing.SetRealm(adminRealm)
	poolInfo = pool.GetPool(barPath, fooPath, fee500)
	tickAfter := poolInfo.Slot0Tick()

	ufmt.Printf("[EXPECTED] Tick before swap should be %d\n", tickBefore)
	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", amount1)
	ufmt.Printf("[EXPECTED] Tick after swap should be %d\n", tickAfter)
}

func testRepositionAndBalance() {
	testing.SetRealm(adminRealm)

	pos, _ := position.GetPosition(1)
	currentLiquidity := pos.Liquidity().ToString()
	currentTickLower := pos.TickLower()
	currentTickUpper := pos.TickUpper()

	ufmt.Printf("[EXPECTED] Current position liquidity should be %s\n", currentLiquidity)
	ufmt.Printf("[EXPECTED] Current tick range should be [%d, %d]\n", currentTickLower, currentTickUpper)

	barBalanceStart := bar.BalanceOf(adminAddr)
	fooBalanceStart := foo.BalanceOf(adminAddr)

	ufmt.Printf("[EXPECTED] User BAR balance before reposition should be %d\n", barBalanceStart)
	ufmt.Printf("[EXPECTED] User FOO balance before reposition should be %d\n", fooBalanceStart)

	ufmt.Println("[INFO] Collecting fees")
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1, false)
	ufmt.Printf("[EXPECTED] Collected fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Collected fee1 should be %s\n", fee1)

	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Decreasing full liquidity")
	_, _, _, _, decreaseAmount0, decreaseAmount1, _ := position.DecreaseLiquidity(
		cross,
		1,
		currentLiquidity,
		"0",
		"0",
		9999999999,
		false,
	)

	ufmt.Printf("[EXPECTED] Amount0 withdrawn should be %s\n", decreaseAmount0)
	ufmt.Printf("[EXPECTED] Amount1 withdrawn should be %s\n", decreaseAmount1)

	pos, _ = position.GetPosition(1)
	ufmt.Printf("[EXPECTED] Position liquidity after decrease should be %s\n", pos.Liquidity().ToString())

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Executing swap to adjust balance")
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		false,
		"10000000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, false)
		},
	)

	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", swapAmount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", swapAmount1)

	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Repositioning to new range (9000~13000)")
	_, newLiquidity, _, _, _, _ := position.Reposition(
		cross,
		1,
		9000,
		13000,
		"50000000",
		"50000000",
		"0",
		"0",
		9999999999,
	)

	ufmt.Printf("[EXPECTED] New liquidity should be %s\n", newLiquidity)
	ufmt.Printf("[EXPECTED] New tick range should be [%d, %d]\n", 9000, 13000)

	barBalanceFinal := bar.BalanceOf(adminAddr)
	fooBalanceFinal := foo.BalanceOf(adminAddr)

	ufmt.Printf("[EXPECTED] User BAR balance after reposition should be %d\n", barBalanceFinal)
	ufmt.Printf("[EXPECTED] User FOO balance after reposition should be %d\n", fooBalanceFinal)

	pos, _ = position.GetPosition(1)
	ufmt.Printf("[EXPECTED] Final position liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Final position tick range should be [%d, %d]\n", pos.TickLower(), pos.TickUpper())
	ufmt.Printf("[EXPECTED] Final position token0 balance should be %s\n", pos.Token0Balance().ToString())
	ufmt.Printf("[EXPECTED] Final position token1 balance should be %s\n", pos.Token1Balance().ToString())

	poolInfo := pool.GetPool(barPath, fooPath, fee500)
	ufmt.Printf("[EXPECTED] Final pool token0 balance should be %s\n", poolInfo.BalanceToken0().ToString())
	ufmt.Printf("[EXPECTED] Final pool token1 balance should be %s\n", poolInfo.BalanceToken1().ToString())
	ufmt.Printf("[EXPECTED] Final pool liquidity should be %s\n", poolInfo.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Final pool tick should be %d\n", poolInfo.Slot0Tick())
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
// [EXPECTED] Current tick should be 10000
//
// [SCENARIO] 2. Mint initial position
// [INFO] Minting initial position (8000~12000)
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 318704392
// [EXPECTED] Amount0 should be 18394892
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 3. Execute swap to generate fees
// [INFO] Executing swap to generate fees
// [EXPECTED] Tick before swap should be 10000
// [EXPECTED] Swap amount0 should be 20000000
// [EXPECTED] Swap amount1 should be -49243484
// [EXPECTED] Tick after swap should be 8031
//
// [SCENARIO] 4. Reposition (decrease full → swap → reposition)
// [EXPECTED] Current position liquidity should be 318704392
// [EXPECTED] Current tick range should be [8000, 12000]
// [EXPECTED] User BAR balance before reposition should be 99999961605108
// [EXPECTED] User FOO balance before reposition should be 99999999243484
// [INFO] Collecting fees
// [EXPECTED] Collected fee0 should be 9900
// [EXPECTED] Collected fee1 should be 0
// [INFO] Decreasing full liquidity
// [EXPECTED] Amount0 withdrawn should be 38384891
// [EXPECTED] Amount1 withdrawn should be 756515
// [EXPECTED] Position liquidity after decrease should be 0
// [INFO] Executing swap to adjust balance
// [EXPECTED] Swap amount0 should be 0
// [EXPECTED] Swap amount1 should be 0
// [INFO] Repositioning to new range (9000~13000)
// [EXPECTED] New liquidity should be 432601712
// [EXPECTED] New tick range should be [9000, 13000]
// [EXPECTED] User BAR balance after reposition should be 99999949999899
// [EXPECTED] User FOO balance after reposition should be 99999999999999
// [EXPECTED] Final position liquidity should be 432601712
// [EXPECTED] Final position tick range should be [9000, 13000]
// [EXPECTED] Final position token0 balance should be 0
// [EXPECTED] Final position token1 balance should be 0
// [EXPECTED] Final pool token0 balance should be 50000002
// [EXPECTED] Final pool token1 balance should be 1
// [EXPECTED] Final pool liquidity should be 0
// [EXPECTED] Final pool tick should be 8031
