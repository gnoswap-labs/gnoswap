package router

import (
	"std"

	"gno.land/r/gnoswap/v1/consts"
)

func GetOrigPkgAddr() std.Address {
	return consts.ROUTER_ADDR
}
