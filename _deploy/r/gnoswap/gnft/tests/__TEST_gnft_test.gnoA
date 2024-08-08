package gnft

import (
	"std"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"

	pusers "gno.land/p/demo/users"
)

var (
	positionPath  = "gno.land/r/gnoswap/v2/position"
	positionAddr  = std.DerivePkgAddr(positionPath)
	positionRealm = std.NewCodeRealm(positionPath)

	dummyOneAddr  = testutils.TestAddress("dummyOne")
	dummyOneRealm = std.NewUserRealm(dummyOneAddr)

	dummyTwoAddr  = testutils.TestAddress("dummyTwo")
	dummyTwoRealm = std.NewUserRealm(dummyTwoAddr)
)

func TestMint_dummyOneAddr(t *testing.T) {
	std.TestSetOrigCaller(dummyOneAddr)
	std.TestSetRealm(positionRealm)
	Mint(a2u(dummyOneAddr), tid(1))
	Mint(a2u(dummyOneAddr), tid(2))
	Mint(a2u(dummyOneAddr), tid(3))
}

func TestMint_dummyTwoAddr(t *testing.T) {
	std.TestSetOrigCaller(dummyTwoAddr)
	std.TestSetRealm(positionRealm)
	Mint(a2u(dummyTwoAddr), tid(4))
	Mint(a2u(dummyTwoAddr), tid(5))
	Mint(a2u(dummyTwoAddr), tid(6))
}

func TestSetTokenURILast(t *testing.T) {
	std.TestSetOrigCaller(dummyOneAddr)
	shouldEQ(t, len(userMinted), 2)
	shouldEQ(t, len(userMinted[dummyOneAddr]), 3)
	SetTokenURILast()

	shouldEQ(t, len(userMinted), 1)
	shouldEQ(t, len(userMinted[dummyOneAddr]), 0)
}

func TestTransferFrom(t *testing.T) {
	std.TestSetOrigCaller(dummyTwoAddr)
	std.TestSetRealm(dummyTwoRealm)

	// before transfer from, check owner
	shouldEQ(t, OwnerOf(tid(5)), dummyTwoAddr)

	TransferFrom(a2u(dummyTwoAddr), a2u(dummyOneAddr), tid(5))

	// after transfer from, check owner
	shouldEQ(t, OwnerOf(tid(5)), dummyOneAddr)

	// check SetTokenURILast not to panic
	SetTokenURILast()
}

// UTILs
func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func tid(id uint64) grc721.TokenID {
	return grc721.TokenID(ufmt.Sprintf("%d", id))
}

func shouldEQ(t *testing.T, got, want interface{}) {
	if got != want {
		t.Errorf("got %v, want %v", got, want)
	}
}
