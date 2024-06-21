package register_gnodev

import (
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/foo20"
	"gno.land/r/demo/gns"
	"gno.land/r/demo/obl"
	"gno.land/r/demo/qux"
	"gno.land/r/demo/usdc"
	"gno.land/r/demo/wugnot"

	"gno.land/r/demo/test01"
	"gno.land/r/demo/test02"
	"gno.land/r/demo/test03"
	"gno.land/r/demo/test04"
	"gno.land/r/demo/test05"
	"gno.land/r/demo/test06"
	"gno.land/r/demo/test07"

	pl "gno.land/r/demo/pool"
	rr "gno.land/r/demo/router"
	sr "gno.land/r/demo/staker"
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

type Test01 struct{}

func (Test01) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return test01.Transfer
}
func (Test01) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return test01.TransferFrom
}
func (Test01) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return test01.BalanceOf
}
func (Test01) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return test01.Approve
}

type Test02 struct{}

func (Test02) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return test02.Transfer
}
func (Test02) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return test02.TransferFrom
}
func (Test02) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return test02.BalanceOf
}
func (Test02) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return test02.Approve
}

type Test03 struct{}

func (Test03) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return test03.Transfer
}
func (Test03) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return test03.TransferFrom
}
func (Test03) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return test03.BalanceOf
}
func (Test03) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return test03.Approve
}

type Test04 struct{}

func (Test04) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return test04.Transfer
}
func (Test04) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return test04.TransferFrom
}
func (Test04) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return test04.BalanceOf
}
func (Test04) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return test04.Approve
}

type Test05 struct{}

func (Test05) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return test05.Transfer
}
func (Test05) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return test05.TransferFrom
}
func (Test05) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return test05.BalanceOf
}
func (Test05) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return test05.Approve
}

type Test06 struct{}

func (Test06) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return test06.Transfer
}
func (Test06) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return test06.TransferFrom
}
func (Test06) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return test06.BalanceOf
}
func (Test06) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return test06.Approve
}

type Test07 struct{}

func (Test07) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return test07.Transfer
}
func (Test07) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return test07.TransferFrom
}
func (Test07) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return test07.BalanceOf
}
func (Test07) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return test07.Approve
}

func init() {
	pl.RegisterGRC20Interface("gno.land/r/demo/foo", FooToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/bar", BarToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/baz", BazToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/qux", QuxToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/gns", GnsToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/obl", OblToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	pl.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/usdc", UsdcToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/test01", Test01{})
	pl.RegisterGRC20Interface("gno.land/r/demo/test02", Test02{})
	pl.RegisterGRC20Interface("gno.land/r/demo/test03", Test03{})
	pl.RegisterGRC20Interface("gno.land/r/demo/test04", Test04{})
	pl.RegisterGRC20Interface("gno.land/r/demo/test05", Test05{})
	pl.RegisterGRC20Interface("gno.land/r/demo/test06", Test06{})
	pl.RegisterGRC20Interface("gno.land/r/demo/test07", Test07{})

	sr.RegisterGRC20Interface("gno.land/r/demo/foo", FooToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/bar", BarToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/baz", BazToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/qux", QuxToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/gns", GnsToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/obl", OblToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	sr.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/usdc", UsdcToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/test01", Test01{})
	sr.RegisterGRC20Interface("gno.land/r/demo/test02", Test02{})
	sr.RegisterGRC20Interface("gno.land/r/demo/test03", Test03{})
	sr.RegisterGRC20Interface("gno.land/r/demo/test04", Test04{})
	sr.RegisterGRC20Interface("gno.land/r/demo/test05", Test05{})
	sr.RegisterGRC20Interface("gno.land/r/demo/test06", Test06{})
	sr.RegisterGRC20Interface("gno.land/r/demo/test07", Test07{})

	rr.RegisterGRC20Interface("gno.land/r/demo/foo", FooToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/bar", BarToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/baz", BazToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/qux", QuxToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/gns", GnsToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/obl", OblToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	rr.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/usdc", UsdcToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/test01", Test01{})
	rr.RegisterGRC20Interface("gno.land/r/demo/test02", Test02{})
	rr.RegisterGRC20Interface("gno.land/r/demo/test03", Test03{})
	rr.RegisterGRC20Interface("gno.land/r/demo/test04", Test04{})
	rr.RegisterGRC20Interface("gno.land/r/demo/test05", Test05{})
	rr.RegisterGRC20Interface("gno.land/r/demo/test06", Test06{})
	rr.RegisterGRC20Interface("gno.land/r/demo/test07", Test07{})
}
