package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/v1/access"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"
	"gno.land/r/gnoswap/v1/router"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"

	"gno.land/r/gnoswap/v1/gns"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	fooPath = "gno.land/r/onbloc/foo"

	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

var (
	fee500 uint32 = 500
	fee3000 uint32 = 3000

	tier1 uint64 = 1
)

var t *testing.T

func main() {
	println("[SCENARIO] #2 All Liquidity ExactOut 1route 1hop")
	println("[INFO] Starting scenario: All liquidity exact out 1route 1hop")
	
	println("[INFO] Setting up pool and position")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
	println("[INFO] Creating bar-baz pool (fee: 500)")
	pl.CreatePool(cross, barPath, bazPath, fee500, common.TickMathGetSqrtRatioAtTick(1).ToString())

	println("[INFO] Approving tokens for pool operations")
	bar.Approve(cross, poolAddr, 100000)
	baz.Approve(cross, poolAddr, 100000)

	// Mint
	println("[INFO] Minting position in bar-baz pool")
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, barPath, bazPath, fee500, int32(-6000), int32(6000), "100000", "100000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 1")
	println("[EXPECTED] amount0:", amount0, "expected: 99962")
	println("[EXPECTED] amount1:", amount1, "expected: 100000")

	pool := pl.GetPool(barPath, bazPath, fee500)
	poolLiq := pool.Liquidity()
	println("[EXPECTED] pool liquidity:", poolLiq.ToString(), "expected: 385771")

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500"
	poolTick := pl.PoolGetSlot0Tick(poolPath)
	println("[EXPECTED] pool tick:", poolTick, "expected: 1")

	println("[INFO] Setting up additional pools and positions")
	createPoolWithoutFee(t)
	makeForthMintPositionWithoutFee(t)

	println("[INFO] Setting swap permissions")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	bar.Approve(cross, poolAddr, max_approve)
	baz.Approve(cross, routerAddr, max_approve) // ITS FOR 0.15% fee

	println("[INFO] Attempting ExactOut swap (bar → 120000 baz)")
	println("[INFO] Expected to fail due to insufficient liquidity")

	println("[EXPECTED] Swap should fail with error: [GNOSWAP-ROUTER-002] slippage check failed || ExactOut: too much spent (max:0, used:168406)")

	uassert.AbortsWithMessage(
		t,
		`[GNOSWAP-ROUTER-002] slippage check failed || ExactOut: too much spent (max:0, used:168406)`,
		func() {
		router.ExactOutSwapRoute(
			cross,
			barPath,  // inputToken
			bazPath,  // outputToken
			"120000", // amountSpecified
			poolPath, // strRouteArr
			"100",    // quoteArr
			"0",      // tokenAmountLimit
			time.Now().Add(time.Hour).Unix(),
			"", // referrer
		)
	})
	println("[INFO] Scenario completed")
}

func createPoolWithoutFee(t *testing.T) {
	testing.SetRealm(adminRealm)
	// set pool create fee to 0 for testing
	pl.SetPoolCreationFeeByAdmin(cross, 0)
	createPool(t, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString(), adminAddr)
	createPool(t, bazPath, fooPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString(), adminAddr)
	createPool(t, barPath, bazPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString(), adminAddr)
	createPool(t, barPath, bazPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString(), adminAddr)
}

func createPool(t *testing.T,
	token0 string,
	token1 string,
	fee uint32,
	sqrtPriceX96 string,
	caller std.Address,
) {
	t.Helper()

	testing.SetRealm(std.NewUserRealm(caller))
	poolPath := pl.GetPoolPath(token0, token1, fee)
	if !pl.DoesPoolPathExist(poolPath) {
		pl.CreatePool(cross, token0, token1, fee, sqrtPriceX96)
		sr.SetPoolTierByAdmin(cross, poolPath, tier1)
	}
}

func makeForthMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	// make actual data to test resetting not only position's state but also pool's state
	testing.SetRealm(adminRealm)

	barApprove(t, adminAddr, poolAddr, max_approve)
	bazApprove(t, adminAddr, poolAddr, max_approve)

	// mint position
	return pn.Mint(
		cross,
		barPath,
		bazPath,
		fee500,
		-887220,
		887220,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)
}

func barApprove(t *testing.T, owner, spender std.Address, amount int64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(owner))
	bar.Approve(cross, spender, amount)
}

func bazApprove(t *testing.T, owner, spender std.Address, amount int64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(owner))
	baz.Approve(cross, spender, amount)
}

// Output:
// [SCENARIO] #2 All Liquidity ExactOut 1route 1hop
// [INFO] Starting scenario: All liquidity exact out 1route 1hop
// [INFO] Setting up pool and position
// [INFO] Approving pool creation fee
// [INFO] Creating bar-baz pool (fee: 500)
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in bar-baz pool
// [INFO] positionId: 1
// [INFO] amount0: 99962
// [INFO] amount1: 100000
// [INFO] liquidity: 385771
// [EXPECTED] positionId: 1 expected: 1
// [EXPECTED] amount0: 99962 expected: 99962
// [EXPECTED] amount1: 100000 expected: 100000
// [EXPECTED] pool liquidity: 385771 expected: 385771
// [EXPECTED] pool tick: 1 expected: 1
// [INFO] Setting up additional pools and positions
// [INFO] Setting swap permissions
// [INFO] Approving tokens for swap
// [INFO] Attempting ExactOut swap (bar → 120000 baz)
// [INFO] Expected to fail due to insufficient liquidity
// [EXPECTED] Swap should fail with error: [GNOSWAP-ROUTER-002] slippage check failed || ExactOut: too much spent (max:0, used:168406)
// [INFO] Scenario completed
