package staker

import (
	"std"
)

// stdlibs
// https://github.com/gnolang/gno/blob/master/stdlibs/stdlibs.go
func GetTimestamp() bigint { // will be deprecate
	return bigint(std.GetTimestamp())
}

func GetOrigPkgAddr() std.Address {
	return std.DerivePkgAddr("gno.land/r/staker")
	// return std.Address("g17rgsdnfxzza0sdfsdma37sdwxagsz378833ca4")
	// return std.GetOrigPkgAddr()
}

func GetOrigCaller() std.Address {
	return std.GetOrigCaller()
}