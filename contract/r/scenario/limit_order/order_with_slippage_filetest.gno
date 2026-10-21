// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/p/gnoswap/gnsmath/v1"
	prbac "gno.land/p/gnoswap/rbac/v1"

	_ "gno.land/r/gnoswap/common/v1"
	_ "gno.land/r/gnoswap/limit_order/v1"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac/v1"
	_ "gno.land/r/gnoswap/router/v1"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/gns"
	lo "gno.land/r/gnoswap/limit_order"
	pool "gno.land/r/gnoswap/pool"
	position "gno.land/r/gnoswap/position"
	router "gno.land/r/gnoswap/router"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	fee500     uint32 = 500
	maxApprove int64  = 9223372036854775806
	minUserOut int64  = 9405
)

var t = &testing.T{}

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())
	aliceAddr     = testutils.TestAddress("alice")
	aliceRealm    = testing.NewUserRealm(aliceAddr)
	bobAddr       = testutils.TestAddress("bob")
	bobRealm      = testing.NewUserRealm(bobAddr)
	keeperAddr    = testutils.TestAddress("keeper")
	keeperRealm   = testing.NewUserRealm(keeperAddr)
	fooPath       = "gno.land/r/onbloc/foo.FOO"
	barPath       = "gno.land/r/onbloc/bar.BAR"
)

func main(cur realm) {
	setupPoolAndLiquidity(cur)
	poolPath := pool.GetPoolPath(barPath, fooPath, fee500)

	testing.SetRealm(aliceRealm)
	foo.Approve(cross(cur), lo.Address(), maxApprove)
	aliceFooBefore := foo.BalanceOf(aliceAddr)
	aliceBarBefore := bar.BalanceOf(aliceAddr)
	slippageOrderID := lo.CreateOrder(
		cross(cur),
		poolPath,
		address(fooPath),
		address(barPath),
		10000,
		9500,
		100,
		50,
		time.Now().Unix()+86400,
		aliceAddr,
	)
	uassert.Equal(t, uint64(1), slippageOrderID)
	uassert.Equal(t, aliceFooBefore-10000, foo.BalanceOf(aliceAddr))

	tokenFaucet(cur, barPath, bobAddr)
	testing.SetRealm(bobRealm)
	bar.Approve(cross(cur), routerAddr, maxApprove)
	router.ExactInSingleSwapRoute(
		cross(cur),
		barPath,
		fooPath,
		"1000",
		barPath+":"+fooPath+":500",
		"1",
		"0",
		time.Now().Unix()+300,
		"",
	)

	testing.SetRealm(keeperRealm)
	keeperBarBefore := bar.BalanceOf(keeperAddr)
	lo.ExecuteOrder(cross(cur), slippageOrderID, keeperAddr)
	aliceReceived := bar.BalanceOf(aliceAddr) - aliceBarBefore
	keeperReceived := bar.BalanceOf(keeperAddr) - keeperBarBefore
	uassert.True(t, aliceReceived >= minUserOut)
	uassert.True(t, keeperReceived > 0)

	testing.SetRealm(aliceRealm)
	fooBeforeExactOrder := foo.BalanceOf(aliceAddr)
	barBeforeExactOrder := bar.BalanceOf(aliceAddr)
	escrowBeforeExactOrder := foo.BalanceOf(lo.Address())
	exactOrderID := lo.CreateOrder(
		cross(cur),
		poolPath,
		address(fooPath),
		address(barPath),
		10000,
		9500,
		0,
		50,
		time.Now().Unix()+86400,
		aliceAddr,
	)
	uassert.Equal(t, uint64(2), exactOrderID)

	tokenFaucet(cur, fooPath, bobAddr)
	testing.SetRealm(bobRealm)
	foo.Approve(cross(cur), routerAddr, maxApprove)
	router.ExactInSingleSwapRoute(
		cross(cur),
		fooPath,
		barPath,
		"5000000",
		fooPath+":"+barPath+":500",
		"1",
		"0",
		time.Now().Unix()+300,
		"",
	)

	testing.SetRealm(keeperRealm)
	uassert.AbortsContains(t, cur, "[LIMIT_ORDER] limit price not reached", func() {
		lo.ExecuteOrder(cross(cur), exactOrderID, keeperAddr)
	})
	uassert.Equal(t, fooBeforeExactOrder-10000, foo.BalanceOf(aliceAddr))
	uassert.Equal(t, barBeforeExactOrder, bar.BalanceOf(aliceAddr))
	uassert.Equal(t, escrowBeforeExactOrder+10000, foo.BalanceOf(lo.Address()))

	testing.SetRealm(aliceRealm)
	lo.CancelOrder(cross(cur), exactOrderID, aliceAddr)
	uassert.Equal(t, fooBeforeExactOrder, foo.BalanceOf(aliceAddr))
	uassert.Equal(t, escrowBeforeExactOrder, foo.BalanceOf(lo.Address()))
}

func setupPoolAndLiquidity(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, pool.GetPoolCreationFee())
	pool.CreatePool(cross(cur), barPath, fooPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	tokenFaucet(cur, fooPath, aliceAddr)
	tokenFaucet(cur, barPath, aliceAddr)

	testing.SetRealm(aliceRealm)
	foo.Approve(cross(cur), poolAddr, maxApprove)
	bar.Approve(cross(cur), poolAddr, maxApprove)
	position.Mint(
		cross(cur),
		barPath,
		fooPath,
		fee500,
		-50000,
		50000,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		"",
	)
}

func tokenFaucet(cur realm, tokenPath string, to address) {
	testing.SetRealm(adminRealm)
	const amount int64 = 5_000_000_000
	if tokenPath == fooPath {
		foo.Transfer(cross(cur), to, amount)
	} else if tokenPath == barPath {
		bar.Transfer(cross(cur), to, amount)
	}
}
