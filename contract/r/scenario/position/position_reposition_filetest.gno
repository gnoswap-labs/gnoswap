// position reposition

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

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
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
		func(cur realm, amount0Delta, amount1Delta int64) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, true)
		},
	)

	testing.SetRealm(adminRealm)
	p = pool.GetPool(barPath, fooPath, fee500)
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
		9999999999,
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
	testing.SetRealm(adminRealm)
	p := pool.GetPool(barPath, fooPath, fee500)
	println("[DEBUG] Tick before second swap:", p.Slot0Tick())
	println("[DEBUG] Pool liquidity:", p.Liquidity().ToString())

	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, INT64_MAX)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	ufmt.Println("[INFO] Executing swap in new range")
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		false,
		"20000000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, false)
		},
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
