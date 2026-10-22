package router

const routerProxyPkgPath = "gno.land/r/gnoswap/router"

var routerImplAddr address

func init(cur realm) {
	routerImplAddr = cur.Address()
}
