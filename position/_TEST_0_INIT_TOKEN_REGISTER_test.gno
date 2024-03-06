package position

import (
	"std"

	"gno.land/r/demo/foo"

	"gno.land/r/demo/bar"

	"gno.land/r/demo/baz"

	"gno.land/r/demo/qux"

	"gno.land/r/demo/wugnot"

	"gno.land/r/demo/obl"

	"gno.land/r/demo/gns"

	"gno.land/r/demo/consts"

	"gno.land/r/demo/users"

	pl "gno.land/r/demo/pool" // only for position `testcase`` to call grc20 by register
)

type FooToken struct{}

func (FooToken) Transfer() func(to users.AddressOrName, amount uint64) {
	return foo.Transfer
}
func (FooToken) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return foo.TransferFrom
}
func (FooToken) BalanceOf() func(owner users.AddressOrName) uint64 {
	return foo.BalanceOf
}
func (FooToken) Approve() func(spender users.AddressOrName, amount uint64) {
	return foo.Approve
}

var _ pl.GRC20Interface = FooToken{}

type BarToken struct{}

func (BarToken) Transfer() func(to users.AddressOrName, amount uint64) {
	return bar.Transfer
}
func (BarToken) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return bar.TransferFrom
}
func (BarToken) BalanceOf() func(owner users.AddressOrName) uint64 {
	return bar.BalanceOf
}
func (BarToken) Approve() func(spender users.AddressOrName, amount uint64) {
	return bar.Approve
}

var _ pl.GRC20Interface = BarToken{}

type BazToken struct{}

func (BazToken) Transfer() func(to users.AddressOrName, amount uint64) {
	return baz.Transfer
}
func (BazToken) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return baz.TransferFrom
}
func (BazToken) BalanceOf() func(owner users.AddressOrName) uint64 {
	return baz.BalanceOf
}
func (BazToken) Approve() func(spender users.AddressOrName, amount uint64) {
	return baz.Approve
}

var _ pl.GRC20Interface = BazToken{}

type QuxToken struct{}

func (QuxToken) Transfer() func(to users.AddressOrName, amount uint64) {
	return qux.Transfer
}
func (QuxToken) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return qux.TransferFrom
}
func (QuxToken) BalanceOf() func(owner users.AddressOrName) uint64 {
	return qux.BalanceOf
}
func (QuxToken) Approve() func(spender users.AddressOrName, amount uint64) {
	return qux.Approve
}

var _ pl.GRC20Interface = QuxToken{}

type WugnotToken struct{}

func (WugnotToken) Transfer() func(to users.AddressOrName, amount uint64) {
	return wugnot.Transfer
}
func (WugnotToken) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return wugnot.TransferFrom
}
func (WugnotToken) BalanceOf() func(owner users.AddressOrName) uint64 {
	return wugnot.BalanceOf
}
func (WugnotToken) Approve() func(spender users.AddressOrName, amount uint64) {
	return wugnot.Approve
}

var _ pl.GRC20Interface = WugnotToken{}

type OBLToken struct{}

func (OBLToken) Transfer() func(to users.AddressOrName, amount uint64) {
	return obl.Transfer
}
func (OBLToken) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return obl.TransferFrom
}
func (OBLToken) BalanceOf() func(owner users.AddressOrName) uint64 {
	return obl.BalanceOf
}
func (OBLToken) Approve() func(spender users.AddressOrName, amount uint64) {
	return obl.Approve
}

var _ pl.GRC20Interface = OBLToken{}

type GNSToken struct{}

func (GNSToken) Transfer() func(to users.AddressOrName, amount uint64) {
	return gns.Transfer
}

func (GNSToken) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return gns.TransferFrom
}

func (GNSToken) BalanceOf() func(owner users.AddressOrName) uint64 {
	return gns.BalanceOf
}

func (GNSToken) Approve() func(spender users.AddressOrName, amount uint64) {
	return gns.Approve
}

var _ pl.GRC20Interface = GNSToken{}

func init() {
	std.TestSetPrevAddr(consts.GNOSWAP_ADMIN)

	pl.RegisterGRC20Interface("gno.land/r/demo/bar", BarToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/foo", FooToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/baz", BazToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/qux", QuxToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/obl", OBLToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/gns", GNSToken{})
}
