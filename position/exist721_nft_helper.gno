package position

import (
	"std"

	"gno.land/p/demo/grc/grc721"
	nft "gno.land/r/gnft"
)

// func TokenURI(tokenId string) string {
// 	require(Exists(tokenId), "Invalid token ID")
// 	return "TODO_THIS_IS_TOKEN_URI"
// 	// return INonfungibleTokenPositionDescriptor(_tokenDescriptor).tokenURI(this, tokenId);
// }

func NFTBalanceOf(addr std.Address) bigint {
	return bigint(nft.BalanceOf(a2u(addr)))
}

func Exists(tokenId string) bool {
	// non exist tokenId will panic
	// use defer to catch the panic
	defer func() {
		if err := recover(); err != nil {
			panic("Invalid token ID")
		}
	}()

	// exists method in grc721 is private
	// we don't have much choice but to use ownerOf
	owner := nft.OwnerOf(grc721.TokenID(tokenId))
	if owner == nil {
		panic("NIL OWNER")
		return false
	}

	if owner == zeroAddress {
		panic("ZERO ADDRESS OWNER")
		return false
	}

	return true
}

// Error handling isn't necessary here
func isApprovedOrOwner(addr std.Address, tokenId string) bool {
	tid := grc721.TokenID(tokenId)

	// check whether token exists
	if !Exists(tokenId) {
		panic("Invalid token ID")
	}

	// check owner first
	owner := nft.OwnerOf(tid)
	if addr == owner {
		return true
	}

	// if not owner, check whether approved in position contract
	_position, ok := positions.Get(tokenId)
	if ok {
		position := _position.(Position)
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
