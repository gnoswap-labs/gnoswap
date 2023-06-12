package factory

import (
	"std"
	"testing"
)

func TestInit(t *testing.T) {
	Init()
	shouldEqual(t, owner, GetOrigCaller())

}

func TestCreatePool(t *testing.T) {
	tokenA := std.Address("ABC")
	tokenB := std.Address("ZXC")

	pool := CreatePool(tokenA, tokenB, 500)

	// should fail => Pool exists
	// CreatePool(tokenA, tokenB, 500)
}

func TestSetOwner(t *testing.T) {
	SetOwner(std.Address("NewOwnerHere"))
	shouldEqual(t, owner, std.Address("NewOwnerHere"))
}

func TestEnableFeeAmount(t *testing.T) {
	std.TestSetOrigCaller(std.Address("NewOwnerHere"))

	EnableFeeAmount(100, 10)
	_fee, _ := feeAmountTickSpacing.Get("100")
	shouldEqual(t, _fee, bigint(10))
}

// helper
func shouldEqual(t *testing.T, got interface{}, expected interface{}) {
	if got != expected {
		t.Fatalf("expected %d, got %d.", expected, got)
	}
}
