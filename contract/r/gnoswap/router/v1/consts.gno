package v1

var routerImplAddr address

func init(cur realm) {
	routerImplAddr = cur.Address()
}
