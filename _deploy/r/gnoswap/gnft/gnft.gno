package gnft

import (
	"math/rand"
	"std"
	"time"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/users"

	"gno.land/r/gnoswap/v1/common"
)

var (
	admin std.Address = "g1q646ctzhvn60v492x8ucvyqnrj2w30cwh6efk5" // deployed position contract
	gnft              = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")
)

var userMinted = make(map[std.Address][]grc721.TokenID)

// Getters
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
	common.IsHalted()

	err := gnft.Approve(users.Resolve(user), tid)
	if err != nil {
		panic(err.Error())
	}
}

func SetApprovalForAll(user pusers.AddressOrName, approved bool) {
	common.IsHalted()

	err := gnft.SetApprovalForAll(users.Resolve(user), approved)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to pusers.AddressOrName, tid grc721.TokenID) {
	common.IsHalted()

	err := gnft.TransferFrom(users.Resolve(from), users.Resolve(to), tid)
	if err != nil {
		panic(err.Error())
	}
}

// Admin
func Mint(to pusers.AddressOrName, tid grc721.TokenID) grc721.TokenID {
	common.IsHalted()

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
	common.IsHalted()

	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	err := gnft.Burn(tid)
	if err != nil {
		panic(err.Error())
	}
}

func SetAdmin(newAdmin pusers.AddressOrName) {
	common.IsHalted()

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
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("gnft.gno__assertIsAdmin() || only admin(%s) can call this function, called from %s", admin.String(), address.String()),
		))
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
	common.IsHalted()

	// rand instance
	seed1 := uint64(time.Now().Unix() + int64(TotalSupply()))
	seed2 := uint64(time.Now().UnixNano() + int64(TotalSupply()))
	pcg := rand.NewPCG(seed1, seed2)
	r := rand.New(pcg)

	tokenURI := genImageURI(r)
	ok, _ := gnft.SetTokenURI(tid, grc721.TokenURI(tokenURI))
	if ok {
		prevAddr, prevRealm := getPrev()
		std.Emit(
			"SetTokenURI",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"lpTokenId", string(tid),
			"internal_tokenURI", tokenURI,
		)
	}
}

func SetTokenURILast() {
	common.IsHalted()

	// rand instance
	seed1 := uint64(time.Now().Unix())
	seed2 := uint64(time.Now().UnixNano())
	pcg := rand.NewPCG(seed1, seed2)
	r := rand.New(pcg)

	prev := std.PrevRealm()
	prevAddr := prev.Addr()
	usersNFT := userMinted[prevAddr]
	for _, tid := range usersNFT {
		tokenURI := genImageURI(r)

		ok, _ := gnft.SetTokenURI(tid, grc721.TokenURI(tokenURI))
		if ok {
			prevAddr, prevRealm := getPrev()
			std.Emit(
				"SetTokenURI",
				"prevAddr", prevAddr,
				"prevRealm", prevRealm,
				"lpTokenId", string(tid),
				"internal_tokenURI", tokenURI,
			)
		}
	}

	delete(userMinted, prevAddr)
}
