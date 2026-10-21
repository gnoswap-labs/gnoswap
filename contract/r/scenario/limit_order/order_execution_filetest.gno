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

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/gns"
	lo "gno.land/r/gnoswap/limit_order"
	pool "gno.land/r/gnoswap/pool"
	position "gno.land/r/gnoswap/position"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	fee500     uint32 = 500
	maxApprove int64  = 9223372036854775806
)

var t = &testing.T{}

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())
	aliceAddr    = testutils.TestAddress("alice")
	aliceRealm   = testing.NewUserRealm(aliceAddr)
	keeperAddr   = testutils.TestAddress("keeper")
	keeperRealm  = testing.NewUserRealm(keeperAddr)
	fooPath      = "gno.land/r/onbloc/foo.FOO"
	barPath      = "gno.land/r/onbloc/bar.BAR"
)

func main(cur realm) {
	setupPoolAndLiquidity(cur)

	testing.SetRealm(aliceRealm)
	foo.Approve(cross(cur), lo.Address(), maxApprove)
	aliceFooBefore := foo.BalanceOf(aliceAddr)
	aliceBarBefore := bar.BalanceOf(aliceAddr)
	escrowBefore := foo.BalanceOf(lo.Address())
	poolPath := pool.GetPoolPath(barPath, fooPath, fee500)
	orderID := lo.CreateOrder(
		cross(cur),
		poolPath,
		address(fooPath),
		address(barPath),
		1000,
		900,
		0,
		50,
		time.Now().Unix()+3600,
		aliceAddr,
	)
	uassert.Equal(t, uint64(1), orderID)
	uassert.Equal(t, aliceFooBefore-1000, foo.BalanceOf(aliceAddr))
	uassert.Equal(t, escrowBefore+1000, foo.BalanceOf(lo.Address()))

	testing.SetRealm(keeperRealm)
	keeperBarBefore := bar.BalanceOf(keeperAddr)
	lo.ExecuteOrder(cross(cur), orderID, keeperAddr)

	aliceReceived := bar.BalanceOf(aliceAddr) - aliceBarBefore
	keeperReceived := bar.BalanceOf(keeperAddr) - keeperBarBefore
	uassert.True(t, aliceReceived >= 900, "owner must receive the order minimum after keeper fee")
	uassert.Equal(t, (aliceReceived+keeperReceived)*50/10000, keeperReceived)
	uassert.Equal(t, escrowBefore, foo.BalanceOf(lo.Address()))
	uassert.Equal(t, aliceFooBefore-1000, foo.BalanceOf(aliceAddr))

	aliceBarAfterExecution := bar.BalanceOf(aliceAddr)
	keeperBarAfterExecution := bar.BalanceOf(keeperAddr)
	uassert.AbortsContains(t, cur, "[LIMIT_ORDER] order is not active", func() {
		lo.ExecuteOrder(cross(cur), orderID, keeperAddr)
	})
	uassert.Equal(t, aliceBarAfterExecution, bar.BalanceOf(aliceAddr))
	uassert.Equal(t, keeperBarAfterExecution, bar.BalanceOf(keeperAddr))
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
		-10000,
		10000,
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
