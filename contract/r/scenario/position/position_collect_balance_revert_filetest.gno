// position collect reverts on insufficient internal balance

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/demo/defi/grc20reg"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"
	_ "gno.land/r/gnoswap/pool/collect_balance_revert"
	_ "gno.land/r/gnoswap/pool/v1"
	"gno.land/r/gnoswap/position"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac"
	_ "gno.land/r/gnoswap/staker/v1"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"

	poolV1Path                = "gno.land/r/gnoswap/pool/v1"
	poolCollectRevertTestPath = "gno.land/r/gnoswap/pool/collect_balance_revert"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	fooPath = "gno.land/r/onbloc/foo.FOO"
	fee     = uint32(3000)
	poolKey = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000"
)

func main(cur realm) {
	ufmt.Println("[SCENARIO] 1. Initialize pool")
	initPool(cur)
	println()

	ufmt.Println("[SCENARIO] 2. Mint position")
	mintPosition(cur)
	println()

	ufmt.Println("[SCENARIO] 3. Swap to move price")
	executeSwap(cur)
	println()

	ufmt.Println("[SCENARIO] 4. Upgrade to balance-revert test implementation")
	upgradePool(cur)
	println()

	ufmt.Println("[SCENARIO] 5. Decrease liquidity with reverting Collect")
	decreaseLiquidityWithRevertingCollect(cur)
	println()

	ufmt.Println("[SCENARIO] 6. Restore pool implementation")
	restorePool(cur)
}

func initPool(cur realm) {
	testing.SetRealm(adminRealm)
	pool.UpgradeImpl(cross(cur), poolV1Path)
	pool.SetPoolCreationFee(cross(cur), 0)

	bar.Approve(cross(cur), poolAddr, INT64_MAX)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)

	pool.CreatePool(
		cross(cur),
		barPath,
		fooPath,
		fee,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
	ufmt.Printf("[EXPECTED] Pool implementation should be %s\n", pool.GetImplementationPackagePath())
}

func mintPosition(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, INT64_MAX)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)

	positionId, _, _, _ := position.Mint(
		cross(cur),
		barPath,
		fooPath,
		fee,
		-960,
		960,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
}

func executeSwap(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, INT64_MAX)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	pool.Swap(
		cross(cur),
		barPath,
		fooPath,
		fee,
		adminAddr,
		true,
		"10000000",
		MIN_PRICE,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(cur, amount0Delta, amount1Delta)
		},
	)

	ufmt.Println("[EXPECTED] Swap should succeed")
}

func upgradePool(cur realm) {
	testing.SetRealm(adminRealm)
	pool.UpgradeImpl(cross(cur), poolCollectRevertTestPath)
	ufmt.Printf("[EXPECTED] Pool implementation should be %s\n", pool.GetImplementationPackagePath())
}

func decreaseLiquidityWithRevertingCollect(cur realm) {
	testing.SetRealm(adminRealm)
	barBefore := bar.BalanceOf(adminAddr)
	owed0Before, _ := position.GetPositionTokensOwed0(1)

	// Internal balance is desynced low (forced to 1 by the test implementation)
	// while tokensOwed0 is larger. The underlying Collect cannot pay, so the
	// whole DecreaseLiquidity must revert instead of persisting a negative
	// pool balance. revive catches the cross-realm abort.
	r := revive(func() {
		position.DecreaseLiquidity(
			cross(cur),
			1,
			"100000000",
			"0",
			"0",
			time.Now().Unix()+3600,
		)
	})

	barAfter := bar.BalanceOf(adminAddr)
	owed0After, _ := position.GetPositionTokensOwed0(1)
	poolBalance0, _ := pool.GetBalanceToken0(poolKey)

	if r != nil {
		ufmt.Printf("[INFO] DecreaseLiquidity aborted: %v\n", r)
	} else {
		println("[WARNING] DecreaseLiquidity did not abort (unexpected)")
	}

	ufmt.Printf("[INFO] BAR balance change: %d (unchanged)\n", barAfter-barBefore)
	ufmt.Printf("[INFO] Pool token0 balance: %d (not negative)\n", poolBalance0)
	ufmt.Printf("[INFO] tokensOwed0 unchanged: %v\n", owed0After == owed0Before)

	if r == nil {
		panic("[ERROR] DecreaseLiquidity should have reverted on insufficient internal balance")
	}
	if poolBalance0 < 0 {
		panic(ufmt.Sprintf("[ERROR] pool token0 balance should not be negative, got %d", poolBalance0))
	}
	if owed0After != owed0Before {
		panic(ufmt.Sprintf("[ERROR] tokensOwed0 should stay unchanged after revert, got %d", owed0After))
	}
}

func restorePool(cur realm) {
	testing.SetRealm(adminRealm)
	pool.UpgradeImpl(cross(cur), poolV1Path)
	ufmt.Printf("[EXPECTED] Pool implementation should be %s\n", pool.GetImplementationPackagePath())
}

func mockSwapCallback(cur realm, amount0Delta int64, amount1Delta int64) error {
	testing.SetRealm(adminRealm)

	if amount0Delta > 0 {
		grc20reg.Transfer(0, cur, barPath, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		grc20reg.Transfer(0, cur, fooPath, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] 1. Initialize pool
// [EXPECTED] Pool implementation should be gno.land/r/gnoswap/pool/v1
//
// [SCENARIO] 2. Mint position
// [EXPECTED] Position ID should be 1
//
// [SCENARIO] 3. Swap to move price
// [EXPECTED] Swap should succeed
//
// [SCENARIO] 4. Upgrade to balance-revert test implementation
// [EXPECTED] Pool implementation should be gno.land/r/gnoswap/pool/collect_balance_revert
//
// [SCENARIO] 5. Decrease liquidity with reverting Collect
// [INFO] DecreaseLiquidity aborted: [GNOSWAP-POOL-021] balance update failed. cannot decrease, token0(1) - amount(29999)
// [INFO] BAR balance change: 0 (unchanged)
// [INFO] Pool token0 balance: 1 (not negative)
// [INFO] tokensOwed0 unchanged: true
//
// [SCENARIO] 6. Restore pool implementation
// [EXPECTED] Pool implementation should be gno.land/r/gnoswap/pool/v1
