package gnft

import (
	"math/rand"
	"std"
	"time"

	"gno.land/p/demo/grc/grc721"
	"gno.land/r/demo/users"

	pusers "gno.land/p/demo/users"
)

var (
	admin std.Address = "g1vsm68lq9cpn7x507s6gh59anmx86kxfhzyszu2" // deployed position contract
	gnft              = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")
)

var userMinted = make(map[std.Address][]grc721.TokenID)

func init() {}

// Getters
func TotalSupply() uint64 {
	return gnft.TokenCount()
}

func GetTokenURI(tid grc721.TokenID) string {
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
	if err != nil {
		panic(err.Error())
	}

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

// Setters

func Approve(user pusers.AddressOrName, tid grc721.TokenID) {
	err := gnft.Approve(users.Resolve(user), tid)
	if err != nil {
		panic(err.Error())
	}
}

func SetApprovalForAll(user pusers.AddressOrName, approved bool) {
	err := gnft.SetApprovalForAll(users.Resolve(user), approved)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to pusers.AddressOrName, tid grc721.TokenID) {
	err := gnft.TransferFrom(users.Resolve(from), users.Resolve(to), tid)
	if err != nil {
		panic(err.Error())
	}
}

// Admin
func Mint(to pusers.AddressOrName, tid grc721.TokenID) grc721.TokenID {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)

	err := gnft.Mint(users.Resolve(to), tid)
	if err != nil {
		panic(err.Error())
	}

	userMinted[users.Resolve(to)] = append(userMinted[users.Resolve(to)], tid)
	return tid
}

func Burn(tid grc721.TokenID) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	err := gnft.Burn(tid)
	if err != nil {
		panic(err.Error())
	}
}

func SetAdmin(newAdmin pusers.AddressOrName) {
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	admin = users.Resolve(newAdmin)
}

// Render

func Render(path string) string {
	switch {
	case path == "":
		return gnft.RenderHome()
	default:
		return "404\n"
	}
}

// Util
func assertIsAdmin(address std.Address) {
	if address != admin {
		panic("gnft_assertIsAdmin_restricted access")
	}
}

func Exists(tid grc721.TokenID) bool {
	_, err := gnft.OwnerOf(tid)
	if err != nil {
		return false
	}

	return true
}

func SetTokenURI(tid grc721.TokenID) {
	// rand instance
	seed1 := uint64(time.Now().Unix())
	seed2 := uint64(time.Now().UnixNano())
	pcg := rand.NewPCG(seed1, seed2)
	r := rand.New(pcg)

	tokenURI := genImageURI(r)

	ok, err := gnft.SetTokenURI(tid, grc721.TokenURI(tokenURI))
	if !ok {
		panic(err.Error())
	}

	std.Emit(
		"GNOSWAP",
		"m_origCaller", std.GetOrigCaller().String(),
		"m_prevRealm", std.PrevRealm().PkgPath(),
		"p_tokenId", string(tid),
		"tokenURI", tokenURI,
		"SetTokenURI", "SetTokenURI",
	)
}

func SetTokenURILast() {
	origCaller := std.GetOrigCaller()

	// rand instance
	seed1 := uint64(time.Now().Unix())
	seed2 := uint64(time.Now().UnixNano())
	pcg := rand.NewPCG(seed1, seed2)
	r := rand.New(pcg)

	usersNFT := userMinted[origCaller]
	for _, tid := range usersNFT {
		tokenURI := genImageURI(r)

		ok, err := gnft.SetTokenURI(tid, grc721.TokenURI(tokenURI))
		if !ok {
			panic(err.Error())
		}

		std.Emit(
			"GNOSWAP",
			"m_origCaller", std.GetOrigCaller().String(),
			"m_prevRealm", std.PrevRealm().PkgPath(),
			"p_tokenId", string(tid),
			"tokenURI", tokenURI,
			"SetTokenURILast", "SetTokenURILast",
		)
	}

	delete(userMinted, origCaller)
}
