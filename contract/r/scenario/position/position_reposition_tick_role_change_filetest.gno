// position reposition tick role change test
// Tests the scenario where a tick changes its role from lower to upper boundary

// PKGPATH: gno.land/r/demo/main

package main

import (
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

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())

	barPath        = "gno.land/r/onbloc/bar"
	fooPath        = "gno.land/r/onbloc/foo"
	fee500  uint32 = 500
	poolPath       = barPath + ":" + fooPath + ":500"
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool at tick 10000")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint Position (tickLower=9000, tickUpper=13000)")
	mintPosition()
	println()

	ufmt.Println("[SCENARIO] 3. Check tick 9000 state (lower tick role)")
	checkTick9000AsLower()
	println()

	ufmt.Println("[SCENARIO] 4. Execute swap to change price")
	executeSwap()
	println()

	ufmt.Println("[SCENARIO] 5. Reposition to new range (5000~9000)")
	repositionToNewRange()
	println()

	ufmt.Println("[SCENARIO] 6. Check tick 9000 state (upper tick role)")
	checkTick9000AsUpper()
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

	p, _ := pool.GetPool(barPath, fooPath, fee500)
	ufmt.Printf("[EXPECTED] Pool tick should be %d\n", p.Slot0Tick())
	ufmt.Printf("[EXPECTED] Pool liquidity should be %s\n", p.Liquidity().ToString())
}

func mintPosition() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting Position with range [9000, 13000]")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		9000,
		13000,
		"100000000",
		"100000000",
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

func checkTick9000AsLower() {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Checking tick 9000 state as lower boundary")
	tickInfo, err := pool.GetTickInfo(poolPath, 9000)
	if err != nil {
		panic(ufmt.Sprintf("Failed to get tick info: %s", err.Error()))
	}

	ufmt.Printf("[EXPECTED] Tick 9000 liquidityGross should be %s\n", tickInfo.LiquidityGross().ToString())
	ufmt.Printf("[EXPECTED] Tick 9000 liquidityNet should be %s (positive for lower tick)\n", tickInfo.LiquidityNet().ToString())
	ufmt.Printf("[EXPECTED] Tick 9000 initialized should be %t\n", tickInfo.Initialized())
}

func executeSwap() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)

	p, _ := pool.GetPool(barPath, fooPath, fee500)
	ufmt.Printf("[INFO] Pool tick before swap: %d\n", p.Slot0Tick())

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	ufmt.Println("[INFO] Executing swap to change price")
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"10000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, true)
		},
	)

	testing.SetRealm(adminRealm)
	p, _ = pool.GetPool(barPath, fooPath, fee500)
	ufmt.Printf("[EXPECTED] Swap amount0: %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1: %s\n", amount1)
	ufmt.Printf("[EXPECTED] Pool tick after swap: %d\n", p.Slot0Tick())
}

func repositionToNewRange() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Collecting fees before reposition")
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1, false)
	ufmt.Printf("[EXPECTED] Collected fee0: %s\n", fee0)
	ufmt.Printf("[EXPECTED] Collected fee1: %s\n", fee1)

	ufmt.Println("[INFO] Decreasing liquidity to clear position")
	_, _, _, _, amount0Decreased, amount1Decreased, _ := position.DecreaseLiquidity(
		cross,
		1,
		"1183668969", // full liquidity
		"0",
		"0",
		9999999999,
		false,
	)
	ufmt.Printf("[EXPECTED] Decreased amount0: %s\n", amount0Decreased)
	ufmt.Printf("[EXPECTED] Decreased amount1: %s\n", amount1Decreased)

	ufmt.Println("[INFO] Repositioning to new range [5000, 9000]")
	_, liquidity, tickLower, tickUpper, amount0, amount1 := position.Reposition(
		cross,
		1,
		5000,
		9000,
		"100000000",
		"100000000",
		"0",
		"0",
		9999999999,
	)

	ufmt.Printf("[EXPECTED] New liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] New tick range: [%d, %d]\n", tickLower, tickUpper)
	ufmt.Printf("[EXPECTED] Amount0: %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1: %s\n", amount1)
}

func checkTick9000AsUpper() {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Checking tick 9000 state as upper boundary")
	tickInfo, err := pool.GetTickInfo(poolPath, 9000)
	if err != nil {
		panic(ufmt.Sprintf("Failed to get tick info: %s", err.Error()))
	}

	ufmt.Printf("[EXPECTED] Tick 9000 liquidityGross should be %s\n", tickInfo.LiquidityGross().ToString())
	ufmt.Printf("[EXPECTED] Tick 9000 liquidityNet should be %s (negative for upper tick)\n", tickInfo.LiquidityNet().ToString())
	ufmt.Printf("[EXPECTED] Tick 9000 initialized should be %t\n", tickInfo.Initialized())
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, zeroForOne bool) error {
	testing.SetRealm(adminRealm)

	if zeroForOne {
		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	} else {
		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] 1. Initialize pool at tick 10000
// [INFO] Creating pool at tick 10000
// [EXPECTED] Pool tick should be 10000
// [EXPECTED] Pool liquidity should be 0
//
// [SCENARIO] 2. Mint Position (tickLower=9000, tickUpper=13000)
// [INFO] Minting Position with range [9000, 13000]
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 1183668969
// [EXPECTED] Amount0 should be 100000000
// [EXPECTED] Amount1 should be 95170720
//
// [SCENARIO] 3. Check tick 9000 state (lower tick role)
// [INFO] Checking tick 9000 state as lower boundary
// [EXPECTED] Tick 9000 liquidityGross should be 1183668969
// [EXPECTED] Tick 9000 liquidityNet should be 1183668969 (positive for lower tick)
// [EXPECTED] Tick 9000 initialized should be true
//
// [SCENARIO] 4. Execute swap to change price
// [INFO] Pool tick before swap: 10000
// [INFO] Executing swap to change price
// [EXPECTED] Swap amount0: 10000000
// [EXPECTED] Swap amount1: -26794841
// [EXPECTED] Pool tick after swap: 9723
//
// [SCENARIO] 5. Reposition to new range (5000~9000)
// [INFO] Collecting fees before reposition
// [EXPECTED] Collected fee0: 4950
// [EXPECTED] Collected fee1: 0
// [INFO] Decreasing liquidity to clear position
// [EXPECTED] Decreased amount0: 109994999
// [EXPECTED] Decreased amount1: 68375877
// [INFO] Repositioning to new range [5000, 9000]
// [EXPECTED] New liquidity: 351781291
// [EXPECTED] New tick range: [5000, 9000]
// [EXPECTED] Amount0: 0
// [EXPECTED] Amount1: 100000000
//
// [SCENARIO] 6. Check tick 9000 state (upper tick role)
// [INFO] Checking tick 9000 state as upper boundary
// [EXPECTED] Tick 9000 liquidityGross should be 351781291
// [EXPECTED] Tick 9000 liquidityNet should be -351781291 (negative for upper tick)
// [EXPECTED] Tick 9000 initialized should be true
