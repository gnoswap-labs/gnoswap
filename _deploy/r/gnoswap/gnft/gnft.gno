package gnft

import (
	"math/rand"
	"std"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/users"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

var (
	gnft  = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")
	owner = ownable.NewWithAddress(consts.POSITION_ADDR) // deployed position contract
)

var (
	tokensToSetUri = avl.NewTree()
)

func Name() string {
	return gnft.Name()
}

func Symbol() string {
	return gnft.Symbol()
}

func TotalSupply() uint64 {
	return gnft.TokenCount()
}

func TokenURI(tid grc721.TokenID) string {
	uri, err := gnft.TokenURI(tid)
	if err != nil {
		panic(err.Error())
	}

	return string(uri)
}

func BalanceOf(user pusers.AddressOrName) uint64 {
	balance, err := gnft.BalanceOf(users.Resolve(user))
	if err != nil {
		panic(err.Error())
	}

	return balance
}

func OwnerOf(tid grc721.TokenID) std.Address {
	owner, err := gnft.OwnerOf(tid)
	checkErr(err)

	return owner
}

func IsApprovedForAll(owner, user pusers.AddressOrName) bool {
	return gnft.IsApprovedForAll(users.Resolve(owner), users.Resolve(user))
}

func GetApproved(tid grc721.TokenID) (std.Address, bool) {
	addr, err := gnft.GetApproved(tid)
	if err != nil {
		return "", false
	}

	return addr, true
}

func Approve(user pusers.AddressOrName, tid grc721.TokenID) {
	common.IsHalted()

	err := gnft.Approve(users.Resolve(user), tid)
	if err != nil {
		panic(err.Error())
	}
}

func SetApprovalForAll(user pusers.AddressOrName, approved bool) {
	common.IsHalted()
	checkErr(gnft.SetApprovalForAll(users.Resolve(user), approved))
}

func TransferFrom(from, to pusers.AddressOrName, tid grc721.TokenID) {
	common.IsHalted()
	checkErr(gnft.TransferFrom(users.Resolve(from), users.Resolve(to), tid))
}

func Mint(to pusers.AddressOrName, tid grc721.TokenID) grc721.TokenID {
	owner.AssertCallerIsOwner()
	common.IsHalted()

	checkErr(gnft.Mint(users.Resolve(to), tid))

	toAddr := users.Resolve(to)
	appendTokensToSetUri(toAddr, tid)
	return tid
}

func Burn(tid grc721.TokenID) {
	owner.AssertCallerIsOwner()
	common.IsHalted()

	checkErr(gnft.Burn(tid))
}

func Render(path string) string {
	switch {
	case path == "":
		return gnft.RenderHome()
	default:
		return "404\n"
	}
}

func SetTokenURI(tid grc721.TokenID) error {
	common.IsHalted()

	// rand instance
	seed1 := uint64(time.Now().Unix() + int64(TotalSupply()))
	seed2 := uint64(time.Now().UnixNano() + int64(TotalSupply()))
	pcg := rand.NewPCG(seed1, seed2)
	r := rand.New(pcg)

	tokenURI := genImageURI(r)
	ok, err := gnft.SetTokenURI(tid, grc721.TokenURI(tokenURI))
	if err != nil {
		return err
	}

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetTokenURI",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"lpTokenId", string(tid),
		"internal_tokenURI", tokenURI,
	)

	return nil
}

func SetTokenURILast() error {
	common.IsHalted()

	// rand instance
	seed1 := uint64(time.Now().Unix())
	seed2 := uint64(time.Now().UnixNano())
	pcg := rand.NewPCG(seed1, seed2)
	r := rand.New(pcg)

	prev := std.PrevRealm()
	prevAddr := prev.Addr()
	tokensToSetUri, _ := getTokensToSetUri(prevAddr)
	for _, tid := range tokensToSetUri {
		tokenURI := genImageURI(r)

		ok, err := gnft.SetTokenURI(tid, grc721.TokenURI(tokenURI))
		if err != nil {
			return err
		}

		deleteTokenFromTokensToSetUri(prevAddr, tid)

		prevAddr, prevRealm := getPrev()
		std.Emit(
			"SetTokenURI",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"lpTokenId", string(tid),
			"internal_tokenURI", tokenURI,
		)
	}

	return nil
}

func getTokensToSetUri(addr std.Address) ([]grc721.TokenID, bool) {
	iTokens, exists := tokensToSetUri.Get(addr.String())
	if !exists {
		return []grc721.TokenID{}, false
	}

	return iTokens.([]grc721.TokenID), true
}

func mustGetTokensToSetUri(addr std.Address) []grc721.TokenID {
	tokens, exists := getTokensToSetUri(addr)
	if !exists {
		panic(ufmt.Sprintf("user %s has no minted nft tokens", addr.String()))
	}

	return tokens
}

func appendTokensToSetUri(addr std.Address, tid grc721.TokenID) {
	prevTokenList, _ := getTokensToSetUri(addr)
	prevTokenList = append(prevTokenList, tid)
	tokensToSetUri.Set(addr.String(), prevTokenList)
}

func deleteTokenFromTokensToSetUri(addr std.Address, tid grc721.TokenID) {
	tokens := mustGetTokensToSetUri(addr)
	for i, token := range tokens {
		if token == tid {
			tokens = append(tokens[:i], tokens[i+1:]...)
			break
		}
	}
}

func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}
