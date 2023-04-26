package liquidity

import (
	"std"
	"gno.land/p/demo/grc/grc721"

	nft "gno.land/r/foo721"
)

func TokenURI(tokenId string) string {
	require(Exists(tokenId), "Invalid token ID")
	return "TODO_THIS_IS_TOKEN_URI"
	// return INonfungibleTokenPositionDescriptor(_tokenDescriptor).tokenURI(this, tokenId);
}

func NFTBalanceOf(addr std.Address) bigint {
	return bigint(nft.BalanceOf(a2u(addr)))
}

func Exists(tokenId string) bool {
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

	// check owner first
	owner := nft.OwnerOf(tid)
	if addr == owner {
		return true
	}
		
	// if not owner, check whether approved
	operator, err := nft.GetApproved(tid)
	if err != nil {
		return false
	}

	if addr == operator {
		return true
	}
	
	return false
}