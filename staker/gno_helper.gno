package staker

import (
	"std"
	"time"

	"gno.land/r/demo/consts"
)

func GetTimestamp() int64 {
	return time.Now().Unix()
}

func GetHeight() int64 {
	return std.GetHeight()
}

func GetOrigPkgAddr() std.Address {
	return consts.STAKER_ADDR
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
