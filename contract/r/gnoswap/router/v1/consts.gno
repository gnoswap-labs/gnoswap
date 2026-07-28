package router

var routerImplAddr address

func init(cur realm) {
	routerImplAddr = cur.Address()
}
