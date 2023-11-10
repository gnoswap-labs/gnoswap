package router

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

func GetOrigPkgAddr() std.Address {
	return std.DerivePkgAddr("gno.land/r/router")
}
