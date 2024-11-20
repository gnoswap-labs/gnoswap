package community_pool

import (
	"std"

	"gno.land/r/gnoswap/v1/consts"
)

var (
	admin std.Address = consts.ADMIN

	fooPath string = "gno.land/r/onbloc/foo"
	barPath string = "gno.land/r/onbloc/bar"
	bazPath string = "gno.land/r/onbloc/baz"
	quxPath string = "gno.land/r/onbloc/qux"

	oblPath string = "gno.land/r/onbloc/obl"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	maxApprove uint64 = 18446744073709551615
)

// Realms to mock frames
var (
	adminRealm = std.NewUserRealm(admin)
	posRealm   = std.NewCodeRealm(consts.POSITION_PATH)
	rouRealm   = std.NewCodeRealm(consts.ROUTER_PATH)
)
