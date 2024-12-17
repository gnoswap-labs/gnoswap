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

const (
	errInvalidTokenId = "invalid token id"
)

var (
	positionAddr  = consts.POSITION_ADDR
	positionRealm = std.NewCodeRealm(consts.POSITION_PATH)

	addr01      = testutils.TestAddress("addr01")
	addr01Realm = std.NewUserRealm(addr01)

	addr02      = testutils.TestAddress("addr02")
	addr02Realm = std.NewUserRealm(addr02)
)

func TestMetadata(t *testing.T) {
	t.Run("name", func(t *testing.T) {
		uassert.Equal(t, "GNOSWAP NFT", Name())
	})

	t.Run("symbol", func(t *testing.T) {
		uassert.Equal(t, "GNFT", Symbol())
	})
}

func TestDefaultMethods(t *testing.T) {
	t.Run("total supply", func(t *testing.T) {
		uassert.Equal(t, uint64(0), TotalSupply())

		std.TestSetRealm(positionRealm)
		Mint(a2u(addr01), tid(1))

		uassert.Equal(t, uint64(1), TotalSupply())
	})

	t.Run("BalanceOf(addr01)", func(t *testing.T) {
		uassert.Equal(t, uint64(1), BalanceOf(a2u(addr01)))
	})

	t.Run("BalanceOf(addr02)", func(t *testing.T) {
		uassert.Equal(t, uint64(0), BalanceOf(a2u(addr02)))
	})

	t.Run("OwnerOf(1)", func(t *testing.T) {
		uassert.Equal(t, addr01, OwnerOf(tid(1)))
	})

	t.Run("OwnerOf(2)", func(t *testing.T) {
		uassert.PanicsWithMessage(t, errInvalidTokenId, func() {
			OwnerOf(tid(2))
		})
	})
}

func TestIsApprovedForAll(t *testing.T) {
	t.Run("IsApprovedForAll(addr01, addr02)", func(t *testing.T) {
		uassert.False(t, IsApprovedForAll(a2u(addr01), a2u(addr02)))

		std.TestSetRealm(addr01Realm)
		SetApprovalForAll(a2u(addr02), true)

		uassert.True(t, IsApprovedForAll(a2u(addr01), a2u(addr02)))
	})
}

func TestGetApproved(t *testing.T) {
	t.Run("GetApproved(1)", func(t *testing.T) {
		addr, approved := GetApproved(tid(1))
		uassert.Equal(t, std.Address(""), addr)
		uassert.False(t, approved)

		std.TestSetRealm(addr01Realm)
		Approve(a2u(addr02), tid(1))

		addr, approved = GetApproved(tid(1))
		uassert.Equal(t, addr02, addr)
		uassert.True(t, approved)
	})
}

func TestTransferFrom(t *testing.T) {
	resetObject(t)

	t.Run("can not transfer from non-existent token id", func(t *testing.T) {
		uassert.PanicsWithMessage(t, "caller is not token owner or approved", func() {
			TransferFrom(a2u(addr01), a2u(addr02), tid(1))
		})
	})

	t.Run("can not transfer token owned by other user", func(t *testing.T) {
		uassert.PanicsWithMessage(t, "caller is not token owner or approved", func() {
			std.TestSetRealm(positionRealm)
			tokenId := Mint(a2u(addr01), tid(1))
			TransferFrom(a2u(addr02), a2u(addr01), tid(1))
		})
	})

	t.Run("transfer token to addr02", func(t *testing.T) {
		std.TestSetRealm(addr01Realm)
		TransferFrom(a2u(addr01), a2u(addr02), tid(1))
	})
}

func TestMint(t *testing.T) {
	resetObject(t)

	t.Run("can not mint if caller is not owner", func(t *testing.T) {
		uassert.PanicsWithMessage(t, "ownable: caller is not owner", func() {
			Mint(a2u(addr01), tid(1))
		})
	})

	std.TestSetRealm(positionRealm)
	t.Run("mint first nft to addr01", func(t *testing.T) {
		tokenId := Mint(a2u(addr01), tid(1))
		uassert.Equal(t, "1", string(tokenId))
	})

	t.Run("can not mint existing token id", func(t *testing.T) {
		uassert.PanicsWithMessage(t, "token id already exists", func() {
			Mint(a2u(addr01), tid(1))
		})
	})

	t.Run("mint second nft to addr02", func(t *testing.T) {
		tokenId := Mint(a2u(addr02), tid(2))
		uassert.Equal(t, "2", string(tokenId))
	})
}

func TestBurn(t *testing.T) {
	t.Run("can not burn if caller is not owner", func(t *testing.T) {
		uassert.PanicsWithMessage(t, "ownable: caller is not owner", func() {
			Burn(tid(2))
		})
	})

	std.TestSetRealm(positionRealm)
	t.Run("can not burn non-existent token id", func(t *testing.T) {
		uassert.PanicsWithMessage(t, errInvalidTokenId, func() {
			Burn(tid(3))
		})
	})

	t.Run("burn second nft", func(t *testing.T) {
		Burn(tid(2))
		uassert.Equal(t, uint64(1), TotalSupply())
	})
}

func TestSetTokenURI(t *testing.T) {
	t.Run("can not set token uri if caller is not owner", func(t *testing.T) {
		uassert.ErrorContains(t, SetTokenURI(tid(1)), "caller is not token owner")
	})

	t.Run("can not set token uri if token id is not minted", func(t *testing.T) {
		uassert.ErrorContains(t, SetTokenURI(tid(2)), errInvalidTokenId)
	})

	resetObject(t)
	std.TestSetRealm(positionRealm)
	Mint(a2u(addr01), tid(1))
	Mint(a2u(addr01), tid(2))

	t.Run("set token uri", func(t *testing.T) {
		std.TestSetRealm(addr01Realm)
		err := SetTokenURI(tid(1))
		uassert.NoError(t, err)
	})
}

func TestTokenURI(t *testing.T) {
	t.Run("can not get token uri if token id is not minted", func(t *testing.T) {
		uassert.PanicsWithMessage(t, errInvalidTokenId, func() {
			TokenURI(tid(2))
		})
	})

	t.Run("can not get token uri if token id is minted, but not set token uri", func(t *testing.T) {
		uassert.PanicsWithMessage(t, errInvalidTokenId, func() {
			TokenURI(tid(2))
		})
	})

	t.Run("get token uri", func(t *testing.T) {
		uassert.NotEmpty(t, TokenURI(tid(1)))
	})
}

func TestSetTokenURILast(t *testing.T) {
	resetObject(t)
	std.TestSetRealm(positionRealm)
	Mint(a2u(addr01), tid(1))
	Mint(a2u(addr01), tid(2))

	t.Run("set token uri last", func(t *testing.T) {
		std.TestSetRealm(addr01Realm)
		SetTokenURILast()
	})

	t.Run("token uri(1)", func(t *testing.T) {
		uassert.NotEmpty(t, TokenURI(tid(1)))
	})

	t.Run("token uri(2)", func(t *testing.T) {
		uassert.NotEmpty(t, TokenURI(tid(2)))
	})
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func tid(id uint64) grc721.TokenID {
	return grc721.TokenID(ufmt.Sprintf("%d", id))
}

func resetObject(t *testing.T) {
	t.Helper()

	gnft = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")
}
