package position

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gnft"
)

func exists(tokenId uint64) bool {
	// non exist tokenId will panic
	// use defer to catch the panic
	defer func() {
		if err := recover(); err != nil {
			panic(ufmt.Sprintf("[POSITION] nft_helper.gno__exists() || tokenId(%s) doesn't exist", tokenId))
		}
	}()

	// exists method in grc721 is private
	// we don't have much choice but to use ownerOf
	owner := gnft.OwnerOf(tid(tokenId))
	if owner == consts.ZERO_ADDRESS {
		panic(ufmt.Sprintf("[POSITION] nft_helper.gno__exists() || tokenId(%s) doesn't exist__ZeroAddressOwner", tokenId))
		return false
	}

	return true
}

// Error handling isn't necessary here
func isApprovedOrOwner(addr std.Address, tokenId uint64) bool {
	tid := tid(tokenId)

	// check whether token exists
	if !exists(tokenId) {
		panic(ufmt.Sprintf("[POSITION] nft_helper.gno__isApprovedOrOwner() || tokenId(%s) doesn't exist", tokenId))
	}

	// check owner first
	owner := gnft.OwnerOf(tid)
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
	operator, ok := gnft.GetApproved(tid)
	if ok && addr == operator {
		return true
	}

	return false
}
