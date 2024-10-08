package position

import (
	"std"

	"gno.land/r/onbloc/foo"

	"gno.land/r/onbloc/bar"

	"gno.land/r/onbloc/baz"

	"gno.land/r/onbloc/qux"

	"gno.land/r/demo/wugnot"

	"gno.land/r/onbloc/obl"

	"gno.land/r/gnoswap/v2/gns"

	"gno.land/r/onbloc/usdc"

	"gno.land/r/gnoswap/v2/consts"

	pusers "gno.land/p/demo/users"

	pl "gno.land/r/gnoswap/v2/pool"
	rr "gno.land/r/gnoswap/v2/router"
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

type USDCToken struct{}

func (USDCToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return usdc.Transfer
}

func (USDCToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return usdc.TransferFrom
}

func (USDCToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return usdc.BalanceOf
}

func (USDCToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return usdc.Approve
}

func init() {
	std.TestSetRealm(std.NewUserRealm(consts.TOKEN_REGISTER))

	pl.RegisterGRC20Interface("gno.land/r/onbloc/bar", BarToken{})
	pl.RegisterGRC20Interface("gno.land/r/onbloc/foo", FooToken{})
	pl.RegisterGRC20Interface("gno.land/r/onbloc/baz", BazToken{})
	pl.RegisterGRC20Interface("gno.land/r/onbloc/qux", QuxToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	pl.RegisterGRC20Interface("gno.land/r/onbloc/obl", OBLToken{})
	pl.RegisterGRC20Interface("gno.land/r/gnoswap/v2/gns", GNSToken{})
	pl.RegisterGRC20Interface("gno.land/r/onbloc/usdc", USDCToken{})

	rr.RegisterGRC20Interface("gno.land/r/onbloc/bar", BarToken{})
	rr.RegisterGRC20Interface("gno.land/r/onbloc/foo", FooToken{})
	rr.RegisterGRC20Interface("gno.land/r/onbloc/baz", BazToken{})
	rr.RegisterGRC20Interface("gno.land/r/onbloc/qux", QuxToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	rr.RegisterGRC20Interface("gno.land/r/onbloc/obl", OBLToken{})
	rr.RegisterGRC20Interface("gno.land/r/gnoswap/v2/gns", GNSToken{})
	rr.RegisterGRC20Interface("gno.land/r/onbloc/usdc", USDCToken{})
}
