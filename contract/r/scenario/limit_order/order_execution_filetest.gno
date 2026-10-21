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
	orderID := lo.CreateOrder(
		cross(cur),
		poolPath,
		address(fooPath),
		address(barPath),
		1000,
		900,
		0,
		time.Now().Unix()+3600,
	)
	uassert.Equal(t, uint64(1), orderID)
	uassert.Equal(t, aliceFooBefore-1000, foo.BalanceOf(aliceAddr))
	uassert.Equal(t, escrowBefore+1000, foo.BalanceOf(lo.Address()))

	view, exists := lo.GetOrder(orderID)
	uassert.True(t, exists)
	uassert.Equal(t, view.FeeBps, uint64(50))
	uassert.Equal(t, view.FeeRecipient, devopsAddr)

	testing.SetRealm(keeperRealm)
	uassert.AbortsContains(t, cur, "[LIMIT_ORDER] invalid fill amount", func() {
		lo.ExecuteOrder(cross(cur), orderID, 0)
	})
	uassert.AbortsContains(t, cur, "[LIMIT_ORDER] invalid fill amount", func() {
		lo.ExecuteOrder(cross(cur), orderID, 1001)
	})
	uassert.Equal(t, aliceFooBefore-1000, foo.BalanceOf(aliceAddr))
	uassert.Equal(t, aliceBarBefore, bar.BalanceOf(aliceAddr))
	uassert.Equal(t, devopsBarBefore, bar.BalanceOf(devopsAddr))
	uassert.Equal(t, keeperBarBefore, bar.BalanceOf(keeperAddr))
	uassert.Equal(t, escrowBefore+1000, foo.BalanceOf(lo.Address()))

	actualInput1, routerNetOutput1 := lo.ExecuteOrder(cross(cur), orderID, 500)
	uassert.Equal(t, actualInput1, "500")
	output1 := u256.MustFromDecimal(routerNetOutput1).Uint64()
	fee1 := feeFor(output1, 50)
	uassert.Equal(t, aliceBarBefore+int64(output1-fee1), bar.BalanceOf(aliceAddr))
	uassert.Equal(t, devopsBarBefore+int64(fee1), bar.BalanceOf(devopsAddr))
	uassert.Equal(t, keeperBarBefore, bar.BalanceOf(keeperAddr))
	uassert.Equal(t, aliceFooBefore-1000, foo.BalanceOf(aliceAddr))
	uassert.Equal(t, escrowBefore+500, foo.BalanceOf(lo.Address()))

	view, exists = lo.GetOrder(orderID)
	uassert.True(t, exists)
	uassert.Equal(t, view.Status, lo.OrderStatusActive)
	uassert.Equal(t, view.FeeBps, uint64(50))
	uassert.Equal(t, view.FeeRecipient, devopsAddr)
	uassert.Equal(t, view.FilledInput, uint64(500))
	uassert.Equal(t, view.RemainingInput, uint64(500))
	uassert.Equal(t, view.GrossOutput, output1)
	uassert.Equal(t, view.ExecutionFee, fee1)

	actualInput2, routerNetOutput2 := lo.ExecuteOrder(cross(cur), orderID, 500)
	uassert.Equal(t, actualInput2, "500")
	output2 := u256.MustFromDecimal(routerNetOutput2).Uint64()
	cumulativeOutput := output1 + output2
	cumulativeFee := feeFor(cumulativeOutput, 50)
	uassert.Equal(t, aliceBarBefore+int64(cumulativeOutput-cumulativeFee), bar.BalanceOf(aliceAddr))
	uassert.Equal(t, devopsBarBefore+int64(cumulativeFee), bar.BalanceOf(devopsAddr))
	uassert.Equal(t, keeperBarBefore, bar.BalanceOf(keeperAddr))
	uassert.Equal(t, foo.BalanceOf(lo.Address()), escrowBefore)
	uassert.Equal(t, aliceFooBefore-1000, foo.BalanceOf(aliceAddr))

	view, exists = lo.GetOrder(orderID)
	uassert.True(t, exists)
	uassert.Equal(t, view.Status, lo.OrderStatusExecuted)
	uassert.Equal(t, view.FeeBps, uint64(50))
	uassert.Equal(t, view.FeeRecipient, devopsAddr)
	uassert.Equal(t, view.FilledInput, uint64(1000))
	uassert.Equal(t, view.RemainingInput, uint64(0))
	uassert.Equal(t, view.GrossOutput, cumulativeOutput)
	uassert.Equal(t, view.ExecutionFee, cumulativeFee)

	orders, nextCursor := lo.GetOrdersByOwner(aliceAddr, 0, 10)
	uassert.Equal(t, len(orders), 1)
	uassert.Equal(t, nextCursor, uint64(0))
	uassert.Equal(t, orders[0].ID, orderID)
	uassert.Equal(t, orders[0].Status, lo.OrderStatusExecuted)
	uassert.Equal(t, orders[0].FeeBps, uint64(50))
	uassert.Equal(t, orders[0].GrossOutput, cumulativeOutput)
	uassert.Equal(t, orders[0].ExecutionFee, cumulativeFee)

	ownerBarAfterExecution := bar.BalanceOf(aliceAddr)
	devopsBarAfterExecution := bar.BalanceOf(devopsAddr)
	keeperBarAfterExecution := bar.BalanceOf(keeperAddr)
	uassert.AbortsContains(t, cur, "[LIMIT_ORDER] order is not active", func() {
		lo.ExecuteOrder(cross(cur), orderID, 1)
	})
	uassert.Equal(t, bar.BalanceOf(aliceAddr), ownerBarAfterExecution)
	uassert.Equal(t, bar.BalanceOf(devopsAddr), devopsBarAfterExecution)
	uassert.Equal(t, bar.BalanceOf(keeperAddr), keeperBarAfterExecution)
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
