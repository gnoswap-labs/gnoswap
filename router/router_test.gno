package router

import (
	"std"
	"strconv"
	"strings"
    "testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/testutils"

	"gno.land/r/gnoswap/v1/consts"
    i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/demo/wugnot"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
	"gno.land/r/gnoswap/v1/gns"

	pusers "gno.land/p/demo/users"
)

func registerGRC20ForTest(t *testing.T, pkgPath string, igrc20 GRC20Interface) {
	t.Helper()
	registered[pkgPath] = igrc20
}

func unregisterGRC20ForTest(t *testing.T, pkgPath string) {
	t.Helper()
	delete(registered, pkgPath)
}

type MockGRC20 struct {
	TransferFn      func(to pusers.AddressOrName, amount uint64)
	TransferFromFn  func(from, to pusers.AddressOrName, amount uint64)
	BalanceOfFn     func(owner pusers.AddressOrName) uint64
	ApproveFn       func(spender pusers.AddressOrName, amount uint64)
	AllowanceFn     func(owner, spender pusers.AddressOrName) uint64
}

func (m MockGRC20) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return m.TransferFn
}

func (m MockGRC20) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return m.TransferFromFn
}

func (m MockGRC20) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return m.BalanceOfFn
}

func (m MockGRC20) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return m.ApproveFn
}

func (m MockGRC20) Allowance() func(owner, spender pusers.AddressOrName) uint64 {
	if m.AllowanceFn != nil {
		return m.AllowanceFn
	}
	return func(owner, spender pusers.AddressOrName) uint64 {
		return 1000000000000
	}
}

func setupTestPool(
	t *testing.T,
	token0Path, token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	t.Helper()

	std.TestSetRealm(std.NewUserRealm(consts.ADMIN))
	pl.SetPoolCreationFeeByAdmin(1)

	if token0Path > token1Path {
		t.Fatalf("tokens are not sorted: %s > %s", token0Path, token1Path)
	}

	pl.CreatePool(token0Path, token1Path, fee, sqrtPriceX96)
}
