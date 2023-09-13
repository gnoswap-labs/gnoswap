package pool

import (
	"std"
	"time"
)

func GetHeight() int64 {
	return std.GetHeight()
}

func GetTimestamp() int64 {
	return time.Now().Unix()
}

func GetChainID() string {
	return std.GetChainID()
}

func GetOrigPkgAddr() std.Address {
	return std.DerivePkgAddr("gno.land/r/pool")
	// return std.GetOrigPkgAddr()
}

func GetOrigCaller() std.Address {
	return std.GetOrigCaller()
}

func PrevRealmAddr() std.Address {
	return std.PrevRealm().Addr()
}

func PrevRealmPath() string {
	return std.PrevRealm().PkgPath()
}

func PrevRealm() std.Realm {
	return std.PrevRealm()
}
