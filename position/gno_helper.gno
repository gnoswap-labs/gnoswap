package position

import (
	"std"
)

// stdlibs
// https://github.com/gnolang/gno/blob/master/stdlibs/stdlibs.go
func GetChainID() string {
	return std.GetChainID()
}

func GetHeight() int64 {
	return std.GetHeight()
}

func GetTimestamp() bigint { // will be deprecate
	return bigint(std.GetTimestamp())
}

func GetOrigPkgAddr() std.Address {
	return std.DerivePkgAddr("gno.land/r/position")
	// return std.GetOrigPkgAddr()
}

func GetOrigCaller() std.Address {
	return std.GetOrigCaller()
}