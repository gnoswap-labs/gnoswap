package position

import (
	"std"
	"time"
)

func GetChainID() string {
	return std.GetChainID()
}

func GetHeight() int64 {
	return std.GetHeight()
}

func GetTimestamp() int64 {
	return time.Now().Unix()
}

func GetOrigPkgAddr() std.Address {
	return std.DerivePkgAddr("gno.land/r/demo/position")
	// return std.GetOrigPkgAddr()
}

func GetOrigCaller() std.Address {
	return std.GetOrigCaller()
}

func PrevRealmAddr() std.Address {
	return std.PrevRealm().Addr()
}
