package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"

	"gno.land/r/onbloc/foo"

	"gno.land/r/onbloc/bar"

	"gno.land/r/onbloc/baz"

	"gno.land/r/onbloc/qux"

	"gno.land/r/demo/wugnot"

	"gno.land/r/onbloc/obl"

	"gno.land/r/gnoswap/v1/gns"

	"gno.land/r/gnoswap/v1/consts"

	pusers "gno.land/p/demo/users"
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

func init() {
	std.TestSetRealm(std.NewUserRealm(consts.TOKEN_REGISTER))

	RegisterGRC20Interface("gno.land/r/onbloc/bar", BarToken{})
	RegisterGRC20Interface("gno.land/r/onbloc/foo", FooToken{})
	RegisterGRC20Interface("gno.land/r/onbloc/baz", BazToken{})
	RegisterGRC20Interface("gno.land/r/onbloc/qux", QuxToken{})
	RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	RegisterGRC20Interface("gno.land/r/onbloc/obl", OBLToken{})
	// RegisterGRC20Interface("gno.land/r/gnoswap/v1/gns", GNSToken{})
}

func TestGetRegisteredTokens(t *testing.T) {
	uassert.Equal(t, 6, len(GetRegisteredTokens()))
}

func TestRegisterGRC20Interface(t *testing.T) {

	tests := []struct {
		name        string
		caller      std.Address
		pkgPath     string
		token       GRC20Interface
		shouldPanic bool
		panicMsg    string
		verify      func()
	}{
		{
			"no permission",
			std.Address(""),
			"gno.land/r/onbloc/bar",
			BarToken{},
			true,
			`[GNOSWAP-POOL-001] caller has no permission || only register(g1er355fkjksqpdtwmhf5penwa82p0rhqxkkyhk5) can register token, called from g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm`,
			func() {},
		},
		{
			"already registered",
			std.Address(consts.TOKEN_REGISTER),
			"gno.land/r/onbloc/bar",
			BarToken{},
			true,
			`[GNOSWAP-POOL-003] already registered token || token(gno.land/r/onbloc/bar) already registered`,
			func() {},
		},
		{
			"success register",
			std.Address(consts.TOKEN_REGISTER),
			"gno.land/r/gnoswap/v1/gns",
			GNSToken{},
			false,
			"",
			func() {
				mustRegistered("gno.land/r/gnoswap/v1/gns")
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if test.caller != "" {
				std.TestSetRealm(std.NewUserRealm(test.caller))
			}

			if test.shouldPanic {
				uassert.PanicsWithMessage(
					t,
					test.panicMsg,
					func() {
						RegisterGRC20Interface(test.pkgPath, test.token)
					},
				)
			} else {
				RegisterGRC20Interface(test.pkgPath, test.token)
				test.verify()
			}
		})
	}
}

func TestUnregisterGRC20Interface(t *testing.T) {
	tests := []struct {
		name        string
		isUser      bool
		caller      std.Address
		pkgPath     string
		shouldPanic bool
		panicMsg    string
		verify      func()
	}{
		{
			"not user call",
			false,
			std.Address(""),
			"gno.land/r/onbloc/bar",
			true,
			`given condition is not satisfied the permission check || is not user call`,
			func() {},
		},
		{
			"no permission",
			true,
			std.Address(""),
			"gno.land/r/onbloc/bar",
			true,
			`caller(g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm) has no permission || unauthorized address to unregister`,
			func() {},
		},
		{
			"success delete not registered",
			true,
			std.Address(consts.TOKEN_REGISTER),
			"gno.land/r/dummy",
			false,
			"",
			func() {
				uassert.Equal(t, 7, len(GetRegisteredTokens()))
			},
		},
		{
			"success delete registered",
			true,
			std.Address(consts.TOKEN_REGISTER),
			"gno.land/r/onbloc/bar",
			false,
			"",
			func() {
				uassert.Equal(t, 6, len(GetRegisteredTokens()))
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if test.isUser && test.caller != "" {
				std.TestSetRealm(std.NewUserRealm(test.caller))
			}

			if !test.isUser {
				std.TestSetRealm(std.NewCodeRealm("gno.land/r/dummy"))
			}

			if test.shouldPanic {
				uassert.PanicsWithMessage(
					t,
					test.panicMsg,
					func() {
						UnregisterGRC20Interface(test.pkgPath)
					},
				)
			} else {
				UnregisterGRC20Interface(test.pkgPath)
				test.verify()
			}
		})
	}

	// re-register to avoid panic in other tests
	std.TestSetRealm(std.NewUserRealm(consts.TOKEN_REGISTER))
	RegisterGRC20Interface("gno.land/r/onbloc/bar", BarToken{})
	uassert.Equal(t, 7, len(GetRegisteredTokens()))

	// reset caller to admin
	std.TestSetRealm(std.NewUserRealm(consts.ADMIN))
}
