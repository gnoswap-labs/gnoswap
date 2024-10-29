// PKGPATH: gno.land/r/gnoswap/v2/community_pool_test
package community_pool_test

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v2/consts"
	"gno.land/r/gnoswap/v2/gns"

	cp "gno.land/r/gnoswap/v2/community_pool"
)

var t *testing.T

func init() {
	cp.InitManual()
}

func main() {
	adminRealm := std.NewUserRealm(consts.ADMIN)
	std.TestSetRealm(adminRealm)

	gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), 1000)
	uassert.Equal(t, uint64(1000), gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR)))

	sendTarget := testutils.TestAddress("sendTarget")
	cp.TransferTokenByAdmin(consts.GNS_PATH, sendTarget, 900)

	uassert.Equal(t, uint64(100), gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR)))
	uassert.Equal(t, uint64(900), gns.BalanceOf(a2u(sendTarget)))
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}
