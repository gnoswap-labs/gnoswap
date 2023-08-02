package staker

import (
	"std"
	"time"
)

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

func PrevRealmAddr() std.Address {
	return std.PrevRealm().Addr()
}
