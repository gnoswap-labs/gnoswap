package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	pusers "gno.land/p/demo/users"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
	"gno.land/r/onbloc/usdc"
)

// define addresses to use in tests
const (
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
)

// addresses used in tests
var addrUsedInTest = []std.Address{
	addr01,
	addr02,
}

// resetObject resets the object state(clear or make it default values)
func resetObject(t *testing.T) {
	pools = make(poolMap)
	slot0FeeProtocol = 0
	poolCreationFee = 100_000_000
	withdrawalFee = 100
}

func burnTokens(t *testing.T) {
	t.Helper()

	// burn tokens
	for _, addr := range addrUsedInTest {
		uAddr := a2u(addr)
		burnFoo(uAddr)
		burnBar(uAddr)
		burnBaz(uAddr)
		burnQux(uAddr)
		burnObl(uAddr)
		burnUsdc(uAddr)
	}
}

func burnFoo(addr pusers.AddressOrName) {
	std.TestSetRealm(adminRealm)
	foo.Burn(addr, foo.BalanceOf(addr))
}

func burnBar(addr pusers.AddressOrName) {
	std.TestSetRealm(adminRealm)
	bar.Burn(addr, bar.BalanceOf(addr))
}

func burnBaz(addr pusers.AddressOrName) {
	std.TestSetRealm(adminRealm)
	baz.Burn(addr, baz.BalanceOf(addr))
}

func burnQux(addr pusers.AddressOrName) {
	std.TestSetRealm(adminRealm)
	qux.Burn(addr, qux.BalanceOf(addr))
}

func burnObl(addr pusers.AddressOrName) {
	std.TestSetRealm(adminRealm)
	obl.Burn(addr, obl.BalanceOf(addr))
}

func burnUsdc(addr pusers.AddressOrName) {
	std.TestSetRealm(adminRealm)
	usdc.Burn(addr, usdc.BalanceOf(addr))
}

func TestBeforeResetObject(t *testing.T) {
	// make some data
	pools = make(poolMap)
	pools["gno.land/r/gnoswap/v1/gns:gno.land/r/onbloc/usdc"] = &Pool{
		token0Path: "gno.land/r/gnoswap/v1/gns",
		token1Path: "gno.land/r/onbloc/usdc",
	}

	slot0FeeProtocol = 1
	poolCreationFee = 100_000_000
	withdrawalFee = 100

	// transfer some tokens
	std.TestSetRealm(adminRealm)
	foo.Transfer(a2u(addr01), 100_000_000)
	bar.Transfer(a2u(addr01), 100_000_000)

	uassert.Equal(t, foo.BalanceOf(a2u(addr01)), uint64(100_000_000))
	uassert.Equal(t, bar.BalanceOf(a2u(addr01)), uint64(100_000_000))
}

func TestResetObject(t *testing.T) {
	resetObject(t)
	uassert.Equal(t, len(pools), 0)
	uassert.Equal(t, slot0FeeProtocol, uint8(0))
	uassert.Equal(t, poolCreationFee, uint64(100_000_000))
	uassert.Equal(t, withdrawalFee, uint64(100))
}

func TestBurnTokens(t *testing.T) {
	burnTokens(t)

	uassert.Equal(t, foo.BalanceOf(a2u(addr01)), uint64(0)) // 100_000_000 -> 0
	uassert.Equal(t, bar.BalanceOf(a2u(addr01)), uint64(0)) // 100_000_000 -> 0
}
