package gnft

import (
	"std"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v1/consts"
)

var (
	positionRealm = std.NewCodeRealm(consts.POSITION_PATH)

	dummyOneAddr  = testutils.TestAddress("dummyOne")
	dummyOneRealm = std.NewUserRealm(dummyOneAddr)

	dummyTwoAddr  = testutils.TestAddress("dummyTwo")
	dummyTwoRealm = std.NewUserRealm(dummyTwoAddr)
)

func TestMint(t *testing.T) {
	std.TestSetRealm(positionRealm)

	t.Run("first nft to dummyOne", func(t *testing.T) {
		tid := Mint(a2u(dummyOneAddr), tid(1))
		uassert.Equal(t, string(tid), "1")
	})

	t.Run("second nft to dummyOne", func(t *testing.T) {
		tid := Mint(a2u(dummyOneAddr), tid(2))
		uassert.Equal(t, string(tid), "2")
	})

	t.Run("third nft to dummyTwo", func(t *testing.T) {
		tid := Mint(a2u(dummyTwoAddr), tid(3))
		uassert.Equal(t, string(tid), "3")
	})
}

func TestSetTokenURILast(t *testing.T) {
	t.Run("inital check", func(t *testing.T) {
		uassert.Equal(t, len(userMinted), 2)
		uassert.Equal(t, len(userMinted[dummyOneAddr]), 2)
		uassert.Equal(t, len(userMinted[dummyTwoAddr]), 1)
	})

	t.Run("get token uri (nil should panic)", func(t *testing.T) {
		uassert.PanicsWithMessage(t,
			"invalid token id",
			func() {
				TokenURI(tid(1))
			},
		)
	})

	t.Run("set token uri last", func(t *testing.T) {
		std.TestSetRealm(dummyOneRealm)
		SetTokenURILast()
	})

	t.Run("get token uri", func(t *testing.T) {
		uassert.NotPanics(t, func() {
			TokenURI(tid(1))
		})
	})
}

func TestTransferFrom(t *testing.T) {
	std.TestSetRealm(dummyTwoRealm)

	t.Run("before transfer, check owner", func(t *testing.T) {
		uassert.Equal(t, OwnerOf(tid(3)), dummyTwoAddr)
	})

	t.Run("transfer from `two` to `one`", func(t *testing.T) {
		TransferFrom(a2u(dummyTwoAddr), a2u(dummyOneAddr), tid(3))
	})

	t.Run("after transfer, check owner", func(t *testing.T) {
		uassert.Equal(t, OwnerOf(tid(3)), dummyOneAddr)
	})

	t.Run("dummyOne can call SetTokenURI", func(t *testing.T) {
		std.TestSetRealm(dummyOneRealm)
		SetTokenURI(tid(5))
	})
}

func TestMetaGetter(t *testing.T) {
	t.Run("name", func(t *testing.T) {
		uassert.Equal(t, Name(), "GNOSWAP NFT")
	})

	t.Run("symbol", func(t *testing.T) {
		uassert.Equal(t, Symbol(), "GNFT")
	})
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func tid(id uint64) grc721.TokenID {
	return grc721.TokenID(ufmt.Sprintf("%d", id))
}
