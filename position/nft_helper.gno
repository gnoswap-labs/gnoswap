package position

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/p/demo/grc/grc721"
	nft "gno.land/r/gnft"
)

func nftBalanceOf(addr std.Address) bigint {
	return bigint(nft.BalanceOf(a2u(addr)))
}

func exists(tokenId bigint) bool {
	// non exist tokenId will panic
	// use defer to catch the panic
	defer func() {
		if err := recover(); err != nil {
			panic(ufmt.Sprintf("[POSITION] nft_helper.gno__exists() || tokenId(%s) doesn't exist", tokenId))
		}
	}()

	// exists method in grc721 is private
	// we don't have much choice but to use ownerOf
	owner := nft.OwnerOf(grc721.TokenID(string(tokenId)))
	if owner == nil {
		panic(ufmt.Sprintf("[POSITION] nft_helper.gno__exists() || tokenId(%s) doesn't exist__NilOwner", tokenId))
		return false
	}

	if owner == ZERO_ADDRESS {
		panic(ufmt.Sprintf("[POSITION] nft_helper.gno__exists() || tokenId(%s) doesn't exist__ZeroAddressOwner", tokenId))
		return false
	}

	return true
}

// Error handling isn't necessary here
func isApprovedOrOwner(addr std.Address, tokenId bigint) bool {
	tid := grc721.TokenID(tokenId)

	// check whether token exists
	if !exists(tokenId) {
		panic(ufmt.Sprintf("[POSITION] nft_helper.gno__isApprovedOrOwner() || tokenId(%s) doesn't exist", tokenId))
	}

	// check owner first
	owner := nft.OwnerOf(tid)
	if addr == owner {
		return true
	}

	// if not owner, check whether approved in position contract
	position, exist := positions[tokenId]
	if exist {
		if addr == position.operator {
			return true
		}
	}

	// if not owner, check whether approved in actual grc721 contract
	operator, err := nft.GetApproved(tid)
	if err != nil {
		return false
	}

	if addr == operator {
		return true
	}

	return false
}
