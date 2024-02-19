package gnft

import (
	"std"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"
)

var (
	// position deployed
	// std.DerivePkgAddr("gno.land/r/demo/position")
	admin std.Address = "g10wwa53xgu4397kvzz7akxar9370zjdpwux5th9"
	nft               = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")
)

func init() {
	// mintNNFT(admin, 10)                                     // @administrator (10)
	// mintNNFT("g1var589z07ppjsjd24ukm4uguzwdt0tw7g47cgm", 5) // @hariom (5)
}

func mintNNFT(owner std.Address, n uint64) {
	count := nft.TokenCount()
	for i := count; i < count+n; i++ {
		tid := grc721.TokenID(ufmt.Sprintf("%d", i))
		nft.Mint(owner, tid)
	}
}

// Getters

func BalanceOf(user users.AddressOrName) uint64 {
	balance, err := nft.BalanceOf(user.Resolve())
	if err != nil {
		panic(err.Error())
	}

	return balance
}

func OwnerOf(tid grc721.TokenID) std.Address {
	owner, err := nft.OwnerOf(tid)
	if err != nil {
		panic(err.Error())
	}

	return owner
}

func IsApprovedForAll(owner, user users.AddressOrName) bool {
	return nft.IsApprovedForAll(owner.Resolve(), user.Resolve())
}

func GetApproved(tid grc721.TokenID) (std.Address, bool) {
	addr, err := nft.GetApproved(tid)
	if err != nil {
		return "", false
		// panic(err.Error())
	}

	return addr, true
}

// Setters

func Approve(user users.AddressOrName, tid grc721.TokenID) {
	err := nft.Approve(user.Resolve(), tid)
	if err != nil {
		panic(err.Error())
	}
}

func SetApprovalForAll(user users.AddressOrName, approved bool) {
	err := nft.SetApprovalForAll(user.Resolve(), approved)
	if err != nil {
		panic(err.Error())
	}
}

func TransferFrom(from, to users.AddressOrName, tid grc721.TokenID) {
	err := nft.TransferFrom(from.Resolve(), to.Resolve(), tid)
	if err != nil {
		panic(err.Error())
	}
}

// Admin

func Mint(to users.AddressOrName, tid grc721.TokenID) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	err := nft.Mint(to.Resolve(), tid)
	if err != nil {
		panic(err.Error())
	}
}

func Burn(tid grc721.TokenID) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	err := nft.Burn(tid)
	if err != nil {
		panic(err.Error())
	}
}

func SetAdmin(newAdmin users.AddressOrName) {
	// caller := std.GetOrigCaller()
	caller := std.PrevRealm().Addr()
	assertIsAdmin(caller)
	admin = newAdmin.Resolve()
}

// Render
func Render(path string) string {
	switch {
	case path == "":
		return nft.RenderHome()
	default:
		return "404\n"
	}
}

// util
func assertIsAdmin(address std.Address) {
	if address != admin {
		panic("restricted access")
	}
}

func TotalSupply() uint64 {
	return nft.TokenCount()
}

func Exists(tid grc721.TokenID) bool {
	_, err := nft.OwnerOf(tid)
	if err != nil {
		return false
	}

	return true
}
