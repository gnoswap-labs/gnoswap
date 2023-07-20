package gnoswap

import (
	"std"
	"time"
)

// stdlibs
// https://github.com/gnolang/gno/blob/master/stdlibs/stdlibs.go
func GetHeight() int64 {
	return std.GetHeight()
}

func GetTimestamp() bigint {
	return bigint(time.Now().Unix())
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

// test
// https://github.com/gnolang/gno/blob/master/tests/imports.go

// XXX skip height
// skip timestamp (WIP in PR)
// XXX set orig caller
// set last caller (WIP in PR)
