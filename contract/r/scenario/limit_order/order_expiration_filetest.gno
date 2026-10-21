// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256/v1"
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
	devopsAddr   = access.MustGetAddress(prbac.ROLE_DEVOPS.String())
	fooPath      = "gno.land/r/onbloc/foo.FOO"
	barPath      = "gno.land/r/onbloc/bar.BAR"
)

func main(cur realm) {
	setupPoolAndLiquidity(cur)

	testing.SetRealm(aliceRealm)
	foo.Approve(cross(cur), lo.Address(), maxApprove)
	aliceFooBefore := foo.BalanceOf(aliceAddr)
	aliceBarBefore := bar.BalanceOf(aliceAddr)
	devopsBarBefore := bar.BalanceOf(devopsAddr)
	keeperBarBefore := bar.BalanceOf(keeperAddr)
	escrowBefore := foo.BalanceOf(lo.Address())
	poolPath := pool.GetPoolPath(barPath, fooPath, fee500)
	expiry := time.Now().Unix() + 600
	firstOrderID := lo.CreateOrder(
		cross(cur), poolPath, address(fooPath), address(barPath),
		1000, 900, 0, expiry,
	)
	secondOrderID := lo.CreateOrder(
		cross(cur), poolPath, address(fooPath), address(barPath),
		2000, 1800, 0, expiry,
	)
	uassert.Equal(t, uint64(1), firstOrderID)
	uassert.Equal(t, uint64(2), secondOrderID)
	uassert.Equal(t, aliceFooBefore-3000, foo.BalanceOf(aliceAddr))
	uassert.Equal(t, escrowBefore+3000, foo.BalanceOf(lo.Address()))

	testing.SetRealm(keeperRealm)
	actualInput, routerNetOutput := lo.ExecuteOrder(cross(cur), firstOrderID, 400)
	uassert.Equal(t, actualInput, "400")
	output := u256.MustFromDecimal(routerNetOutput).Uint64()
	fee := feeFor(output, 50)
	uassert.Equal(t, aliceBarBefore+int64(output-fee), bar.BalanceOf(aliceAddr))
	uassert.Equal(t, devopsBarBefore+int64(fee), bar.BalanceOf(devopsAddr))
	uassert.Equal(t, keeperBarBefore, bar.BalanceOf(keeperAddr))
	uassert.Equal(t, escrowBefore+2600, foo.BalanceOf(lo.Address()))

	view, exists := lo.GetOrder(firstOrderID)
	uassert.True(t, exists)
	uassert.Equal(t, view.Status, lo.OrderStatusActive)
	uassert.Equal(t, view.FeeBps, uint64(50))
	uassert.Equal(t, view.FeeRecipient, devopsAddr)
	uassert.Equal(t, view.FilledInput, uint64(400))
	uassert.Equal(t, view.RemainingInput, uint64(600))
	uassert.Equal(t, view.GrossOutput, output)
	uassert.Equal(t, view.ExecutionFee, fee)

	testing.SkipHeights(121)
	uassert.AbortsContains(t, cur, "[LIMIT_ORDER] order has expired", func() {
		lo.ExecuteOrder(cross(cur), firstOrderID, 100)
	})
	uassert.Equal(t, aliceFooBefore-3000, foo.BalanceOf(aliceAddr))
	uassert.Equal(t, aliceBarBefore+int64(output-fee), bar.BalanceOf(aliceAddr))
	uassert.Equal(t, devopsBarBefore+int64(fee), bar.BalanceOf(devopsAddr))
	uassert.Equal(t, keeperBarBefore, bar.BalanceOf(keeperAddr))
	uassert.Equal(t, escrowBefore+2600, foo.BalanceOf(lo.Address()))

	cleaned := lo.CleanupExpiredOrders(cross(cur), 1)
	uassert.Equal(t, cleaned, uint64(1))
	uassert.Equal(t, aliceFooBefore-2400, foo.BalanceOf(aliceAddr))
	uassert.Equal(t, escrowBefore+2000, foo.BalanceOf(lo.Address()))
	uassert.Equal(t, aliceBarBefore+int64(output-fee), bar.BalanceOf(aliceAddr))
	uassert.Equal(t, devopsBarBefore+int64(fee), bar.BalanceOf(devopsAddr))
	uassert.Equal(t, keeperBarBefore, bar.BalanceOf(keeperAddr))

	view, exists = lo.GetOrder(firstOrderID)
	uassert.True(t, exists)
	uassert.Equal(t, view.Status, lo.OrderStatusExpired)
	uassert.Equal(t, view.FilledInput, uint64(400))
	uassert.Equal(t, view.RefundedInput, uint64(600))
	uassert.Equal(t, view.RemainingInput, uint64(0))
	uassert.Equal(t, view.FeeBps, uint64(50))
	uassert.Equal(t, view.GrossOutput, output)
	uassert.Equal(t, view.ExecutionFee, fee)

	cleaned = lo.CleanupExpiredOrders(cross(cur), 10)
	uassert.Equal(t, cleaned, uint64(1))
	uassert.Equal(t, aliceFooBefore-400, foo.BalanceOf(aliceAddr))
	uassert.Equal(t, escrowBefore, foo.BalanceOf(lo.Address()))
	uassert.Equal(t, aliceBarBefore+int64(output-fee), bar.BalanceOf(aliceAddr))
	uassert.Equal(t, devopsBarBefore+int64(fee), bar.BalanceOf(devopsAddr))
	uassert.Equal(t, keeperBarBefore, bar.BalanceOf(keeperAddr))

	view, exists = lo.GetOrder(secondOrderID)
	uassert.True(t, exists)
	uassert.Equal(t, view.Status, lo.OrderStatusExpired)
	uassert.Equal(t, view.FilledInput, uint64(0))
	uassert.Equal(t, view.RefundedInput, uint64(2000))
	uassert.Equal(t, view.RemainingInput, uint64(0))
	uassert.Equal(t, uint64(0), lo.CleanupExpiredOrders(cross(cur), 10))
}

func feeFor(cumulativeOutput, feeBps uint64) uint64 {
	return cumulativeOutput * feeBps / 10000
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
		"1000000",
		"1000000",
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
