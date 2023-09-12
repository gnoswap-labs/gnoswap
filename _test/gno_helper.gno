package tc

import (
	"std"
	"time"
)

// stdlibs
// https://github.com/gnolang/gno/blob/master/stdlibs/stdlibs.go
func GetHeight() int64 {
	return std.GetHeight()
}

func GetTimestamp() int64 {
	return time.Now().Unix()
}

func GetChainID() string {
	return std.GetChainID()
}

func GetOrigCaller() std.Address {
	return std.GetOrigCaller()
}

// derive pkg addr

// test
// https://github.com/gnolang/gno/blob/master/tests/imports.go

// XXX skip height
// skip timestamp (WIP in PR)
// XXX set orig caller
// set last caller (WIP in PR)
