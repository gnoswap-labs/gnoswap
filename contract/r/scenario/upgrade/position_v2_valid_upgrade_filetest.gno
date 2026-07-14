// PKGPATH: gno.land/r/gnoswap/v1/main

// Position contract upgrade to v2_valid scenario test.
//
// v2_valid is a symlinked copy of the v1 position sources published under a
// v2_valid module path. This test targets the interrealm-v2 readonly-taint
// concern: position data structures (the positions BPTree and per-position
// structs) are created by the v1 implementation realm, the active
// implementation is then switched to v2_valid, and the SAME v1-created
// position is read-modify-written through v2_valid via real state-changing
// entry points (Mint, IncreaseLiquidity, DecreaseLiquidity, CollectFee,
// Reposition, SetPositionOperator).
//
// Because the positions tree and structs are owned by the domain (proxy)
// realm and all writes are routed through domain-owned methods, mutating
// v1-created data through v2_valid must NOT trigger a readonly-taint panic.
// A PASS proves the migration path is taint-safe for every mutating entry
// point exposed by proxy.gno.
package main

import (
	"math"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/position/v2_valid"
	_ "gno.land/r/gnoswap/router/v1"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())

	// SetPositionOperator is staker-only (access.AssertIsStaker), so it must be
	// invoked from the staker realm rather than from admin.
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm   = testing.NewUserRealm(stakerAddr)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee500  = uint32(500)

	positionId    = uint64(1)
	newPositionId = uint64(2)

	operatorAddr = testutils.TestAddress("operator")
)

const (
	poolV1Path          = "gno.land/r/gnoswap/pool/v1"
	positionV1Path      = "gno.land/r/gnoswap/position/v1"
	positionV2ValidPath = "gno.land/r/gnoswap/position/v2_valid"
	routerV1Path        = "gno.land/r/gnoswap/router/v1"
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize pool + position + router with v1")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Create v1 data: pool + position + swap")
	createPoolV1(cur)
	mintPositionV1(cur)
	swapV1(cur)
	println()

	println("[SCENARIO] 3. Read v1-created position data via getters")
	printPositionData(cur)
	println()

	println("[SCENARIO] 4. Upgrade position implementation to v2_valid")
	upgradeToV2Valid(cur)
	println()

	println("[SCENARIO] 5. Mutate v1 position through v2_valid (taint-prone RMW)")
	increaseLiquidityV2Valid(cur)
	decreaseLiquidityV2Valid(cur)
	collectFeeV2Valid(cur)
	println()

	println("[SCENARIO] 6. Read position data after v2_valid increase/decrease/collect")
	printPositionData(cur)
	println()

	println("[SCENARIO] 7. Mint a NEW position through v2_valid (BPTree insert post-upgrade)")
	mintPositionV2Valid(cur)
	printNewPositionData(cur)
	println()

	println("[SCENARIO] 8. SetPositionOperator on v1 position through v2_valid (RMW operator field)")
	setPositionOperatorV2Valid(cur)
	println()

	println("[SCENARIO] 9. Reposition v1 position through v2_valid (clear then re-mint into new ticks)")
	clearV1PositionForReposition(cur)
	repositionV2Valid(cur)
	println()

	println("[SCENARIO] 10. Read final v1 position data after v2_valid reposition")
	printPositionData(cur)
	println()
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)
	pool.UpgradeImpl(cross(cur), poolV1Path)
	position.UpgradeImpl(cross(cur), positionV1Path)
	router.UpgradeImpl(cross(cur), routerV1Path)
	ufmt.Printf("[EXPECTED] Position implementation: %s\n", position.GetImplementationPackagePath())
}

func createPoolV1(cur realm) {
	testing.SetRealm(adminRealm)
	pool.CreatePool(cross(cur), barPath, fooPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	ufmt.Printf("[EXPECTED] Created pool: %s\n", pool.GetPoolPath(barPath, fooPath, fee500))
}

// mintPositionV1 mints a position with the v1 implementation realm. This
// allocates an entry in the positions BPTree plus a position struct owned by
// the domain realm but written by v1.
func mintPositionV1(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)

	id, liq, _, _ := position.Mint(cross(cur), barPath, fooPath, fee500, -960, 960, "50000000", "50000000", "0", "0", time.Now().Unix()+3600, adminAddr, "")
	ufmt.Printf("[EXPECTED] v1 minted position id=%d liquidity=%s\n", id, liq)
}

// swapV1 swaps through the v1 pool so the v1-created position accrues fees.
func swapV1(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), routerAddr, math.MaxInt64)
	foo.Approve(cross(cur), routerAddr, math.MaxInt64)

	in, out := router.ExactInSwapRoute(cross(cur), fooPath, barPath, "1000000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1", int64(9999999999), "")
	ufmt.Printf("[EXPECTED] v1 swap in=%s out=%s\n", in, out)
}

func upgradeToV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	position.UpgradeImpl(cross(cur), positionV2ValidPath)
	ufmt.Printf("[EXPECTED] Upgraded position implementation: %s\n", position.GetImplementationPackagePath())
}

// increaseLiquidityV2Valid adds liquidity to the v1-created position through
// v2_valid. This RMWs the v1-allocated position struct (liquidity, fee growth
// snapshots) and the positions BPTree node.
func increaseLiquidityV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)

	id, liq, _, _, _ := position.IncreaseLiquidity(cross(cur), positionId, "10000000", "10000000", "0", "0", time.Now().Unix()+3600)
	ufmt.Printf("[EXPECTED] v2_valid increased position id=%d liquidity=%s\n", id, liq)
}

// decreaseLiquidityV2Valid removes part of the liquidity from the v1-created
// position through v2_valid, another RMW of the v1-allocated struct.
func decreaseLiquidityV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	id, liq, _, _, _, _, _ := position.DecreaseLiquidity(cross(cur), positionId, "5000000", "0", "0", time.Now().Unix()+3600)
	ufmt.Printf("[EXPECTED] v2_valid decreased position id=%d liquidity=%s\n", id, liq)
}

// collectFeeV2Valid collects the fees accrued by the v1-created position
// (from the v1 swap) through v2_valid. This RMWs the tokensOwed/feeGrowth
// fields of the v1-allocated position struct.
func collectFeeV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	id, amount0, amount1, poolPath, _, _ := position.CollectFee(cross(cur), positionId)
	ufmt.Printf("[EXPECTED] v2_valid collected fee id=%d amount0=%s amount1=%s pool=%s\n", id, amount0, amount1, poolPath)
}

// mintPositionV2Valid mints a brand-new position through v2_valid. This proves
// a BPTree insert (new node allocation) and a fresh position struct allocation
// performed by the v2_valid implementation against the domain-owned positions
// tree are taint-safe post-upgrade.
func mintPositionV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)

	id, liq, _, _ := position.Mint(cross(cur), barPath, fooPath, fee500, -960, 960, "20000000", "20000000", "0", "0", time.Now().Unix()+3600, adminAddr, "")
	ufmt.Printf("[EXPECTED] v2_valid minted NEW position id=%d liquidity=%s\n", id, liq)
}

// setPositionOperatorV2Valid sets an operator on the v1-created position
// through v2_valid. This RMWs the operator field of the v1-allocated struct.
// The entry point asserts the caller is the staker (access.AssertIsStaker),
// so it is invoked from the staker realm.
func setPositionOperatorV2Valid(cur realm) {
	testing.SetRealm(stakerRealm)
	position.SetPositionOperator(cross(cur), positionId, operatorAddr)
	ufmt.Printf("[EXPECTED] v2_valid set operator id=%d operator=%s\n", positionId, position.GetPositionOperator(positionId))
}

// clearV1PositionForReposition fully drains the v1 position so it satisfies the
// Reposition precondition (position must be clear: liquidity == 0 and
// tokensOwed0/1 == 0). It removes 100% of the remaining liquidity through
// v2_valid and then collects fees to zero out tokensOwed.
func clearV1PositionForReposition(cur realm) {
	testing.SetRealm(adminRealm)
	remaining := position.GetPositionLiquidity(positionId)
	id, liq, _, _, _, _, _ := position.DecreaseLiquidity(cross(cur), positionId, remaining, "0", "0", time.Now().Unix()+3600)
	ufmt.Printf("[EXPECTED] v2_valid drained position id=%d removedLiquidity=%s\n", id, liq)

	cid, amount0, amount1, _, _, _ := position.CollectFee(cross(cur), positionId)
	ufmt.Printf("[EXPECTED] v2_valid cleared owed id=%d amount0=%s amount1=%s liquidity=%s\n",
		cid, amount0, amount1, position.GetPositionLiquidity(positionId))
}

// repositionV2Valid repositions the now-cleared v1 position into a new tick
// range through v2_valid. Reposition is the heaviest RMW: it re-mints liquidity
// into the position struct, rewrites tickLower/tickUpper/feeGrowth snapshots,
// flips the burned flag, and updates the positions BPTree node.
func repositionV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)

	id, liq, tickLower, tickUpper, _, _ := position.Reposition(cross(cur), positionId, -1020, 1020, "30000000", "30000000", "0", "0", time.Now().Unix()+3600)
	ufmt.Printf("[EXPECTED] v2_valid repositioned id=%d liquidity=%s tickLower=%d tickUpper=%d\n", id, liq, tickLower, tickUpper)
}

func printPositionData(cur realm) {
	liquidity := position.GetPositionLiquidity(positionId)
	tickLower, tickUpper := position.GetPositionTicks(positionId)
	poolKey := position.GetPositionPoolKey(positionId)
	ufmt.Printf("[EXPECTED] position id=%d liquidity=%s tickLower=%d tickUpper=%d pool=%s\n",
		positionId, liquidity, tickLower, tickUpper, poolKey)
}

func printNewPositionData(cur realm) {
	liquidity := position.GetPositionLiquidity(newPositionId)
	tickLower, tickUpper := position.GetPositionTicks(newPositionId)
	poolKey := position.GetPositionPoolKey(newPositionId)
	ufmt.Printf("[EXPECTED] position id=%d liquidity=%s tickLower=%d tickUpper=%d pool=%s\n",
		newPositionId, liquidity, tickLower, tickUpper, poolKey)
}

// Output:
// [SCENARIO] 1. Initialize pool + position + router with v1
// [EXPECTED] Position implementation: gno.land/r/gnoswap/position/v1
//
// [SCENARIO] 2. Create v1 data: pool + position + swap
// [EXPECTED] Created pool: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] v1 minted position id=1 liquidity=1066918731
// [EXPECTED] v1 swap in=1000000 out=-997067
//
// [SCENARIO] 3. Read v1-created position data via getters
// [EXPECTED] position id=1 liquidity=1066918731 tickLower=-960 tickUpper=960 pool=gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
//
// [SCENARIO] 4. Upgrade position implementation to v2_valid
// [EXPECTED] Upgraded position implementation: gno.land/r/gnoswap/position/v2_valid
//
// [SCENARIO] 5. Mutate v1 position through v2_valid (taint-prone RMW)
// [EXPECTED] v2_valid increased position id=1 liquidity=209201802
// [EXPECTED] v2_valid decreased position id=1 liquidity=5000000
// [EXPECTED] v2_valid collected fee id=1 amount0=0 amount1=0 pool=gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
//
// [SCENARIO] 6. Read position data after v2_valid increase/decrease/collect
// [EXPECTED] position id=1 liquidity=1271120533 tickLower=-960 tickUpper=960 pool=gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
//
// [SCENARIO] 7. Mint a NEW position through v2_valid (BPTree insert post-upgrade)
// [EXPECTED] v2_valid minted NEW position id=2 liquidity=418403604
// [EXPECTED] position id=2 liquidity=418403604 tickLower=-960 tickUpper=960 pool=gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
//
// [SCENARIO] 8. SetPositionOperator on v1 position through v2_valid (RMW operator field)
// [EXPECTED] v2_valid set operator id=1 operator=g1dacx2unpw3hhyh6lta047h6lta047h6l7tdt3w
//
// [SCENARIO] 9. Reposition v1 position through v2_valid (clear then re-mint into new ticks)
// [EXPECTED] v2_valid drained position id=1 removedLiquidity=1271120533
// [EXPECTED] v2_valid cleared owed id=1 amount0=0 amount1=0 liquidity=0
// [EXPECTED] v2_valid repositioned id=1 liquidity=592233260 tickLower=-1020 tickUpper=1020
//
// [SCENARIO] 10. Read final v1 position data after v2_valid reposition
// [EXPECTED] position id=1 liquidity=592233260 tickLower=-1020 tickUpper=1020 pool=gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
//
