// position unclaimed fee
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

	ufmt.Println("[SCENARIO] 2. Mint in-range position (8000~12000)")
	mintInRangePosition()
	println()

	ufmt.Println("[SCENARIO] 3. Mint lower range position (5000~8000)")
	mintLowerRangePosition()
	println()

	ufmt.Println("[SCENARIO] 4. Mint upper range position (12000~14000)")
	mintUpperRangePosition()
	println()

	ufmt.Println("[SCENARIO] 5. Check unclaimed fees before swap")
	checkUnclaimedFeesBeforeSwap()
	println()

	ufmt.Println("[SCENARIO] 6. Execute first swap")
	executeFirstSwap()
	println()

	ufmt.Println("[SCENARIO] 7. Check unclaimed fees after first swap")
	checkUnclaimedFeesAfterFirstSwap()
	println()

	ufmt.Println("[SCENARIO] 8. Execute second swap")
	executeSecondSwap()
	println()

	ufmt.Println("[SCENARIO] 9. Check unclaimed fees after second swap")
	checkUnclaimedFeesAfterSecondSwap()
	println()

	ufmt.Println("[SCENARIO] 10. Execute third swap")
	executeThirdSwap()
	println()

	ufmt.Println("[SCENARIO] 11. Check final unclaimed fees")
	checkFinalUnclaimedFees()
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

func mintInRangePosition() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 18394892)
	foo.Approve(cross, poolAddr, 50000000)

	ufmt.Println("[INFO] Minting position in range")
	positionId, _, amount0, amount1 := position.Mint(
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
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func mintLowerRangePosition() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 0)
	foo.Approve(cross, poolAddr, 50000000)

	ufmt.Println("[INFO] Minting position in lower range")
	positionId, _, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		5000,
		8000,
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
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func mintUpperRangePosition() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 50000000)
	foo.Approve(cross, poolAddr, 0)

	ufmt.Println("[INFO] Minting position in upper range")
	positionId, _, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		12000,
		14000,
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
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func checkUnclaimedFeesBeforeSwap() {
	testing.SetRealm(adminRealm)
	amount0, amount1 := position.UnclaimedFee(1)

	ufmt.Printf("[EXPECTED] Unclaimed fee0 should be %s\n", amount0.ToString())
	ufmt.Printf("[EXPECTED] Unclaimed fee1 should be %s\n", amount1.ToString())
}

func executeFirstSwap() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 1234567)

	testing.SetRealm(routerRealm)
	ufmt.Println("[INFO] Executing first swap")
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

func checkUnclaimedFeesAfterFirstSwap() {
	testing.SetRealm(adminRealm)
	amount0, amount1 := position.UnclaimedFee(1)

	ufmt.Printf("[EXPECTED] Unclaimed fee0 should be %s\n", amount0.ToString())
	ufmt.Printf("[EXPECTED] Unclaimed fee1 should be %s\n", amount1.ToString())
}

func executeSecondSwap() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)

	testing.SetRealm(routerRealm)
	ufmt.Println("[INFO] Executing second swap")
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

func checkUnclaimedFeesAfterSecondSwap() {
	testing.SetRealm(adminRealm)
	amount0, amount1 := position.UnclaimedFee(1)

	ufmt.Printf("[EXPECTED] Unclaimed fee0 should be %s\n", amount0.ToString())
	ufmt.Printf("[EXPECTED] Unclaimed fee1 should be %s\n", amount1.ToString())
}

func executeThirdSwap() {
	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

	testing.SetRealm(routerRealm)
	ufmt.Println("[INFO] Executing third swap")
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

func checkFinalUnclaimedFees() {
	testing.SetRealm(adminRealm)
	amount0, amount1 := position.UnclaimedFee(1)

	ufmt.Printf("[EXPECTED] Final unclaimed fee0 should be %s\n", amount0.ToString())
	ufmt.Printf("[EXPECTED] Final unclaimed fee1 should be %s\n", amount1.ToString())
}

// Output:
// [SCENARIO] 1. Initialize pool with tick 10000
// [INFO] Creating pool at tick 10000
//
// [SCENARIO] 2. Mint in-range position (8000~12000)
// [INFO] Minting position in range
// [EXPECTED] Position ID should be 1
// [EXPECTED] Amount0 should be 18394892
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 3. Mint lower range position (5000~8000)
// [INFO] Minting position in lower range
// [EXPECTED] Position ID should be 2
// [EXPECTED] Amount0 should be 0
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 4. Mint upper range position (12000~14000)
// [INFO] Minting position in upper range
// [EXPECTED] Position ID should be 3
// [EXPECTED] Amount0 should be 50000000
// [EXPECTED] Amount1 should be 0
//
// [SCENARIO] 5. Check unclaimed fees before swap
// [EXPECTED] Unclaimed fee0 should be 0
// [EXPECTED] Unclaimed fee1 should be 0
//
// [SCENARIO] 6. Execute first swap
// [INFO] Executing first swap
// [EXPECTED] Swap amount0 should be 1234567
// [EXPECTED] Swap amount1 should be -3332779
//
// [SCENARIO] 7. Check unclaimed fees after first swap
// [EXPECTED] Unclaimed fee0 should be 617
// [EXPECTED] Unclaimed fee1 should be 0
//
// [SCENARIO] 8. Execute second swap
// [INFO] Executing second swap
// [EXPECTED] Swap amount0 should be 20000000
// [EXPECTED] Swap amount1 should be -48647018
//
// [SCENARIO] 9. Check unclaimed fees after second swap
// [EXPECTED] Unclaimed fee0 should be 10170
// [EXPECTED] Unclaimed fee1 should be 0
//
// [SCENARIO] 10. Execute third swap
// [INFO] Executing third swap
// [EXPECTED] Swap amount0 should be -8692001
// [EXPECTED] Swap amount1 should be 20000000
//
// [SCENARIO] 11. Check final unclaimed fees
// [EXPECTED] Final unclaimed fee0 should be 10170
// [EXPECTED] Final unclaimed fee1 should be 9009
