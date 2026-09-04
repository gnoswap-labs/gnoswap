package router

import (
	"chain"
	"testing"

	"gno.land/p/gnoswap/gnsmath"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/obl"
)

func TestCollectRouteTokens(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		routeArr string
		want     []string
	}{
		{
			name:     "single hop",
			routeArr: "tokenA:tokenB:3000",
			want:     []string{"tokenA", "tokenB"},
		},
		{
			name:     "multi hop deduplicates shared tokens",
			routeArr: "tokenA:tokenB:3000*POOL*tokenB:tokenC:500",
			want:     []string{"tokenA", "tokenB", "tokenC"},
		},
		{
			name:     "multi route keeps first-appearance order",
			routeArr: "tokenA:tokenC:3000,tokenA:tokenB:500*POOL*tokenB:tokenC:3000",
			want:     []string{"tokenA", "tokenC", "tokenB"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			got := collectRouteTokens(tt.routeArr)

			uassert.Equal(t, len(got), len(tt.want))
			for i := range tt.want {
				uassert.Equal(t, got[i], tt.want[i])
			}
		})
	}
}

func TestRefundLeftovers(cur realm, t *testing.T) {
	router := mockRouter()
	recipient := testutils.TestAddress("refundRecipient1")

	// funds the router held before the snapshot must never be refunded
	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), routerAddr, 5000)

	snapshot := router.captureFundsSnapshot(singlePoolPath)

	// leftover accrued after the snapshot, i.e. during a swap
	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), routerAddr, 1234)

	routerBarBefore := bar.BalanceOf(routerAddr)

	func(cur realm) {
		testing.SetRealm(routerRealm)
		router.refundLeftovers(0, cur, snapshot, recipient)
	}(cross(cur))

	uassert.Equal(t, bar.BalanceOf(recipient), int64(1234))
	uassert.Equal(t, bar.BalanceOf(routerAddr), routerBarBefore-1234)
	// baz is on the route but accrued nothing, so nothing is sent
	uassert.Equal(t, baz.BalanceOf(recipient), int64(0))
}

func TestRefundLeftoversExcludesPendingProtocolFee(cur realm, t *testing.T) {
	router := mockRouter()
	recipient := testutils.TestAddress("refundRecipient2")

	snapshot := router.captureFundsSnapshot(singlePoolPath)

	// 1000 accrued during the swap, of which 400 was recorded as a pending
	// protocol fee (protocol fee realm halted mid-swap)
	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), routerAddr, 1000)
	router.addPendingProtocolFee(0, cur, barPath, 400)

	func(cur realm) {
		testing.SetRealm(routerRealm)
		router.refundLeftovers(0, cur, snapshot, recipient)
	}(cross(cur))

	uassert.Equal(t, bar.BalanceOf(recipient), int64(600))
}

func TestRefundLeftoversNoLeftover(cur realm, t *testing.T) {
	router := mockRouter()
	recipient := testutils.TestAddress("refundRecipient3")

	snapshot := router.captureFundsSnapshot(singlePoolPath)

	func(cur realm) {
		testing.SetRealm(routerRealm)
		router.refundLeftovers(0, cur, snapshot, recipient)
	}(cross(cur))

	uassert.Equal(t, bar.BalanceOf(recipient), int64(0))
	uassert.Equal(t, baz.BalanceOf(recipient), int64(0))
}

// TestExactInSwapRouteRefundsPartialFillLeftover drives a real multi-hop swap
// whose second hop only partially fills, and verifies the intermediate-token
// leftover is refunded to the swap caller in the same call while pre-existing
// router funds stay untouched.
//
// NOTE: in this test harness the caller/payer the router derives via
// rlm.Previous() resolves to the router v1 package address (the same reason
// other tests in this package pre-fund routerV1Addr), so the v1 address plays
// the swap-user role here.
func TestExactInSwapRouteRefundsPartialFillLeftover(cur realm, t *testing.T) {
	initRouterTest(cur, t)

	callerAddr := chain.PackageAddress(routerV1Path)

	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross(cur), 0)

	// fresh pool pairs unused by other tests, so shared test state (pool
	// prices, oracle observations) cannot interfere:
	// deep first-hop pool bar-obl@3000, thin second-hop pool baz-obl@500
	// holding only a narrow in-range position
	CreatePool(cur, t, barPath, oblPath, fee3000, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(), admin)
	CreatePool(cur, t, bazPath, oblPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(), admin)

	testing.SetRealm(adminRealm)
	TokenApprove(cur, t, barPath, admin, poolAddr, maxApprove)
	TokenApprove(cur, t, bazPath, admin, poolAddr, maxApprove)
	TokenApprove(cur, t, oblPath, admin, poolAddr, maxApprove)

	// advance time so the pool oracle accepts a new observation
	testing.SkipHeights(1)

	testing.SetRealm(adminRealm)
	pn.Mint(cross(cur), barPath, oblPath, fee3000, minTick, maxTick,
		"1000000", "1000000", "0", "0", max_timeout, admin, "")
	pn.Mint(cross(cur), bazPath, oblPath, fee500, int32(-10), int32(10),
		"10000", "10000", "0", "0", max_timeout, admin, "")

	// fund the swap caller with the input token and approve the router
	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), callerAddr, 5_000_000_000)

	testing.SetRealm(testing.NewCodeRealm(routerV1Path))
	bar.Approve(cross(cur), routerAddr, maxApprove)

	// pre-existing router funds must survive the refund untouched
	testing.SetRealm(adminRealm)
	obl.Transfer(cross(cur), routerAddr, 7777)

	routerOblBefore := obl.BalanceOf(routerAddr)
	callerOblBefore := obl.BalanceOf(callerAddr)
	callerBazBefore := baz.BalanceOf(callerAddr)

	testing.SkipHeights(100)

	routeArr := barPath + ":" + oblPath + ":3000*POOL*" + oblPath + ":" + bazPath + ":500"

	router := mockRouter()

	testing.SetRealm(testing.NewUserRealm(callerAddr))
	func(cur realm) {
		testing.SetRealm(routerRealm)
		router.ExactInSwapRoute(
			0, cur,
			barPath,
			bazPath,
			"200000",
			routeArr,
			"100",
			"1",
			max_timeout,
			"",
		)
	}(cross(cur))

	// the swap produced output
	uassert.True(t, baz.BalanceOf(callerAddr) > callerBazBefore)
	// the partially consumed intermediate token was refunded to the caller
	uassert.True(t, obl.BalanceOf(callerAddr) > callerOblBefore)
	// the router kept nothing from the swap and lost none of its prior funds
	uassert.Equal(t, obl.BalanceOf(routerAddr), routerOblBefore)
}
