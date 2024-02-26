package router

import (
	"std"
	"time"

	"gno.land/r/demo/consts"
)

func GetHeight() int64 {
	return std.GetHeight()
}

func GetTimestamp() int64 {
	return time.Now().Unix()
}

func GetOrigPkgAddr() std.Address {
	return consts.ROUTER_ADDR
}
