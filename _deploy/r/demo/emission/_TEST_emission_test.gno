package emission

import (
	"std"
	"testing"

	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/gns"
)

func TestEmitGns(t *testing.T) {
	shouldEQ(t, gns.TotalSupply(), 100000000000000) // GSA has
	shouldEQ(t, gnsBalance(emissionAddr), 0)

	EmitGns() // 1 ~ 123 height

	shouldEQ(t, gnsBalance(emissionAddr), 4387842345)
	shouldEQ(t, gns.TotalSupply(), 100000000000000+4387842345)

	shouldEQ(t, std.GetHeight(), 123)
}

func TestEmitGnsSameBlock(t *testing.T) {
	// request mint again in same block => do not mint again
	// it may happen because single block can have multiple txs & msgs
	EmitGns()
	shouldEQ(t, gns.TotalSupply(), 100000000000000+4387842345)
}

func TestEmitGnsAllAmount(t *testing.T) {
	std.TestSkipHeights(75686400 - 1)
	gns.TestSetLastMintedHeight(std.GetHeight())
	std.TestSkipHeights(1)

	EmitGns()
	shouldEQ(t, gns.TotalSupply(), 100000000000000+4387842345+2229594)
	// all emission duratino has been passed

	std.TestSkipHeights(1)
	EmitGns() // since all emission has been done, no more minting
	shouldEQ(t, gns.TotalSupply(), 100000000000000+4387842345+2229594)
}

// UTILs
func gnsBalance(addr std.Address) uint64 {
	a2u := pusers.AddressOrName(addr)

	return gns.BalanceOf(a2u)
}

func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldPanicWithMsg(t *testing.T, f func(), msg string) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("The code did not panic")
		} else {
			if r != msg {
				t.Errorf("excepted panic(%v), got(%v)", msg, r)
			}
		}
	}()
	f()
}
