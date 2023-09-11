package gnoswap

import (
	"std"
	"time"
)

func GetHeight() uint64 {
	return uint64(std.GetHeight()) // origin return int64
}

func GetTimestamp() uint64 {
	return uint64(time.Now().Unix()) // origin return int64
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
