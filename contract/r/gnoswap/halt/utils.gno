package halt

import (
	"std"
)

// getPrevRealm returns object of the previous realm.
func getPrevRealm() std.Realm {
	return std.PrevRealm()
}

// getPrevAddr returns the address of the previous realm.
func getPrevAddr() std.Address {
	return std.PrevRealm().Addr()
}

// getPrevAsString returns the address and package path of the previous realm.
func getPrevAsString() (string, string) {
	prev := getPrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}
