package router

import (
	"std"

	"gno.land/r/gnoswap/v2/consts"
)

func GetOrigPkgAddr() std.Address {
	return consts.ROUTER_ADDR
}
