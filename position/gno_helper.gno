package position

import (
	"std"
	"time"

	"gno.land/r/demo/consts"
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
	return consts.POSITION_ADDR
	// return std.GetOrigPkgAddr()
}

func GetOrigCaller() std.Address {
	return std.GetOrigCaller()
}

func PrevRealmAddr() std.Address {
	return std.PrevRealm().Addr()
}
