package register_gnodev

import (
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/foo20"
	"gno.land/r/demo/wugnot"

	"gno.land/r/gnoswap/gns"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
	"gno.land/r/onbloc/usdc"

	cp "gno.land/r/gnoswap/community_pool"
	pl "gno.land/r/gnoswap/pool"
	pf "gno.land/r/gnoswap/protocol_fee"
	rr "gno.land/r/gnoswap/router"
	sr "gno.land/r/gnoswap/staker"
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

type GnsToken struct{}

func (GnsToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return gns.Transfer
}
func (GnsToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return gns.TransferFrom
}
func (GnsToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return gns.BalanceOf
}
func (GnsToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return gns.Approve
}

type OblToken struct{}

func (OblToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return obl.Transfer
}
func (OblToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return obl.TransferFrom
}
func (OblToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return obl.BalanceOf
}
func (OblToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return obl.Approve
}

type Foo20Token struct{}

func (Foo20Token) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return foo20.Transfer
}
func (Foo20Token) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return foo20.TransferFrom
}
func (Foo20Token) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return foo20.BalanceOf
}
func (Foo20Token) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return foo20.Approve
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

type UsdcToken struct{}

func (UsdcToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return usdc.Transfer
}
func (UsdcToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return usdc.TransferFrom
}
func (UsdcToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return usdc.BalanceOf
}
func (UsdcToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return usdc.Approve
}

func init() {
	pl.RegisterGRC20Interface("gno.land/r/onbloc/foo", FooToken{})
	pl.RegisterGRC20Interface("gno.land/r/onbloc/bar", BarToken{})
	pl.RegisterGRC20Interface("gno.land/r/onbloc/baz", BazToken{})
	pl.RegisterGRC20Interface("gno.land/r/onbloc/qux", QuxToken{})
	pl.RegisterGRC20Interface("gno.land/r/gnoswap/gns", GnsToken{})
	pl.RegisterGRC20Interface("gno.land/r/onbloc/obl", OblToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	pl.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	pl.RegisterGRC20Interface("gno.land/r/onbloc/usdc", UsdcToken{})

	sr.RegisterGRC20Interface("gno.land/r/onbloc/foo", FooToken{})
	sr.RegisterGRC20Interface("gno.land/r/onbloc/bar", BarToken{})
	sr.RegisterGRC20Interface("gno.land/r/onbloc/baz", BazToken{})
	sr.RegisterGRC20Interface("gno.land/r/onbloc/qux", QuxToken{})
	sr.RegisterGRC20Interface("gno.land/r/gnoswap/gns", GnsToken{})
	sr.RegisterGRC20Interface("gno.land/r/onbloc/obl", OblToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	sr.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	sr.RegisterGRC20Interface("gno.land/r/onbloc/usdc", UsdcToken{})

	rr.RegisterGRC20Interface("gno.land/r/onbloc/foo", FooToken{})
	rr.RegisterGRC20Interface("gno.land/r/onbloc/bar", BarToken{})
	rr.RegisterGRC20Interface("gno.land/r/onbloc/baz", BazToken{})
	rr.RegisterGRC20Interface("gno.land/r/onbloc/qux", QuxToken{})
	rr.RegisterGRC20Interface("gno.land/r/gnoswap/gns", GnsToken{})
	rr.RegisterGRC20Interface("gno.land/r/onbloc/obl", OblToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	rr.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	rr.RegisterGRC20Interface("gno.land/r/onbloc/usdc", UsdcToken{})

	pf.RegisterGRC20Interface("gno.land/r/onbloc/foo", FooToken{})
	pf.RegisterGRC20Interface("gno.land/r/onbloc/bar", BarToken{})
	pf.RegisterGRC20Interface("gno.land/r/onbloc/baz", BazToken{})
	pf.RegisterGRC20Interface("gno.land/r/onbloc/qux", QuxToken{})
	pf.RegisterGRC20Interface("gno.land/r/gnoswap/gns", GnsToken{})
	pf.RegisterGRC20Interface("gno.land/r/onbloc/obl", OblToken{})
	pf.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	pf.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	pf.RegisterGRC20Interface("gno.land/r/onbloc/usdc", UsdcToken{})

	cp.RegisterGRC20Interface("gno.land/r/onbloc/foo", FooToken{})
	cp.RegisterGRC20Interface("gno.land/r/onbloc/bar", BarToken{})
	cp.RegisterGRC20Interface("gno.land/r/onbloc/baz", BazToken{})
	cp.RegisterGRC20Interface("gno.land/r/onbloc/qux", QuxToken{})
	cp.RegisterGRC20Interface("gno.land/r/gnoswap/gns", GnsToken{})
	cp.RegisterGRC20Interface("gno.land/r/onbloc/obl", OblToken{})
	cp.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	cp.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	cp.RegisterGRC20Interface("gno.land/r/onbloc/usdc", UsdcToken{})
}
