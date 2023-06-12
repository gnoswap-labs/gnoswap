package staker

import (
	"std"
	"time"
)

// stdlibs
// https://github.com/gnolang/gno/blob/master/stdlibs/stdlibs.go
func GetTimestamp() bigint {
	return bigint(time.Now().Unix())
}

func GetHeight() int64 {
	return std.GetHeight()
}

func GetOrigPkgAddr() std.Address {
	return std.DerivePkgAddr("gno.land/r/staker")
	// return std.Address("g17rgsdnfxzza0sdfsdma37sdwxagsz378833ca4")
	// return std.GetOrigPkgAddr()
}

func GetOrigCaller() std.Address {
	return std.GetOrigCaller()
}
