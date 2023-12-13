package staker

import (
	"std"
	"time"
)

func GetTimestamp() int64 {
	return time.Now().Unix()
}

func GetHeight() int64 {
	return std.GetHeight()
}

func GetOrigPkgAddr() std.Address {
	return std.DerivePkgAddr("gno.land/r/demo/staker")
	// return std.GetOrigPkgAddr()
}

func GetOrigCaller() std.Address {
	return std.GetOrigCaller()
}

func PrevRealmAddr() std.Address {
	return std.PrevRealm().Addr()
}
