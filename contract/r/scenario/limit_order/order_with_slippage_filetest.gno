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
	devopsAddr    = access.MustGetAddress(prbac.ROLE_DEVOPS.String())
	fooPath       = "gno.land/r/onbloc/foo.FOO"
	barPath       = "gno.land/r/onbloc/bar.BAR"
)

func main(cur realm) {
	setupPoolAndLiquidity(cur)
	poolPath := pool.GetPoolPath(barPath, fooPath, fee500)

	testing.SetRealm(aliceRealm)
	foo.Approve(cross(cur), lo.Address(), maxApprove)
	bar.Approve(cross(cur), lo.Address(), maxApprove)
	aliceFooBefore := foo.BalanceOf(aliceAddr)
	aliceBarBefore := bar.BalanceOf(aliceAddr)
	devopsBarBefore := bar.BalanceOf(devopsAddr)
	keeperBarBefore := bar.BalanceOf(keeperAddr)
	fooEscrowBefore := foo.BalanceOf(lo.Address())
	slippageOrderID := lo.CreateOrder(
		cross(cur),
		poolPath,
		address(fooPath),
		address(barPath),
		10000,
		9500,
		100,
		time.Now().Unix()+86400,
	)
	uassert.Equal(t, uint64(1), slippageOrderID)
	uassert.Equal(t, aliceFooBefore-10000, foo.BalanceOf(aliceAddr))

	view, exists := lo.GetOrder(slippageOrderID)
	uassert.True(t, exists)
	uassert.Equal(t, view.FeeBps, uint64(50))
	uassert.Equal(t, view.FeeRecipient, devopsAddr)

	testing.SetRealm(keeperRealm)
	actualInput, routerNetOutput := lo.ExecuteOrder(cross(cur), slippageOrderID, 10000)
	uassert.Equal(t, actualInput, "10000")
	output := u256.MustFromDecimal(routerNetOutput).Uint64()
	fee := feeFor(output, 50)
	uassert.True(t, output-fee >= 9405, "owner must receive the 9,405 slippage-adjusted minimum after execution fee")
	uassert.Equal(t, aliceBarBefore+int64(output-fee), bar.BalanceOf(aliceAddr))
	uassert.Equal(t, devopsBarBefore+int64(fee), bar.BalanceOf(devopsAddr))
	uassert.Equal(t, keeperBarBefore, bar.BalanceOf(keeperAddr))
	uassert.Equal(t, aliceFooBefore-10000, foo.BalanceOf(aliceAddr))
	uassert.Equal(t, fooEscrowBefore, foo.BalanceOf(lo.Address()))

	view, exists = lo.GetOrder(slippageOrderID)
	uassert.True(t, exists)
	uassert.Equal(t, view.Status, lo.OrderStatusExecuted)
	uassert.Equal(t, view.FeeBps, uint64(50))
	uassert.Equal(t, view.FeeRecipient, devopsAddr)
	uassert.Equal(t, view.FilledInput, uint64(10000))
	uassert.Equal(t, view.GrossOutput, output)
	uassert.Equal(t, view.ExecutionFee, fee)

	testing.SetRealm(aliceRealm)
	aliceFooBeforeReverse := foo.BalanceOf(aliceAddr)
	aliceBarBeforeReverse := bar.BalanceOf(aliceAddr)
	devopsFooBeforeReverse := foo.BalanceOf(devopsAddr)
	keeperFooBeforeReverse := foo.BalanceOf(keeperAddr)
	barEscrowBeforeReverse := bar.BalanceOf(lo.Address())
	reverseOrderID := lo.CreateOrder(
		cross(cur),
		poolPath,
		address(barPath),
		address(fooPath),
		1000,
		900,
		100,
		time.Now().Unix()+86400,
	)
	uassert.Equal(t, uint64(2), reverseOrderID)
	uassert.Equal(t, aliceBarBeforeReverse-1000, bar.BalanceOf(aliceAddr))
	testing.SetRealm(keeperRealm)
	reverseInput, reverseRouterOutput := lo.ExecuteOrder(cross(cur), reverseOrderID, 1000)
	uassert.Equal(t, reverseInput, "1000")
	reverseOutput := u256.MustFromDecimal(reverseRouterOutput).Uint64()
	reverseFee := feeFor(reverseOutput, 50)
	uassert.True(t, reverseOutput-reverseFee >= 891, "reverse-direction owner output must meet the 891 slippage-adjusted minimum")
	uassert.Equal(t, aliceFooBeforeReverse+int64(reverseOutput-reverseFee), foo.BalanceOf(aliceAddr))
	uassert.Equal(t, devopsFooBeforeReverse+int64(reverseFee), foo.BalanceOf(devopsAddr))
	uassert.Equal(t, keeperFooBeforeReverse, foo.BalanceOf(keeperAddr))
	uassert.Equal(t, barEscrowBeforeReverse, bar.BalanceOf(lo.Address()))

	view, exists = lo.GetOrder(reverseOrderID)
	uassert.True(t, exists)
	uassert.Equal(t, view.Status, lo.OrderStatusExecuted)
	uassert.Equal(t, view.FeeBps, uint64(50))
	uassert.Equal(t, view.FeeRecipient, devopsAddr)
	uassert.Equal(t, view.FilledInput, uint64(1000))
	uassert.Equal(t, view.GrossOutput, reverseOutput)
	uassert.Equal(t, view.ExecutionFee, reverseFee)

	testing.SetRealm(aliceRealm)
	fooBeforeExactOrder := foo.BalanceOf(aliceAddr)
	barBeforeExactOrder := bar.BalanceOf(aliceAddr)
	escrowBeforeExactOrder := foo.BalanceOf(lo.Address())
	devopsBarBeforeExactOrder := bar.BalanceOf(devopsAddr)
	keeperBarBeforeExactOrder := bar.BalanceOf(keeperAddr)
	exactOrderID := lo.CreateOrder(
		cross(cur),
		poolPath,
		address(fooPath),
		address(barPath),
		10000,
		9500,
		0,
		time.Now().Unix()+86400,
	)
	uassert.Equal(t, uint64(3), exactOrderID)
	uassert.Equal(t, fooBeforeExactOrder-10000, foo.BalanceOf(aliceAddr))

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
	uassert.AbortsContains(t, cur, "[GNOSWAP-ROUTER-001] slippage check failed", func() {
		lo.ExecuteOrder(cross(cur), exactOrderID, 10000)
	})
	uassert.Equal(t, fooBeforeExactOrder-10000, foo.BalanceOf(aliceAddr))
	uassert.Equal(t, barBeforeExactOrder, bar.BalanceOf(aliceAddr))
	uassert.Equal(t, escrowBeforeExactOrder+10000, foo.BalanceOf(lo.Address()))
	uassert.Equal(t, devopsBarBeforeExactOrder, bar.BalanceOf(devopsAddr))
	uassert.Equal(t, keeperBarBeforeExactOrder, bar.BalanceOf(keeperAddr))
	view, exists = lo.GetOrder(exactOrderID)
	uassert.True(t, exists)
	uassert.Equal(t, view.Status, lo.OrderStatusActive)
	uassert.Equal(t, view.FeeBps, uint64(50))
	uassert.Equal(t, view.FilledInput, uint64(0))
	uassert.Equal(t, view.RemainingInput, uint64(10000))
	uassert.Equal(t, view.GrossOutput, uint64(0))
	uassert.Equal(t, view.ExecutionFee, uint64(0))
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
