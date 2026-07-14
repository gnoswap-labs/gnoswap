// PKGPATH: gno.land/r/gnoswap/v1/main

// Router contract upgrade to v2_valid scenario test.
//
// v2_valid is a symlinked copy of the v1 router sources published under a
// v2_valid module path. This test targets the interrealm-v2 readonly-taint
// concern for the router's own persistent state: the swap fee scalar and the
// pendingProtocolFees map.
//
// The v1 implementation realm sets a swap fee and performs a swap, which RMWs
// the pendingProtocolFees map and downstream pool/position data. The active
// implementation is then switched to v2_valid, and the SAME v1-created swap
// fee scalar is read (GetSwapFee) and mutated (SetSwapFee) through v2_valid.
//
// Because the router's storage is owned by the domain (proxy) realm, reading
// and mutating v1-created data through v2_valid must NOT trigger a
// readonly-taint panic. A PASS proves the migration path is taint-safe.
//
// All state-mutating router entry points are exercised through v2_valid AFTER
// the upgrade: the four swap-route variants (ExactIn / ExactOut x Swap /
// SingleSwap) and SetSwapFee. The swap variants RMW the v1-created
// pendingProtocolFees map (router protocol-fee accrual) plus downstream pool
// state; SetSwapFee RMWs the v1-created swap-fee scalar. None may trigger a
// readonly-taint panic over the v1-allocated persistent state.
//
// The swap path now works post-upgrade: assertIsRouterImplementation resolves the expected
// caller from a package-level var initialized in init() to the active
// implementation's address (router/v1/consts.gno), so the SwapCallback
// re-entering from the active v2_valid implementation passes the caller check.
//
// DrySwapRoute is intentionally not exercised: it has no realm parameter and
// resolves the payer via unsafe.PreviousRealm(), which has no frame at the
// filetest top level, so calling it from main would panic for an unrelated
// reason. Reads are covered via getters (GetSwapFee) and swap return values.
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
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/router/v2_valid"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee500  = uint32(500)

	// single-pool route string (input:output:fee) reused by all swap variants
	fooBar500Route = "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"
)

const (
	routerV1Path      = "gno.land/r/gnoswap/router/v1"
	routerV2ValidPath = "gno.land/r/gnoswap/router/v2_valid"
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize pool + router with v1")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Create v1 data: pool + position")
	createPoolV1(cur)
	mintPositionV1(cur)
	println()

	println("[SCENARIO] 3. v1: set swap fee and perform swap (RMW pending protocol fees)")
	setSwapFeeV1(cur)
	swapV1(cur)
	println()

	println("[SCENARIO] 4. Read v1-created router data via getters")
	printRouterData(cur)
	println()

	println("[SCENARIO] 5. Upgrade router implementation to v2_valid")
	upgradeToV2Valid(cur)
	println()

	println("[SCENARIO] 6. Read v1 data through v2_valid (GetSwapFee over v1 scalar)")
	printRouterData(cur)
	println()

	println("[SCENARIO] 7. ExactInSwapRoute through v2_valid (RMW pendingProtocolFees + pool)")
	exactInSwapRouteV2Valid(cur)
	println()

	println("[SCENARIO] 8. ExactInSingleSwapRoute through v2_valid")
	exactInSingleSwapRouteV2Valid(cur)
	println()

	println("[SCENARIO] 9. ExactOutSwapRoute through v2_valid")
	exactOutSwapRouteV2Valid(cur)
	println()

	println("[SCENARIO] 10. ExactOutSingleSwapRoute through v2_valid")
	exactOutSingleSwapRouteV2Valid(cur)
	println()

	println("[SCENARIO] 11. Mutate v1 data through v2_valid (SetSwapFee scalar RMW)")
	setSwapFeeV2Valid(cur)
	println()

	println("[SCENARIO] 12. Read final router data after v2_valid mutation")
	printRouterData(cur)
	println()
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)
	router.UpgradeImpl(cross(cur), routerV1Path)
	ufmt.Printf("[EXPECTED] Router implementation: %s\n", router.GetImplementationPackagePath())
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

	// Wider, deeper position so all post-upgrade swap variants have ample
	// liquidity and produce deterministic outputs.
	id2, liq2, _, _ := position.Mint(cross(cur), barPath, fooPath, fee500, -6000, 6000, "200000000", "200000000", "0", "0", time.Now().Unix()+3600, adminAddr, "")
	ufmt.Printf("[EXPECTED] v1 minted wide position id=%d liquidity=%s\n", id2, liq2)
}

func setSwapFeeV1(cur realm) {
	testing.SetRealm(adminRealm)
	router.SetSwapFee(cross(cur), 20)
	ufmt.Printf("[EXPECTED] v1 swap fee set to: %d\n", router.GetSwapFee())
}

// swapV1 swaps through the v1-created pool. The router accrues pending protocol
// fees on the swap output token, RMWing the pendingProtocolFees map allocated
// by the v1 implementation realm.
func swapV1(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), routerAddr, math.MaxInt64)
	foo.Approve(cross(cur), routerAddr, math.MaxInt64)

	in, out := router.ExactInSwapRoute(cross(cur), fooPath, barPath, "1000000", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1", int64(9999999999), "")
	ufmt.Printf("[EXPECTED] v1 swap in=%s out=%s\n", in, out)
}

func printRouterData(cur realm) {
	testing.SetRealm(adminRealm)
	ufmt.Printf("[EXPECTED] router impl=%s swapFee=%d\n", router.GetImplementationPackagePath(), router.GetSwapFee())
}

func upgradeToV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	router.UpgradeImpl(cross(cur), routerV2ValidPath)
	ufmt.Printf("[EXPECTED] Upgraded router implementation: %s\n", router.GetImplementationPackagePath())
}

// exactInSwapRouteV2Valid drives a multi-hop (single-pool) exact-in swap through
// the active v2_valid implementation. The SwapCallback re-enters the router from
// the v2_valid realm and now passes assertIsRouterImplementation, so the swap completes and
// RMWs the v1-created pendingProtocolFees map plus downstream pool data. Taint
// over the v1-allocated map would panic here.
func exactInSwapRouteV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), routerAddr, math.MaxInt64)
	foo.Approve(cross(cur), routerAddr, math.MaxInt64)

	in, out := router.ExactInSwapRoute(cross(cur), fooPath, barPath, "1000000", fooBar500Route, "100", "1", int64(9999999999), "")
	ufmt.Printf("[EXPECTED] v2_valid ExactInSwapRoute in=%s out=%s\n", in, out)
}

// exactInSingleSwapRouteV2Valid drives a single-hop exact-in swap through
// v2_valid (sqrtPriceLimitX96="0" = no price limit).
func exactInSingleSwapRouteV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), routerAddr, math.MaxInt64)
	foo.Approve(cross(cur), routerAddr, math.MaxInt64)

	in, out := router.ExactInSingleSwapRoute(cross(cur), fooPath, barPath, "1000000", fooBar500Route, "1", "0", int64(9999999999), "")
	ufmt.Printf("[EXPECTED] v2_valid ExactInSingleSwapRoute in=%s out=%s\n", in, out)
}

// exactOutSwapRouteV2Valid drives a multi-hop (single-pool) exact-out swap
// through v2_valid: amountOut is exact, amountInMax caps the input.
func exactOutSwapRouteV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), routerAddr, math.MaxInt64)
	foo.Approve(cross(cur), routerAddr, math.MaxInt64)

	in, out := router.ExactOutSwapRoute(cross(cur), fooPath, barPath, "1000000", fooBar500Route, "100", "2000000", int64(9999999999), "")
	ufmt.Printf("[EXPECTED] v2_valid ExactOutSwapRoute in=%s out=%s\n", in, out)
}

// exactOutSingleSwapRouteV2Valid drives a single-hop exact-out swap through
// v2_valid (sqrtPriceLimitX96="0" = no price limit).
func exactOutSingleSwapRouteV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), routerAddr, math.MaxInt64)
	foo.Approve(cross(cur), routerAddr, math.MaxInt64)

	in, out := router.ExactOutSingleSwapRoute(cross(cur), fooPath, barPath, "1000000", fooBar500Route, "2000000", "0", int64(9999999999), "")
	ufmt.Printf("[EXPECTED] v2_valid ExactOutSingleSwapRoute in=%s out=%s\n", in, out)
}

// setSwapFeeV2Valid mutates the v1-created swap fee scalar through v2_valid.
// Taint over the v1-allocated scalar would panic here.
func setSwapFeeV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	router.SetSwapFee(cross(cur), 35)
	ufmt.Printf("[EXPECTED] v2_valid swap fee set to: %d\n", router.GetSwapFee())
}

// Output:
// [SCENARIO] 1. Initialize pool + router with v1
// [EXPECTED] Router implementation: gno.land/r/gnoswap/router/v1
//
// [SCENARIO] 2. Create v1 data: pool + position
// [EXPECTED] Created pool: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] v1 minted position id=1 liquidity=1066918731
// [EXPECTED] v1 minted wide position id=2 liquidity=771692266
//
// [SCENARIO] 3. v1: set swap fee and perform swap (RMW pending protocol fees)
// [EXPECTED] v1 swap fee set to: 20
// [EXPECTED] v1 swap in=1000000 out=-996959
//
// [SCENARIO] 4. Read v1-created router data via getters
// [EXPECTED] router impl=gno.land/r/gnoswap/router/v1 swapFee=20
//
// [SCENARIO] 5. Upgrade router implementation to v2_valid
// [EXPECTED] Upgraded router implementation: gno.land/r/gnoswap/router/v2_valid
//
// [SCENARIO] 6. Read v1 data through v2_valid (GetSwapFee over v1 scalar)
// [EXPECTED] router impl=gno.land/r/gnoswap/router/v2_valid swapFee=20
//
// [SCENARIO] 7. ExactInSwapRoute through v2_valid (RMW pendingProtocolFees + pool)
// [EXPECTED] v2_valid ExactInSwapRoute in=1000000 out=-995877
//
// [SCENARIO] 8. ExactInSingleSwapRoute through v2_valid
// [EXPECTED] v2_valid ExactInSingleSwapRoute in=1000000 out=-994795
//
// [SCENARIO] 9. ExactOutSwapRoute through v2_valid
// [EXPECTED] v2_valid ExactOutSwapRoute in=1006328 out=-1000000
//
// [SCENARIO] 10. ExactOutSingleSwapRoute through v2_valid
// [EXPECTED] v2_valid ExactOutSingleSwapRoute in=1007428 out=-1000000
//
// [SCENARIO] 11. Mutate v1 data through v2_valid (SetSwapFee scalar RMW)
// [EXPECTED] v2_valid swap fee set to: 35
//
// [SCENARIO] 12. Read final router data after v2_valid mutation
// [EXPECTED] router impl=gno.land/r/gnoswap/router/v2_valid swapFee=35
//
