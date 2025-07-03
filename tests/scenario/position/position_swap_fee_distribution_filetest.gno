// position swap fee distribution
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

	ufmt.Println("[SCENARIO] 2. Mint wide range position (8000~12000)")
	mintWidePosition()
	println()

	ufmt.Println("[SCENARIO] 3. Mint tight range position (9500~10500)")
	mintTightPosition()
	println()

	ufmt.Println("[SCENARIO] 4. Check fees before swap")
	checkFeesBeforeSwap()
	println()

	ufmt.Println("[SCENARIO] 5. Execute swap")
	executeSwap()
	println()

	ufmt.Println("[SCENARIO] 6. Check fee distribution after swap")
	checkFeesAfterSwap()
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

func mintWidePosition() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 18394892)
	foo.Approve(cross, poolAddr, 50000000)

	ufmt.Println("[INFO] Minting position with wide range")
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

func mintTightPosition() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 18394892)
	foo.Approve(cross, poolAddr, 50000000)

	ufmt.Println("[INFO] Minting position with tight range")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		9500,
		10500,
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

func checkFeesBeforeSwap() {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Checking fees for position 1")
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1, false)
	ufmt.Printf("[EXPECTED] Fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Fee1 should be %s\n", fee1)

	ufmt.Println("[INFO] Checking fees for position 2")
	_, fee0, fee1, _, _, _ = position.CollectFee(cross, 2, false)
	ufmt.Printf("[EXPECTED] Fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Fee1 should be %s\n", fee1)
}

func executeSwap() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 1234567)

	testing.SetRealm(routerRealm)
	ufmt.Println("[INFO] Executing swap")
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"1234567",
		consts.MIN_PRICE,
		adminAddr,
	)

	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", amount1)
}

func checkFeesAfterSwap() {
	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Checking fees for position 1")
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1, false)
	ufmt.Printf("[EXPECTED] Fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Fee1 should be %s\n", fee1)

	ufmt.Println("[INFO] Checking fees for position 2")
	_, fee0, fee1, _, _, _ = position.CollectFee(cross, 2, false)
	ufmt.Printf("[EXPECTED] Fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Fee1 should be %s\n", fee1)
}

// Output:
// [SCENARIO] 1. Initialize pool with tick 10000
// [INFO] Creating pool at tick 10000
//
// [SCENARIO] 2. Mint wide range position (8000~12000)
// [INFO] Minting position with wide range
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 318704392
// [EXPECTED] Amount0 should be 18394892
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 3. Mint tight range position (9500~10500)
// [INFO] Minting position with tight range
// [EXPECTED] Position ID should be 2
// [EXPECTED] Liquidity should be 1228379121
// [EXPECTED] Amount0 should be 18394892
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 4. Check fees before swap
// [INFO] Checking fees for position 1
// [EXPECTED] Fee0 should be 0
// [EXPECTED] Fee1 should be 0
// [INFO] Checking fees for position 2
// [EXPECTED] Fee0 should be 0
// [EXPECTED] Fee1 should be 0
//
// [SCENARIO] 5. Execute swap
// [INFO] Executing swap
// [EXPECTED] Swap amount0 should be 1234567
// [EXPECTED] Swap amount1 should be -3349648
//
// [SCENARIO] 6. Check fee distribution after swap
// [INFO] Checking fees for position 1
// [EXPECTED] Fee0 should be 126
// [EXPECTED] Fee1 should be 0
// [INFO] Checking fees for position 2
// [EXPECTED] Fee0 should be 486
// [EXPECTED] Fee1 should be 0
