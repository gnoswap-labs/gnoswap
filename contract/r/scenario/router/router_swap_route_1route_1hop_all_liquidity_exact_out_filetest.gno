package main

import (
	"testing"
	"time"

	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/access"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
	btcPath = "gno.land/r/gnoswap/test_token/btc"

	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

var (
	fee500  uint32 = 500
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
	println("[INFO] Creating atom-atone pool (fee: 500)")
	pl.CreatePool(cross, atomPath, atonePath, fee500, common.TickMathGetSqrtRatioAtTick(1).ToString())

	println("[INFO] Approving tokens for pool operations")
	atom.Approve(cross, poolAddr, 100000)
	atone.Approve(cross, poolAddr, 100000)

	// Mint
	println("[INFO] Minting position in atom-atone pool")
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, atomPath, atonePath, fee500, int32(-6000), int32(6000), "100000", "100000", "0", "0", max_timeout, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 1")
	println("[EXPECTED] amount0:", amount0, "expected: 99962")
	println("[EXPECTED] amount1:", amount1, "expected: 100000")

	pool, _ := pl.GetPool(atomPath, atonePath, fee500)
	poolLiq := pool.Liquidity()
	println("[EXPECTED] pool liquidity:", poolLiq.ToString(), "expected: 385771")

	poolPath := "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500"
	poolTick := pl.GetSlot0Tick(poolPath)
	println("[EXPECTED] pool tick:", poolTick, "expected: 1")

	println("[INFO] Setting up additional pools and positions")
	createPoolWithoutFee(t)
	makeForthMintPositionWithoutFee(t)

	println("[INFO] Setting swap permissions")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving tokens for swap")
	atom.Approve(cross, routerAddr, max_approve)
	atone.Approve(cross, routerAddr, max_approve) // ITS FOR 0.15% fee

	expectedAmountSpecified := "119820"

	println("[INFO] Attempting ExactOut swap (atom →", expectedAmountSpecified, "atone) with fee is almost 120000")
	println("[INFO] Expected to fail due to insufficient liquidity")

	println("[EXPECTED] Swap should fail with error: [GNOSWAP-ROUTER-001] slippage check failed || ExactOut: too much spent (max:0, used:168406)")

	uassert.AbortsWithMessage(
		t,
		`[GNOSWAP-ROUTER-001] slippage check failed || ExactOut: too much spent (max:0, used:168406)`,
		func() {
			router.ExactOutSwapRoute(
				cross,
				atomPath,                 // inputToken
				atonePath,                 // outputToken
				expectedAmountSpecified, // amountSpecified
				poolPath,                // strRouteArr
				"100",                   // quoteArr
				"0",                     // tokenAmountLimit
				time.Now().Add(time.Hour).Unix(),
				"", // referrer
			)
		})
	println("[INFO] Scenario completed")
}

func createPoolWithoutFee(t *testing.T) {
	testing.SetRealm(adminRealm)
	// set pool create fee to 0 for testing
	pl.SetPoolCreationFee(cross, 0)
	createPool(t, atomPath, btcPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString(), adminAddr)
	createPool(t, atonePath, btcPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString(), adminAddr)
	createPool(t, atomPath, atonePath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString(), adminAddr)
	createPool(t, atomPath, atonePath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString(), adminAddr)
}

func createPool(t *testing.T,
	token0 string,
	token1 string,
	fee uint32,
	sqrtPriceX96 string,
	caller address,
) {
	t.Helper()

	testing.SetRealm(testing.NewUserRealm(caller))
	poolPath := pl.GetPoolPath(token0, token1, fee)
	if !pl.ExistsPoolPath(poolPath) {
		pl.CreatePool(cross, token0, token1, fee, sqrtPriceX96)
		sr.SetPoolTier(cross, poolPath, tier1)
	}
}

func makeForthMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	// make actual data to test resetting not only position's state but also pool's state
	testing.SetRealm(adminRealm)

	atomApprove(t, adminAddr, poolAddr, max_approve)
	atoneApprove(t, adminAddr, poolAddr, max_approve)

	// mint position
	return pn.Mint(
		cross,
		atomPath,
		atonePath,
		fee500,
		-887220,
		887220,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		adminAddr,
		"",
	)
}

func atomApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	atom.Approve(cross, spender, amount)
}

func atoneApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	atone.Approve(cross, spender, amount)
}

// Output:
// [SCENARIO] #2 All Liquidity ExactOut 1route 1hop
// [INFO] Starting scenario: All liquidity exact out 1route 1hop
// [INFO] Setting up pool and position
// [INFO] Approving pool creation fee
// [INFO] Creating atom-atone pool (fee: 500)
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in atom-atone pool
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
// [INFO] Attempting ExactOut swap (atom → 119820 atone) with fee is almost 120000
// [INFO] Expected to fail due to insufficient liquidity
// [EXPECTED] Swap should fail with error: [GNOSWAP-ROUTER-001] slippage check failed || ExactOut: too much spent (max:0, used:168406)
// [INFO] Scenario completed
