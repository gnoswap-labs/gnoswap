package router

import (
	"std"

	"gno.land/r/gnoswap/consts"
)

func GetOrigPkgAddr() std.Address {
	return consts.ROUTER_ADDR
}
