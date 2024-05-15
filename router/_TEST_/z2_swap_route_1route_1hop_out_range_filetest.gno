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

	return uint64(testBanker.GetCoins(addr)[0].Amount)
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
	_, _, amount0, amount1 := pn.Mint(barPath, bazPath, fee500, int32(12000), int32(15000), "100000", "100000", "0", "0", maxTimeout, gsa.String())
	// only bar, no baz
	if amount0 != "36790" {
		"router_z3_mint() || amount0 should be 10000"
	}
	if amount1 != "100000" {
		"router_z3_mint() || amount1 should be 0"
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
	if dryResult != "-1" {
		panic("router_z3_drySwapBarBazExactIn() || dryResult should be -1")
	}
}

func swapBarBazExactIn() {
	std.TestSetPrevAddr(gsa)

	bar.Approve(a2u(consts.POOL_ADDR), uint64(1000))
	baz.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX) // ITS FOR 0.15% fee

	rr.SwapRoute(
		barPath,    // inputToken
		bazPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500", // strRouteArr
		"100",  // quoteArr
		"2700", // tokenAmountLimit
	)
}

// Error:
// [ROUTER] router.gno__SwapRoute() || too few received for user (expected minimum received:2700, actual received:0)
