package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
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
	RegisterGRC20Interface("gno.land/r/gnoswap/v1/gns", GNSToken{})
}

func TestGetRegisteredTokens(t *testing.T) {
	uassert.Equal(t, len(GetRegisteredTokens()), 7)
}

func TestRegisterGRC20Interface(t *testing.T) {
	uassert.PanicsWithMessage(t,
		`[GNOSWAP-POOL-001] caller has no permission || token_register.gno__RegisterGRC20Interface() || only register(g1er355fkjksqpdtwmhf5penwa82p0rhqxkkyhk5) can register token, called from g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm`,
		func() {
			RegisterGRC20Interface("gno.land/r/onbloc/bar", BarToken{})
		},
	)
}

func TestUnregisterGRC20Interface(t *testing.T) {
	dummy := testutils.TestAddress("dummy")
	std.TestSetRealm(std.NewUserRealm(dummy))

	uassert.PanicsWithMessage(t,
		`[GNOSWAP-POOL-001] caller has no permission || token_register.gno__UnregisterGRC20Interface() || unauthorized address(g1v36k6mteta047h6lta047h6lta047h6lz7gmv8) to unregister`,
		func() {
			UnregisterGRC20Interface("gno.land/r/onbloc/bar")
		},
	)

	uassert.Equal(t, len(GetRegisteredTokens()), 7)

	std.TestSetRealm(std.NewUserRealm(consts.TOKEN_REGISTER))
	UnregisterGRC20Interface("gno.land/r/onbloc/bar")
	uassert.Equal(t, len(GetRegisteredTokens()), 6)

	// re-register to avoid panic in other tests
	RegisterGRC20Interface("gno.land/r/onbloc/bar", BarToken{})

	std.TestSetRealm(adminRealm)
}
