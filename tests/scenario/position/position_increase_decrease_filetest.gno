// position increase decrease test
package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
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

	barPath        = "gno.land/r/onbloc/bar"
	fooPath        = "gno.land/r/onbloc/foo"
	fee500  uint32 = 500
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool with tick 10000")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint initial position (8000~12000)")
	mintInitialPosition()
	println()

	ufmt.Println("[SCENARIO] 3. Check initial position state")
	checkInitialPositionState()
	println()

	ufmt.Println("[SCENARIO] 4. Increase position liquidity")
	increasePositionLiquidity()
	println()

	ufmt.Println("[SCENARIO] 5. Check increased position state")
	checkIncreasedPositionState()
	println()

	ufmt.Println("[SCENARIO] 6. Execute swap to generate fees")
	executeSwap()
	println()

	ufmt.Println("[SCENARIO] 7. Decrease position liquidity")
	decreasePositionLiquidity()
	println()

	ufmt.Println("[SCENARIO] 8. Check final position state")
	checkFinalPositionState()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFeeByAdmin(cross, 0)

	ufmt.Println("[INFO] Creating pool at tick 10000")
	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		fee500,
		"130621891405341611593710811006",
	)
}

func mintInitialPosition() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 18394892)
	foo.Approve(cross, poolAddr, 50000000)

	ufmt.Println("[INFO] Minting initial position")
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

func checkInitialPositionState() {
	testing.SetRealm(adminRealm)
	pos, _ := position.GetPosition(1)

	ufmt.Printf("[EXPECTED] Initial position liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Initial position tickLower should be %d\n", pos.TickLower())
	ufmt.Printf("[EXPECTED] Initial position tickUpper should be %d\n", pos.TickUpper())
	ufmt.Printf("[EXPECTED] Position token0 balance should be %s\n", pos.Token0Balance().ToString())
	ufmt.Printf("[EXPECTED] Position token1 balance should be %s\n", pos.Token1Balance().ToString())
}

func increasePositionLiquidity() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 18394892)
	foo.Approve(cross, poolAddr, 50000000)

	ufmt.Println("[INFO] Increasing position liquidity")
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
}

func checkIncreasedPositionState() {
	testing.SetRealm(adminRealm)
	pos, _ := position.GetPosition(1)

	ufmt.Printf("[EXPECTED] Increased position liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Position tickLower should be unchanged at %d\n", pos.TickLower())
	ufmt.Printf("[EXPECTED] Position tickUpper should be unchanged at %d\n", pos.TickUpper())
	ufmt.Printf("[EXPECTED] Position token0 balance should be %s\n", pos.Token0Balance().ToString())
	ufmt.Printf("[EXPECTED] Position token1 balance should be %s\n", pos.Token1Balance().ToString())
}

func executeSwap() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 20000000)

	testing.SetRealm(routerRealm)
	ufmt.Println("[INFO] Executing swap to generate fees")
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"20000000",
		consts.MIN_PRICE,
		adminAddr,
	)

	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", amount1)
}

func decreasePositionLiquidity() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, 100000000)
	foo.Approve(cross, poolAddr, 100000000)

	ufmt.Println("[INFO] Collecting fees before decrease")
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1, false)
	ufmt.Printf("[EXPECTED] Collected fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Collected fee1 should be %s\n", fee1)

	ufmt.Println("[INFO] Decreasing position liquidity")
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
	ufmt.Printf("[EXPECTED] Amount0 removed should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 removed should be %s\n", amount1)
}

func checkFinalPositionState() {
	testing.SetRealm(adminRealm)
	pos, _ := position.GetPosition(1)

	ufmt.Printf("[EXPECTED] Final position liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Position tickLower should be unchanged at %d\n", pos.TickLower())
	ufmt.Printf("[EXPECTED] Position tickUpper should be unchanged at %d\n", pos.TickUpper())

	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1, false)
	ufmt.Printf("[EXPECTED] Final fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Final fee1 should be %s\n", fee1)
}

// Output:
// [SCENARIO] 1. Initialize pool with tick 10000
// [INFO] Creating pool at tick 10000
//
// [SCENARIO] 2. Mint initial position (8000~12000)
// [INFO] Minting initial position
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 318704392
// [EXPECTED] Amount0 should be 18394892
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 3. Check initial position state
// [EXPECTED] Initial position liquidity should be 318704392
// [EXPECTED] Initial position tickLower should be 8000
// [EXPECTED] Initial position tickUpper should be 12000
// [EXPECTED] Position token0 balance should be 18394892
// [EXPECTED] Position token1 balance should be 50000000
//
// [SCENARIO] 4. Increase position liquidity
// [INFO] Increasing position liquidity
// [EXPECTED] Added liquidity should be 318704392
// [EXPECTED] Amount0 added should be 18394892
// [EXPECTED] Amount1 added should be 50000000
//
// [SCENARIO] 5. Check increased position state
// [EXPECTED] Increased position liquidity should be 637408784
// [EXPECTED] Position tickLower should be unchanged at 8000
// [EXPECTED] Position tickUpper should be unchanged at 12000
// [EXPECTED] Position token0 balance should be 36789783
// [EXPECTED] Position token1 balance should be 99999999
//
// [SCENARIO] 6. Execute swap to generate fees
// [INFO] Executing swap to generate fees
// [EXPECTED] Swap amount0 should be 20000000
// [EXPECTED] Swap amount1 should be -51664436
//
// [SCENARIO] 7. Decrease position liquidity
// [INFO] Collecting fees before decrease
// [EXPECTED] Collected fee0 should be 9900
// [EXPECTED] Collected fee1 should be 0
// [INFO] Decreasing position liquidity
// [EXPECTED] Removed liquidity should be 100000000
// [EXPECTED] Amount0 removed should be 8907907
// [EXPECTED] Amount1 removed should be 7583134
//
// [SCENARIO] 8. Check final position state
// [EXPECTED] Final position liquidity should be 537408784
// [EXPECTED] Position tickLower should be unchanged at 8000
// [EXPECTED] Position tickUpper should be unchanged at 12000
// [EXPECTED] Final fee0 should be 0
// [EXPECTED] Final fee1 should be 0
