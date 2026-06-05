// position unclaimed fee

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"
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

	barPath        = "gno.land/r/onbloc/bar"
	fooPath        = "gno.land/r/onbloc/foo"
	fee500  uint32 = 500
)

func main(cur realm) {
	ufmt.Println("[SCENARIO] 1. Initialize pool with tick 10000")
	initPool(cur)
	println()

	ufmt.Println("[SCENARIO] 2. Mint in-range position (8000~12000)")
	mintInRangePosition(cur)
	println()

	ufmt.Println("[SCENARIO] 3. Mint lower range position (5000~8000)")
	mintLowerRangePosition(cur)
	println()

	ufmt.Println("[SCENARIO] 4. Mint upper range position (12000~14000)")
	mintUpperRangePosition(cur)
	println()

	ufmt.Println("[SCENARIO] 5. Check unclaimed fees before swap")
	checkUnclaimedFeesBeforeSwap(cur)
	println()

	ufmt.Println("[SCENARIO] 6. Execute first swap")
	executeFirstSwap(cur)
	println()

	ufmt.Println("[SCENARIO] 7. Check unclaimed fees after first swap")
	checkUnclaimedFeesAfterFirstSwap(cur)
	println()

	ufmt.Println("[SCENARIO] 8. Execute second swap")
	executeSecondSwap(cur)
	println()

	ufmt.Println("[SCENARIO] 9. Check unclaimed fees after second swap")
	checkUnclaimedFeesAfterSecondSwap(cur)
	println()

	ufmt.Println("[SCENARIO] 10. Execute third swap")
	executeThirdSwap(cur)
	println()

	ufmt.Println("[SCENARIO] 11. Check final unclaimed fees")
	checkFinalUnclaimedFees(cur)
	println()
}

func initPool(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)

	ufmt.Println("[INFO] Creating pool at tick 10000")
	pool.CreatePool(
		cross(cur),
		barPath,
		fooPath,
		fee500,
		"130621891405341611593710811006",
	)
}

func mintInRangePosition(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, 18394892)
	foo.Approve(cross(cur), poolAddr, 50000000)

	ufmt.Println("[INFO] Minting position in range")
	positionId, _, amount0, amount1 := position.Mint(
		cross(cur),
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
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func mintLowerRangePosition(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, 0)
	foo.Approve(cross(cur), poolAddr, 50000000)

	ufmt.Println("[INFO] Minting position in lower range")
	positionId, _, amount0, amount1 := position.Mint(
		cross(cur),
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
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func mintUpperRangePosition(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, 50000000)
	foo.Approve(cross(cur), poolAddr, 0)

	ufmt.Println("[INFO] Minting position in upper range")
	positionId, _, amount0, amount1 := position.Mint(
		cross(cur),
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
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func checkUnclaimedFeesBeforeSwap(cur realm) {
	testing.SetRealm(adminRealm)
	amount0, amount1 := position.GetUnclaimedFee(1)

	ufmt.Printf("[EXPECTED] Unclaimed fee0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Unclaimed fee1 should be %s\n", amount1)
}

func executeFirstSwap(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, 1234567)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	ufmt.Println("[INFO] Executing first swap")
	amount0, amount1 := pool.Swap(
		cross(cur),
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"1234567",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(cur, barPath, fooPath, amount0Delta, amount1Delta, true)
		},
	)

	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", amount1)
}

func checkUnclaimedFeesAfterFirstSwap(cur realm) {
	testing.SetRealm(adminRealm)
	amount0, amount1 := position.GetUnclaimedFee(1)

	ufmt.Printf("[EXPECTED] Unclaimed fee0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Unclaimed fee1 should be %s\n", amount1)
}

func executeSecondSwap(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, INT64_MAX)

	// set current realm and origin caller
	ufmt.Println("[INFO] Executing second swap")
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	amount0, amount1 := pool.Swap(
		cross(cur),
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"20000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(cur, barPath, fooPath, amount0Delta, amount1Delta, true)
		},
	)

	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", amount1)
}

func checkUnclaimedFeesAfterSecondSwap(cur realm) {
	testing.SetRealm(adminRealm)
	amount0, amount1 := position.GetUnclaimedFee(1)

	ufmt.Printf("[EXPECTED] Unclaimed fee0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Unclaimed fee1 should be %s\n", amount1)
}

func executeThirdSwap(cur realm) {
	testing.SetRealm(adminRealm)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	ufmt.Println("[INFO] Executing third swap")
	amount0, amount1 := pool.Swap(
		cross(cur),
		barPath,
		fooPath,
		fee500,
		adminAddr,
		false,
		"20000000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(cur, barPath, fooPath, amount0Delta, amount1Delta, false)
		},
	)

	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", amount1)
}

func checkFinalUnclaimedFees(cur realm) {
	testing.SetRealm(adminRealm)
	amount0, amount1 := position.GetUnclaimedFee(1)

	ufmt.Printf("[EXPECTED] Final unclaimed fee0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Final unclaimed fee1 should be %s\n", amount1)
}

func mockSwapCallback(cur realm, token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, zeroForOne bool) error {
	testing.SetRealm(adminRealm)

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross(cur), token0Path, poolAddr, amount0Delta)
	}

	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross(cur), token1Path, poolAddr, amount1Delta)
	}

	return nil
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
