package factory

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
)

var (
	po  = testutils.TestAddress("po")  // Pool Owner
	ano = testutils.TestAddress("ano") // Another Address
)

func TestInit(t *testing.T) {
	shouldEQ(t, initialized, false)

	std.TestSetOrigCaller(po)
	Init()

	shouldEQ(t, initialized, true)
	shouldEQ(t, owner, po)

	shouldPanic(t, func() { Init() })
}

func TestCreatePool(t *testing.T) {
	var _tmpTokenA, _tmpTokenB string // XXX std.Address or pkg_path
	var _tmpFee, _tmpSqrtPrice bigint

	_tmpTokenA = "foo" // token0 pkg_path
	_tmpTokenB = "bar" // token1 pkg_path
	_tmpFee = 3000
	_tmpSqrtPrice = 130621891405341611593710811006

	createdPool := CreatePool(_tmpTokenA, _tmpTokenB, _tmpFee, _tmpSqrtPrice)

	shouldPanic(t, func() { CreatePool(_tmpTokenA, _tmpTokenB, _tmpFee, _tmpSqrtPrice) })
}

func TestSetOwner(t *testing.T) {
	std.TestSetOrigCaller(ano)
	shouldPanic(t, func() { SetOwner(ano) })

	std.TestSetOrigCaller(po)
	shouldEQ(t, owner, po)
	SetOwner(ano)
	shouldEQ(t, owner, ano)

	// revert
	std.TestSetOrigCaller(ano)
	SetOwner(po)
}

func TestEnableFeeAmount(t *testing.T) {
	std.TestSetOrigCaller(po)

	shouldPanic(t, func() { EnableFeeAmount(-1, 1000) })
	shouldPanic(t, func() { EnableFeeAmount(1000000, 1000) })

	EnableFeeAmount(123, 456)
	shouldPanic(t, func() { EnableFeeAmount(123, 987) })
}

func TestGetPool(t *testing.T) {
	getPool("foo", "bar", bigint(3000))
	shouldPanic(t, func() { getPool("foo", "bar", bigint(3001)) })
}

// utils
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}
