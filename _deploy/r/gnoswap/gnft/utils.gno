package gnft

import (
	"std"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"
)

func getPrevAsString() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func tid(id uint64) grc721.TokenID {
	return grc721.TokenID(ufmt.Sprintf("%d", id))
}

func Exists(tid grc721.TokenID) bool {
	_, err := gnft.OwnerOf(tid)
	if err != nil {
		return false
	}

	return true
}
