package router

var routerImplAddr address

// init records this package's realm address for callback authorization checks.
//
// Parameters:
//   - cur: Current realm context supplied by the runtime during package initialization.
func init(cur realm) {
	routerImplAddr = cur.Address()
}
