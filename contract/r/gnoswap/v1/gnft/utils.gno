package gnft

import (
	"std"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"
)

// getPrevAsString returns the address and package path of the previous realm.
func getPrevAsString() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

// getPrevAddr returns the address of the previous realm.
func getPrevAddr() std.Address {
	return std.PrevRealm().Addr()
}

// a2u converts std.Address to pusers.AddressOrName.
// pusers is a package that contains the user-related functions.
//
// Input:
//   - addr: the address to convert
//
// Output:
//   - pusers.AddressOrName: the converted address
func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

// tid converts uint64 to grc721.TokenID.
//
// Input:
//   - id: the uint64 to convert
//
// Output:
//   - grc721.TokenID: the converted token ID
func tid(id uint64) grc721.TokenID {
	return grc721.TokenID(ufmt.Sprintf("%d", id))
}

// Exists checks if a token ID exists.
//
// Input:
//   - tid: the token ID to check
//
// Output:
//   - bool: true if the token ID exists, false otherwise
func Exists(tid grc721.TokenID) bool {
	_, err := gnft.OwnerOf(tid)
	if err != nil {
		return false
	}

	return true
}
