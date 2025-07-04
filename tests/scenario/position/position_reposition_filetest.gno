// position reposition
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

	ufmt.Println("[SCENARIO] 4. Execute swap to change price")
	executeSwap()
	println()

	ufmt.Println("[SCENARIO] 5. Reposition to new range (9000~13000)")
	repositionToNewRange()
	println()

	ufmt.Println("[SCENARIO] 6. Check repositioned state")
	checkRepositionedState()
	println()

	ufmt.Println("[SCENARIO] 7. Execute swap in new range")
	executeSwapInNewRange()
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
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

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

	ufmt.Printf("[EXPECTED] Position liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Position tickLower should be %d\n", pos.TickLower())
	ufmt.Printf("[EXPECTED] Position tickUpper should be %d\n", pos.TickUpper())
}

func executeSwap() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)

	testing.SetRealm(routerRealm)
	ufmt.Println("[INFO] Executing swap to change price")
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

func repositionToNewRange() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Collecting fees before reposition")
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1, false)
	ufmt.Printf("[EXPECTED] Collected fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Collected fee1 should be %s\n", fee1)

	ufmt.Println("[INFO] Decreasing liquidity for reposition (liquidity: 318704392)")
	position.DecreaseLiquidity(
		cross,
		1,
		"318704392",
		"0",
		"0",
		9999999999,
		false,
	)

	ufmt.Println("[INFO] Repositioning to new range")
	_, liquidity, amount0, amount1, _, _ := position.Reposition(
		cross,
		1,
		9000,
		13000,
		"50000000",
		"50000000",
		"0",
		"0",
	)

	ufmt.Printf("[EXPECTED] New liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func checkRepositionedState() {
	testing.SetRealm(adminRealm)
	pos, _ := position.GetPosition(1)

	ufmt.Printf("[EXPECTED] Position liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Position tickLower should be %d\n", pos.TickLower())
	ufmt.Printf("[EXPECTED] Position tickUpper should be %d\n", pos.TickUpper())
}

func executeSwapInNewRange() {
	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

	testing.SetRealm(routerRealm)
	ufmt.Println("[INFO] Executing swap in new range")
	amount0, amount1 := pool.Swap(
		cross,
		fooPath,
		barPath,
		fee500,
		adminAddr,
		false,
		"20000000",
		consts.MAX_PRICE,
		adminAddr,
	)

	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", amount1)
}

func checkFinalPositionState() {
	testing.SetRealm(adminRealm)
	pos, _ := position.GetPosition(1)

	ufmt.Printf("[EXPECTED] Final position liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Final position tickLower should be %d\n", pos.TickLower())
	ufmt.Printf("[EXPECTED] Final position tickUpper should be %d\n", pos.TickUpper())

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
// [EXPECTED] Position liquidity should be 318704392
// [EXPECTED] Position tickLower should be 8000
// [EXPECTED] Position tickUpper should be 12000
//
// [SCENARIO] 4. Execute swap to change price
// [INFO] Executing swap to change price
// [EXPECTED] Swap amount0 should be 20000000
// [EXPECTED] Swap amount1 should be -49243484
//
// [SCENARIO] 5. Reposition to new range (9000~13000)
// [INFO] Collecting fees before reposition
// [EXPECTED] Collected fee0 should be 9900
// [EXPECTED] Collected fee1 should be 0
// [INFO] Decreasing liquidity for reposition (liquidity: 318704392)
// [INFO] Repositioning to new range
// [EXPECTED] New liquidity should be 432601712
// [EXPECTED] Amount0 should be %!s(int32=9000)
// [EXPECTED] Amount1 should be %!s(int32=13000)
//
// [SCENARIO] 6. Check repositioned state
// [EXPECTED] Position liquidity should be 432601712
// [EXPECTED] Position tickLower should be 9000
// [EXPECTED] Position tickUpper should be 13000
//
// [SCENARIO] 7. Execute swap in new range
// [INFO] Executing swap in new range
// [EXPECTED] Swap amount0 should be -7895067
// [EXPECTED] Swap amount1 should be 20000000
//
// [SCENARIO] 8. Check final position state
// [EXPECTED] Final position liquidity should be 432601712
// [EXPECTED] Final position tickLower should be 9000
// [EXPECTED] Final position tickUpper should be 13000
// [EXPECTED] Final fee0 should be 0
// [EXPECTED] Final fee1 should be 9900
