package community_pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"
)

var (
	dummyAddr = testutils.TestAddress("dummyAddr")
)

func init() {
	InitManual()
}

func TestTransferTokenByAdmin(t *testing.T) {
	t.Run("panic if not admin", func(t *testing.T) {
		uassert.PanicsWithMessage(
			t,
			"[COMMUNITY_POOL] community_pool.gno__TransferTokenByAdmin() || only admin(g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c) can transfer token, called from g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm",
			func() {
				TransferTokenByAdmin(consts.GNS_PATH, dummyAddr, 1000)
			},
		)
	})

	t.Run("success if admin", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		std.TestSetRealm(adminRealm)
		gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), 1)

		TransferTokenByAdmin(consts.GNS_PATH, dummyAddr, 1)
	})
}

func TestTransferToken(t *testing.T) {
	t.Run("panic if not governance", func(t *testing.T) {
		uassert.PanicsWithMessage(
			t,
			"[COMMUNITY_POOL] community_pool.gno__TransferToken() || only governance(g1eudq5dvx9sem5ascp0etlpk3kpxylz8kcy8cf5) can transfer token, called from g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm",
			func() {
				TransferToken(consts.GNS_PATH, dummyAddr, 1)
			},
		)
	})

	t.Run("success if governance", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		std.TestSetRealm(adminRealm)
		gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), 1)

		govRealm := std.NewUserRealm(consts.GOV_GOVERNANCE_ADDR)
		std.TestSetRealm(govRealm)
		TransferToken(consts.GNS_PATH, dummyAddr, 1)
	})
}
