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
	mintBarBaz()
	mintBazFoo()
	mintFooQux()

	drySwapBarBazExactIn()
	swapBarBazExactIn()

	drySwapBazBarExactIn()
	swapBazBarExactIn()

	drySwapBarBazExactOut()
	swapBarBazExactOut()

	drySwapBarQuxExactIn()
	swapBarQuxExactIn()

	drySwapQuxBarExactOut()
	swapQuxBarExactOut()

}

func createPool() {
	std.TestSetPrevAddr(gsa)

	// tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875

	// 1 BAR ≈ 2.7 BAZ
	// 1 BAR ≈ 7.29 FOO
	// 1 BAR ≈ 19.683 QUX

	// 1 BAZ = 0.37 BAR
	// 1 BAZ = 2.7 FOO
	// 1 BAZ = 7.29 QUX

	// 1 QUX = 0.05 BAR
	// 1 QUX = 0.13 BAZ
	// 1 QUX = 0.37 FOO
	pl.CreatePool(barPath, bazPath, fee100, common.TickMathGetSqrtRatioAtTick(10_000).ToString())
	pl.CreatePool(bazPath, fooPath, fee100, common.TickMathGetSqrtRatioAtTick(10_000).ToString())
	pl.CreatePool(fooPath, quxPath, fee100, common.TickMathGetSqrtRatioAtTick(10_000).ToString())

}

func mintBarBaz() {
	std.TestSetPrevAddr(gsa)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	std.TestSetPrevRealm(consts.STAKER_PATH)
	_, _, amount0, amount1 := pn.Mint(barPath, bazPath, fee100, int32(9000), int32(11000), "100000000", "100000000", "0", "0", maxTimeout, gsa.String())
	if amount0 != "36789784" {
		panic("router_z6_mintBarBaz() || amount0 should be 36789784")
	}
	if amount1 != "100000000" {
		panic("router_z6_mintBarBaz() || amount1 should be 100000000")
	}
}

func mintBazFoo() {
	std.TestSetPrevAddr(gsa)
	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	std.TestSetPrevRealm(consts.STAKER_PATH)
	_, _, amount0, amount1 := pn.Mint(bazPath, fooPath, fee100, int32(9000), int32(11000), "100000000", "100000000", "0", "0", maxTimeout, gsa.String())
	if amount0 != "36789784" {
		panic("router_z6_mintBazFoo() || amount0 should be 36789784")
	}
	if amount1 != "100000000" {
		panic("router_z6_mintBazFoo() || amount1 should be 100000000")
	}
}

func mintFooQux() {
	std.TestSetPrevAddr(gsa)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	std.TestSetPrevRealm(consts.STAKER_PATH)
	_, _, amount0, amount1 := pn.Mint(fooPath, quxPath, fee100, int32(9000), int32(11000), "100000000", "100000000", "0", "0", maxTimeout, gsa.String())
	if amount0 != "36789784" {
		panic("router_z6_mintBazFoo() || amount0 should be 36789784")
	}
	if amount1 != "100000000" {
		panic("router_z6_mintBazFoo() || amount1 should be 100000000")
	}
}

// BAR > BAZ > ExactIn || DRY
func drySwapBarBazExactIn() {
	std.TestSetPrevAddr(gsa)

	dryResult := rr.DrySwapRoute(
		barPath,    // inputToken
		bazPath,    // outputToken
		"1000000",  // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // strRouteArr
		"100", // quoteArr
	)
	if dryResult != "2714276" {
		panic("router_z6_drySwapBarBazExactIn() || dryResult should be 2714276")
	}
}

// BAR > BAZ > ExactIn || SWAP
func swapBarBazExactIn() {
	std.TestSetPrevAddr(gsa)

	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)   // swap input amount
	baz.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX) // 0.15% fee

	amountIn, amountOut := rr.SwapRoute(
		barPath,    // inputToken
		bazPath,    // outputToken
		"1000000",  // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // strRouteArr
		"100", // quoteArr
		"0",   // tokenAmountLimit
	)
	if amountIn != "1000000" {
		panic("router_z6_swapBarBazExactIn() || amountIn should be 1000000")
	}
	if amountOut != "-2710205" {
		panic("router_z6_swapBarBazExactIn() || amountIn should be -2710205")
	}
}

// BAZ > BAR > ExactIn || DRY
func drySwapBazBarExactIn() {
	std.TestSetPrevAddr(gsa)

	dryResult := rr.DrySwapRoute(
		bazPath,    // inputToken
		barPath,    // outputToken
		"2714276",  // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/baz:gno.land/r/demo/bar:100", // strRouteArr
		"100", // quoteArr
	)
	if dryResult != "999799" {
		panic("router_z6_drySwapBazBarExactIn() || dryResult should be 999799")
	}
}

// BAZ > BAR > ExactIn || SWAP
func swapBazBarExactIn() {
	std.TestSetPrevAddr(gsa)

	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)   // swap input amount
	bar.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX) // 0.15% fee

	amountIn, amountOut := rr.SwapRoute(
		bazPath,    // inputToken
		barPath,    // outputToken
		"2714276",  // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/baz:gno.land/r/demo/bar:100", // strRouteArr
		"100", // quoteArr
		"0",   // tokenAmountLimit
	)
	if amountIn != "2714276" {
		panic("router_z6_swapBazBarExactIn() || amountIn should be 2714276")
	}
	if amountOut != "-998300" {
		panic("router_z6_swapBazBarExactIn() || amountIn should be -998300")
	}
}

// BAR > BAZ > ExactOut || DRY
func drySwapBarBazExactOut() {
	std.TestSetPrevAddr(gsa)

	dryResult := rr.DrySwapRoute(
		barPath,     // inputToken
		bazPath,     // outputToken
		"2714276",   // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // strRouteArr
		"100", // quoteArr
	)
	if dryResult != "1000002" {
		panic("router_z6_drySwapBarBazExactOut() || dryResult should be 1000002") //
	}
}

// BAR > BAZ > ExactOut || SWAP
func swapBarBazExactOut() {
	std.TestSetPrevAddr(gsa)

	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)   // swap input amount
	baz.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX) // 0.15% fee

	amountIn, amountOut := rr.SwapRoute(
		barPath,     // inputToken
		bazPath,     // outputToken
		"2714276",   // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100", // strRouteArr
		"100",     // quoteArr
		"1000002", // tokenAmountLimit
	)
	if amountIn != "1000002" {
		panic("router_z6_swapBarBazExactOut() || amountIn should be 1000002")
	}
	if amountOut != "-2710205" {
		panic("router_z6_swapBarBazExactOut() || amountIn should be 1000002")
	}
}

// BAR > QUX > ExactIn || DRY
func drySwapBarQuxExactIn() {
	std.TestSetPrevAddr(gsa)

	dryResult := rr.DrySwapRoute(
		barPath,    // inputToken
		quxPath,    // outputToken
		"1000000",  // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100*POOL*gno.land/r/demo/baz:gno.land/r/demo/foo:100*POOL*gno.land/r/demo/foo:gno.land/r/demo/qux:100", // strRouteArr
		"100", // quoteArr
	)
	if dryResult != "19733647" {
		panic("router_z6_drySwapBarQuxExactIn() || amountIn should be 19733647")
	}
}

// BAR > QUX > ExactIn || SWAP
func swapBarQuxExactIn() {
	std.TestSetPrevAddr(gsa)

	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)   // swap input amount
	qux.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX) // 0.15% fee

	amountIn, amountOut := rr.SwapRoute(
		barPath,    // inputToken
		quxPath,    // outputToken
		"1000000",  // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:100*POOL*gno.land/r/demo/baz:gno.land/r/demo/foo:100*POOL*gno.land/r/demo/foo:gno.land/r/demo/qux:100", // strRouteArr
		"100", // quoteArr
		"0",   // tokenAmountLimit
	)

	if amountIn != "1000000" {
		panic("router_z6_swapBarQuxExactIn() || amountIn should be 1000000")
	}
	if amountOut != "-19704047" {
		panic("router_z6_swapBarQuxExactIn() || amountIn should be -19704047")
	}
}

// QUX > BAR > ExactOut || DRY
func drySwapQuxBarExactOut() {
	std.TestSetPrevAddr(gsa)

	dryResult := rr.DrySwapRoute(
		quxPath,     // inputToken
		barPath,     // outputToken
		"2000000",   // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/qux:gno.land/r/demo/foo:100*POOL*gno.land/r/demo/foo:gno.land/r/demo/baz:100*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:100", // strRouteArr
		"100", // quoteArr
	)
	if dryResult != "40079942" {
		panic("router_z6_drySwapQuxBarExactOut() || amountIn should be 40079942")
	}
}

// QUX > BAR > ExactOut || SWAP
func swapQuxBarExactOut() {
	std.TestSetPrevAddr(gsa)

	qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)   // swap input amount
	bar.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX) // 0.15% fee

	amountIn, amountOut := rr.SwapRoute(
		quxPath,     // inputToken
		barPath,     // outputToken
		"2000000",   // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/demo/qux:gno.land/r/demo/foo:100*POOL*gno.land/r/demo/foo:gno.land/r/demo/baz:100*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:100", // strRouteArr
		"100",      // quoteArr
		"40079942", // tokenAmountLimit
	)

	if amountIn != "40079942" {
		panic("router_z6_swapQuxBarExactOut() || amountIn should be 40079942")
	}
	if amountOut != "-1997000" {
		panic("router_z6_swapQuxBarExactOut() || amountIn should be -1997000")
	}
}
