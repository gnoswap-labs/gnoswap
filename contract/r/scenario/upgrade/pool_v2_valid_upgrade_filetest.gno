// PKGPATH: gno.land/r/gnoswap/v1/main

// Pool contract upgrade to v2_valid scenario test.
//
// v2_valid is a symlinked copy of the v1 pool sources published under a
// v2_valid module path. This test focuses on the interrealm-v2 readonly-taint
// concern: data structures (pools/positions BPTrees, ticks, tick bitmaps,
// slot0, oracle observations) are created by the v1 implementation realm, the
// active implementation is then switched to v2_valid, and the SAME v1-created
// data is mutated through v2_valid via real state-changing entry points.
//
// This test exercises ALL state-mutating pool entry points through v2_valid
// after the upgrade, to prove the v1->v2_valid migration is taint-safe across
// every RMW path:
//
//   - CreatePool                          (pools BPTree insert: second pool)
//   - Mint                                (positions/ticks BPTree + slot0 RMW)
//   - Swap                                (slot0 + fee growth + bitmaps RMW)
//   - Burn / Collect / HandleWithdrawalFee (driven via position.DecreaseLiquidity,
//                                          which is the only legitimate caller of
//                                          the position-role-gated pool entry points)
//   - CollectProtocol                     (protocol fee accounting RMW)
//   - SetFeeProtocol                      (iterates pools BPTree, RMWs every slot0)
//   - IncreaseObservationCardinalityNext  (oracle observation array RMW)
//   - SetPoolCreationFee / SetWithdrawalFee (scalar store writes)
//   - SetSwapStartHook / SetSwapEndHook / SetTickCrossHook (func store writes,
//                                          staker-role-gated)
//
// Because storage is owned by the domain (proxy) realm and all writes are
// routed through domain-owned trees/methods, mutating v1-created data through
// v2_valid must NOT trigger a readonly-taint panic. A PASS proves the
// migration path is taint-safe.
package main

import (
	"math"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/pool/v2_valid"
	_ "gno.land/r/gnoswap/router/v1"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())

	// staker-role realm: the Set*Hook entry points are gated by
	// access.AssertIsStaker, so they can only be driven from the staker address.
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm   = testing.NewUserRealm(stakerAddr)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee500  = uint32(500)
	fee3000 = uint32(3000)

	barFoo500PoolPath  = "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
	barFoo3000PoolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
)

const (
	poolV1Path      = "gno.land/r/gnoswap/pool/v1"
	poolV2ValidPath = "gno.land/r/gnoswap/pool/v2_valid"
	routerV1Path    = "gno.land/r/gnoswap/router/v1"
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize pool + router with v1")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Create v1 data: pool + position + swap")
	createPoolV1(cur)
	mintPositionV1(cur)
	swapV1(cur)
	println()

	println("[SCENARIO] 3. Read v1-created data via getters")
	printPoolData(cur)
	println()

	println("[SCENARIO] 4. Upgrade pool implementation to v2_valid")
	upgradeToV2Valid(cur)
	println()

	println("[SCENARIO] 5. Mutate v1 data through v2_valid (taint-prone RMW)")
	mintPositionV2Valid(cur)
	swapV2Valid(cur)
	increaseObservationV2Valid(cur)
	println()

	println("[SCENARIO] 6. CreatePool through v2_valid (pools BPTree RMW)")
	createSecondPoolV2Valid(cur)
	println()

	println("[SCENARIO] 7. Burn + Collect + HandleWithdrawalFee through v2_valid")
	// position.DecreaseLiquidity is the legitimate caller of the position-role-gated
	// pool entry points Burn, Collect and HandleWithdrawalFee. It drives all three
	// in a single call against the v1-created position 1, RMWing the v1 ticks /
	// positions BPTrees and the protocol-fee accounting.
	decreaseLiquidityV2Valid(cur)
	println()

	println("[SCENARIO] 8. SetFeeProtocol + CollectProtocol through v2_valid")
	setFeeProtocolV2Valid(cur)
	swapV2Valid(cur) // generate protocol fees under the new fee-protocol setting
	collectProtocolV2Valid(cur)
	println()

	println("[SCENARIO] 9. Scalar fee setters through v2_valid")
	setPoolCreationFeeV2Valid(cur)
	setWithdrawalFeeV2Valid(cur)
	println()

	println("[SCENARIO] 10. Swap hook setters through v2_valid (staker role)")
	setSwapHooksV2Valid(cur)
	println()

	println("[SCENARIO] 11. Read final data via getters after v2_valid mutation")
	printPoolData(cur)
	println()
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)
	pool.UpgradeImpl(cross(cur), poolV1Path)
	router.UpgradeImpl(cross(cur), routerV1Path)
	ufmt.Printf("[EXPECTED] Pool implementation: %s\n", pool.GetImplementationPackagePath())
}

func createPoolV1(cur realm) {
	testing.SetRealm(adminRealm)
	pool.CreatePool(cross(cur), barPath, fooPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	ufmt.Printf("[EXPECTED] Created pool: %s\n", pool.GetPoolPath(barPath, fooPath, fee500))
}

func mintPositionV1(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)

	id, liq, _, _ := position.Mint(cross(cur), barPath, fooPath, fee500, -960, 960, "50000000", "50000000", "0", "0", time.Now().Unix()+3600, adminAddr, "")
	ufmt.Printf("[EXPECTED] v1 minted position id=%d liquidity=%s\n", id, liq)
}

func swapV1(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), routerAddr, math.MaxInt64)
	foo.Approve(cross(cur), routerAddr, math.MaxInt64)

	in, out := router.ExactInSwapRoute(cross(cur), fooPath, barPath, "1000000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1", int64(9999999999), "")
	ufmt.Printf("[EXPECTED] v1 swap in=%s out=%s\n", in, out)
}

func upgradeToV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	pool.UpgradeImpl(cross(cur), poolV2ValidPath)
	ufmt.Printf("[EXPECTED] Upgraded pool implementation: %s\n", pool.GetImplementationPackagePath())
}

// mintPositionV2Valid mints additional liquidity on the v1-created pool.
// This RMWs the pool's positions BPTree, ticks BPTree, tick bitmaps and slot0
// liquidity that were allocated by the v1 implementation realm.
func mintPositionV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)

	id, liq, _, _ := position.Mint(cross(cur), barPath, fooPath, fee500, -960, 960, "30000000", "30000000", "0", "0", time.Now().Unix()+3600, adminAddr, "")
	ufmt.Printf("[EXPECTED] v2_valid minted position id=%d liquidity=%s\n", id, liq)
}

// swapV2Valid swaps through the v1-created pool. This RMWs slot0 (sqrtPrice,
// tick), fee growth globals, protocol fees and tick bitmaps owned by the
// domain realm but originally written by v1.
func swapV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), routerAddr, math.MaxInt64)
	foo.Approve(cross(cur), routerAddr, math.MaxInt64)

	in, out := router.ExactInSwapRoute(cross(cur), fooPath, barPath, "1000000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1", int64(9999999999), "")
	ufmt.Printf("[EXPECTED] v2_valid swap in=%s out=%s\n", in, out)
}

// increaseObservationV2Valid grows the v1-created oracle observation array,
// another v1-allocated structure mutated through v2_valid.
func increaseObservationV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	pool.IncreaseObservationCardinalityNext(cross(cur), barPath, fooPath, fee500, 10)
	ufmt.Printf("[EXPECTED] v2_valid increased observation cardinality\n")
}

// createSecondPoolV2Valid creates a SECOND pool through v2_valid, proving the
// v1-allocated pools BPTree accepts an insert under the new implementation.
func createSecondPoolV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	pool.CreatePool(cross(cur), barPath, fooPath, fee3000, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	ufmt.Printf("[EXPECTED] v2_valid created second pool: %s (total pools=%d)\n",
		pool.GetPoolPath(barPath, fooPath, fee3000), pool.GetPoolCount())
}

// decreaseLiquidityV2Valid removes part of v1-created position 1 via
// position.DecreaseLiquidity. That higher-level call legitimately drives the
// position-role-gated pool entry points Burn (removes liquidity from the v1
// ticks/positions BPTrees), Collect (transfers owed tokens) and
// HandleWithdrawalFee (protocol-fee accounting), all against v1-created data.
func decreaseLiquidityV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	_, removedLiq, _, _, _, _, _ := position.DecreaseLiquidity(cross(cur), uint64(1), "100000000", "0", "0", time.Now().Unix()+3600)
	ufmt.Printf("[EXPECTED] v2_valid decreased position 1 (Burn+Collect+HandleWithdrawalFee) removedLiq=%s poolLiq=%s\n",
		removedLiq, pool.GetLiquidity(barFoo500PoolPath))
}

// setFeeProtocolV2Valid sets the protocol fee. SetFeeProtocol iterates the
// v1-created pools BPTree and RMWs every pool's slot0 fee-protocol field.
func setFeeProtocolV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetFeeProtocol(cross(cur), 6, 6)
	ufmt.Printf("[EXPECTED] v2_valid set fee protocol, slot0FeeProtocol=%d\n",
		pool.GetSlot0FeeProtocol(barFoo500PoolPath))
}

// collectProtocolV2Valid collects accrued protocol fees (admin/governance gated),
// RMWing the v1-created protocol-fee accounting for the pool.
func collectProtocolV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	before0, before1 := pool.GetProtocolFeesTokens(barFoo500PoolPath)
	amt0, amt1 := pool.CollectProtocol(cross(cur), barPath, fooPath, fee500, adminAddr, "1000000000", "1000000000")
	after0, after1 := pool.GetProtocolFeesTokens(barFoo500PoolPath)
	ufmt.Printf("[EXPECTED] v2_valid collected protocol fees collected0=%s collected1=%s feesBefore=(%d,%d) feesAfter=(%d,%d)\n",
		amt0, amt1, before0, before1, after0, after1)
}

// setPoolCreationFeeV2Valid writes the pool-creation-fee scalar through v2_valid.
func setPoolCreationFeeV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 12345)
	ufmt.Printf("[EXPECTED] v2_valid set pool creation fee=%d\n", pool.GetPoolCreationFee())
}

// setWithdrawalFeeV2Valid writes the withdrawal-fee scalar through v2_valid.
func setWithdrawalFeeV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetWithdrawalFee(cross(cur), 250)
	ufmt.Printf("[EXPECTED] v2_valid set withdrawal fee=%d\n", pool.GetWithdrawalFee())
}

// setSwapHooksV2Valid writes the three swap hook function slots through v2_valid.
// These entry points are gated by access.AssertIsStaker, so they run from the
// staker realm. They are set last (after all swaps) so the no-op hooks do not
// perturb earlier swap outputs. Setting them proves the func-valued store slots
// are RMW-safe under the upgraded implementation.
func setSwapHooksV2Valid(cur realm) {
	testing.SetRealm(stakerRealm)
	pool.SetSwapStartHook(cross(cur), func(cur realm, poolPath string, timestamp int64) {})
	pool.SetSwapEndHook(cross(cur), func(cur realm, poolPath string) error { return nil })
	pool.SetTickCrossHook(cross(cur), func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {})
	ufmt.Printf("[EXPECTED] v2_valid set swap start/end/tick-cross hooks\n")
}

func printPoolData(cur realm) {
	testing.SetRealm(adminRealm)
	p, _ := pool.GetPool(barPath, fooPath, fee500)
	ufmt.Printf("[EXPECTED] pool=%s tick=%d liquidity=%s positions=%d\n",
		p.PoolPath(), p.Slot0Tick(), p.Liquidity().ToString(), pool.GetPoolPositionCount(barFoo500PoolPath))
}

// Output:
// [SCENARIO] 1. Initialize pool + router with v1
// [EXPECTED] Pool implementation: gno.land/r/gnoswap/pool/v1
//
// [SCENARIO] 2. Create v1 data: pool + position + swap
// [EXPECTED] Created pool: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] v1 minted position id=1 liquidity=1066918731
// [EXPECTED] v1 swap in=1000000 out=-997067
//
// [SCENARIO] 3. Read v1-created data via getters
// [EXPECTED] pool=gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500 tick=18 liquidity=1066918731 positions=1
//
// [SCENARIO] 4. Upgrade pool implementation to v2_valid
// [EXPECTED] Upgraded pool implementation: gno.land/r/gnoswap/pool/v2_valid
//
// [SCENARIO] 5. Mutate v1 data through v2_valid (taint-prone RMW)
// [EXPECTED] v2_valid minted position id=2 liquidity=627605406
// [EXPECTED] v2_valid swap in=1000000 out=-995547
// [EXPECTED] v2_valid increased observation cardinality
//
// [SCENARIO] 6. CreatePool through v2_valid (pools BPTree RMW)
// [EXPECTED] v2_valid created second pool: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000 (total pools=2)
//
// [SCENARIO] 7. Burn + Collect + HandleWithdrawalFee through v2_valid
// [EXPECTED] v2_valid decreased position 1 (Burn+Collect+HandleWithdrawalFee) removedLiq=100000000 poolLiq=1594524137
//
// [SCENARIO] 8. SetFeeProtocol + CollectProtocol through v2_valid
// [EXPECTED] v2_valid set fee protocol, slot0FeeProtocol=102
// [EXPECTED] v2_valid swap in=1000000 out=-994338
// [EXPECTED] v2_valid collected protocol fees collected0=0 collected1=83 feesBefore=(0,83) feesAfter=(0,0)
//
// [SCENARIO] 9. Scalar fee setters through v2_valid
// [EXPECTED] v2_valid set pool creation fee=12345
// [EXPECTED] v2_valid set withdrawal fee=250
//
// [SCENARIO] 10. Swap hook setters through v2_valid (staker role)
// [EXPECTED] v2_valid set swap start/end/tick-cross hooks
//
// [SCENARIO] 11. Read final data via getters after v2_valid mutation
// [EXPECTED] pool=gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500 tick=43 liquidity=1594524137 positions=1
//
