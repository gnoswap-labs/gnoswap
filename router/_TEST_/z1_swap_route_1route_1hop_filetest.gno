package main

import (
	"std"
	"testing"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/gns"
	"gno.land/r/demo/obl"
	"gno.land/r/demo/qux"
	"gno.land/r/demo/wugnot"

	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/gnoswap/common"
	"gno.land/r/demo/gnoswap/consts"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"
	rr "gno.land/r/demo/router"
)

var (
	gsa std.Address = consts.GNOSWAP_ADMIN

	fooPath string = "gno.land/r/demo/foo"
	barPath string = "gno.land/r/demo/bar"
	bazPath string = "gno.land/r/demo/baz"
	quxPath string = "gno.land/r/demo/qux"

	oblPath string = "gno.land/r/demo/obl"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	maxTimeout int64 = 9999999999

	maxApprove uint64 = 18446744073709551615

	// TESTING
	t *testing.T
)

type FooToken struct{}

func (FooToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return foo.Transfer
}
func (FooToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return foo.TransferFrom
}
func (FooToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return foo.BalanceOf
}
func (FooToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return foo.Approve
}

type BarToken struct{}

func (BarToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return bar.Transfer
}
func (BarToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return bar.TransferFrom
}
func (BarToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return bar.BalanceOf
}
func (BarToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return bar.Approve
}

type BazToken struct{}

func (BazToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return baz.Transfer
}
func (BazToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return baz.TransferFrom
}
func (BazToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return baz.BalanceOf
}
func (BazToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return baz.Approve
}

type QuxToken struct{}

func (QuxToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return qux.Transfer
}
func (QuxToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return qux.TransferFrom
}
func (QuxToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return qux.BalanceOf
}
func (QuxToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return qux.Approve
}

type WugnotToken struct{}

func (WugnotToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return wugnot.Transfer
}
func (WugnotToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return wugnot.TransferFrom
}
func (WugnotToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return wugnot.BalanceOf
}
func (WugnotToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return wugnot.Approve
}

type OBLToken struct{}

func (OBLToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return obl.Transfer
}
func (OBLToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return obl.TransferFrom
}
func (OBLToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return obl.BalanceOf
}
func (OBLToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return obl.Approve
}

type GNSToken struct{}

func (GNSToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return gns.Transfer
}

func (GNSToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return gns.TransferFrom
}

func (GNSToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return gns.BalanceOf
}

func (GNSToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return gns.Approve
}

/* HELPER FUNCTIONS */
func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func ugnotBalanceOf(addr std.Address) uint64 {
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)

	coins := testBanker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(coins.AmountOf("ugnot"))
}

func init() {
	// TOKEN REGISTER
	std.TestSetPrevAddr(gsa)
	pl.RegisterGRC20Interface("gno.land/r/demo/foo", FooToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/bar", BarToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/baz", BazToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/qux", QuxToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/obl", OBLToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/gns", GNSToken{})

	rr.RegisterGRC20Interface("gno.land/r/demo/foo", FooToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/bar", BarToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/baz", BazToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/qux", QuxToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/obl", OBLToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/gns", GNSToken{})
}

/* START TEST */
func main() {
	createPool()
	mint()
	drySwapBarBazExactIn()
	swapBarBazExactIn()
	drySwapBarBazExactOut()
	swapBarBazExactOut()
	drySwapBazBarExactIn()
	swapBazBarExactIn()
	drySwapBazBarExactOut()
	swapBazBarExactOut()
}

func createPool() {
	std.TestSetPrevAddr(gsa)

	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE)
	std.TestSkipHeights(1)

	// 1 HOPS
	pl.CreatePool(barPath, bazPath, fee500, common.TickMathGetSqrtRatioAtTick(10_000).ToString())
	// tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
}

func mint() {
	std.TestSetPrevAddr(gsa)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	std.TestSetPrevRealm(consts.STAKER_PATH)
	_, _, amount0, amount1 := pn.Mint(barPath, bazPath, fee500, int32(9000), int32(11000), "100000", "100000", "0", "0", maxTimeout, gsa.String())
	if amount0 != "36790" {
		"router_z2_mint() || amount0 should be 36790"
	}
	if amount1 != "100000" {
		"router_z2_mint() || amount1 should be 100000"
	}
}

func drySwapBarBazExactIn() {
	std.TestSetPrevAddr(gsa)

	dryResult := rr.DrySwapRoute(
		barPath,    // inputToken
		bazPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500", // strRouteArr
		"100", // quoteArr
	)
	if dryResult != "2711" {
		panic("router_z2_drySwapBarBazExactIn() || dryResult should be 2711")
	}
}

func swapBarBazExactIn() {
	std.TestSetPrevAddr(gsa)

	bar.Approve(a2u(consts.POOL_ADDR), uint64(1000))
	baz.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX) // ITS FOR 0.15% fee

	amountIn, amountOut := rr.SwapRoute(
		barPath,    // inputToken
		bazPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500", // strRouteArr
		"100",  // quoteArr
		"2700", // tokenAmountLimit
	)
	if amountIn != "1000" {
		"router_z2_swapBarBazExactIn() || amountIn should be 1000"
	}
	if amountOut != "-2707" {
		"router_z2_swapBarBazExactIn() || amountOut should be -2707"
	}
}

func drySwapBarBazExactOut() {
	std.TestSetPrevAddr(gsa)

	dryResult := rr.DrySwapRoute(
		barPath,     // inputToken
		bazPath,     // outputToken
		"1000",      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500", // strRouteArr
		"100", // quoteArr
	)
	if dryResult != "371" {
		panic("router_z2_drySwapBarBazExactOut() || dryResult should be 371")
	}
}

func swapBarBazExactOut() {
	std.TestSetPrevAddr(gsa)

	bar.Approve(a2u(consts.POOL_ADDR), uint64(1000))
	baz.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX) // ITS FOR 0.15% fee

	amountIn, amountOut := rr.SwapRoute(
		barPath,     // inputToken
		bazPath,     // outputToken
		"1000",      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500", // strRouteArr
		"100", // quoteArr
		"371", // tokenAmountLimit
	)
	if amountIn != "371" {
		"router_z2_swapBarBazExactOut() || amountIn should be 371"
	}
	if amountOut != "-1000" {
		"router_z2_swapBarBazExactOut() || amountOut should be -1000"
	}
}

func drySwapBazBarExactIn() {
	std.TestSetPrevAddr(gsa)

	dryResult := rr.DrySwapRoute(
		bazPath,    // inputToken
		barPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"100", // quoteArr
	)
	if dryResult != "368" {
		panic("router_z2_drySwapBazBarExactIn() || dryResult should be 368")
	}
}

func swapBazBarExactIn() {
	std.TestSetPrevAddr(gsa)

	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	bar.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX) // ITS FOR 0.15% fee

	amountIn, amountOut := rr.SwapRoute(
		bazPath,    // inputToken
		barPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"100", // quoteArr
		"360", // tokenAmountLimit
	)
	if amountIn != "1000" {
		"router_z2_swapBarBazExactOut() || amountIn should be 1000"
	}
	if amountOut != "-368" {
		"router_z2_swapBarBazExactOut() || amountOut should be -368"
	}
}

func drySwapBazBarExactOut() {
	std.TestSetPrevAddr(gsa)

	dryResult := rr.DrySwapRoute(
		bazPath,     // inputToken
		barPath,     // outputToken
		"3000",      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"100", // quoteArr
	)
	if dryResult != "8171" {
		panic("router_z2_drySwapBazBarExactOut() || dryResult should be 8171")
	}
}

func swapBazBarExactOut() {
	std.TestSetPrevAddr(gsa)
	bar.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX)

	amountIn, amountOut := rr.SwapRoute(
		bazPath,     // inputToken
		barPath,     // outputToken
		"3000",      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"100",  // quoteArr
		"8200", // tokenAmountLimit
	)
	if amountIn != "8171" {
		"router_z2_swapBazBarExactOut() || amountIn should be 8171"
	}
	if amountOut != "-2996" {
		panic(amountOut)
		"router_z2_swapBazBarExactOut() || amountOut should be -2996"
	}
}
