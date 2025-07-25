// position reposition
package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/gnoswap/v1/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = std.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())
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

	ufmt.Println("[SCENARIO] 3. Mint additional position (8000~12000)")
	mintInitialPosition()
	println()

	ufmt.Println("[SCENARIO] 4. Check initial position state")
	checkInitialPositionState()
	println()

	ufmt.Println("[SCENARIO] 5. Execute swap to change price")
	executeSwap()
	println()

	ufmt.Println("[SCENARIO] 6. Reposition to new range (9000~13000)")
	repositionToNewRange()
	println()

	ufmt.Println("[SCENARIO] 7. Check repositioned state")
	checkRepositionedState()
	println()

	ufmt.Println("[SCENARIO] 8. Execute swap in new range")
	executeSwapInNewRange()
	println()

	ufmt.Println("[SCENARIO] 9. Check final position state")
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
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

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
	bar.Approve(cross, poolAddr, INT64_MAX)

	p := pool.GetPool(barPath, fooPath, fee500)
	println("[DEBUG] Tick before swap:", p.Slot0Tick())

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
		MIN_PRICE,
		adminAddr,
	)

	println("[DEBUG] Tick after swap:", p.Slot0Tick())

	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", amount1)
}

func repositionToNewRange() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

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
	ufmt.Printf("[EXPECTED] Amount0 should be %d\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %d\n", amount1)
}

func checkRepositionedState() {
	testing.SetRealm(adminRealm)
	pos, _ := position.GetPosition(1)

	ufmt.Printf("[EXPECTED] Position liquidity should be %s\n", pos.Liquidity().ToString())
	ufmt.Printf("[EXPECTED] Position tickLower should be %d\n", pos.TickLower())
	ufmt.Printf("[EXPECTED] Position tickUpper should be %d\n", pos.TickUpper())
}

func executeSwapInNewRange() {

	p := pool.GetPool(barPath, fooPath, fee500)
	println("[DEBUG] Tick before second swap:", p.Slot0Tick())
	println("[DEBUG] Pool liquidity:", p.Liquidity().ToString())

	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, INT64_MAX)

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
		MAX_PRICE,
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
// [SCENARIO] 3. Mint additional position (8000~12000)
// [INFO] Minting initial position
// [EXPECTED] Position ID should be 2
// [EXPECTED] Liquidity should be 318704392
// [EXPECTED] Amount0 should be 18394892
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 4. Check initial position state
// [EXPECTED] Position liquidity should be 318704392
// [EXPECTED] Position tickLower should be 8000
// [EXPECTED] Position tickUpper should be 12000
//
// [SCENARIO] 5. Execute swap to change price
// [DEBUG] Tick before swap: 10000
// [INFO] Executing swap to change price
// [DEBUG] Tick after swap: 8991
// [EXPECTED] Swap amount0 should be 20000000
// [EXPECTED] Swap amount1 should be -51664436
//
// [SCENARIO] 6. Reposition to new range (9000~13000)
// [INFO] Collecting fees before reposition
// [EXPECTED] Collected fee0 should be 4950
// [EXPECTED] Collected fee1 should be 0
// [INFO] Decreasing liquidity for reposition (liquidity: 318704392)
// [INFO] Repositioning to new range
// [EXPECTED] New liquidity should be 432601712
// [EXPECTED] Amount0 should be 9000
// [EXPECTED] Amount1 should be 13000
//
// [SCENARIO] 7. Check repositioned state
// [EXPECTED] Position liquidity should be 432601712
// [EXPECTED] Position tickLower should be 9000
// [EXPECTED] Position tickUpper should be 13000
//
// [SCENARIO] 8. Execute swap in new range
// [DEBUG] Tick before second swap: 8991
// [DEBUG] Pool liquidity: 318704392
// [INFO] Executing swap in new range
// [EXPECTED] Swap amount0 should be -7994911
// [EXPECTED] Swap amount1 should be 20000000
//
// [SCENARIO] 9. Check final position state
// [EXPECTED] Final position liquidity should be 432601712
// [EXPECTED] Final position tickLower should be 9000
// [EXPECTED] Final position tickUpper should be 13000
// [EXPECTED] Final fee0 should be 0
// [EXPECTED] Final fee1 should be 5642
