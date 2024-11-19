package community_pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gns"
)

var (
	dummyAddr = testutils.TestAddress("dummyAddr")
)

func TestTransferTokenByAdmin(t *testing.T) {
	t.Run("panic if not admin", func(t *testing.T) {
		uassert.PanicsWithMessage(
			t,
			"[GNOSWAP-COMMUNITY_POOL-001] caller has no permission || community_pool.gno__TransferTokenByAdmin() || only admin(g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c) can transfer token, called from g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm",
			func() {
				TransferTokenByAdmin(consts.GNS_PATH, dummyAddr, 1000)
			},
		)
	})

	t.Run("panic if not registered", func(t *testing.T) {
		uassert.PanicsWithMessage(
			t,
			"[GNOSWAP-COMMUNITY_POOL-002] not registered || community_pool.gno__transferToken() || token(gno.land/r/demo/nope) not registered",
			func() {
				std.TestSetRealm(adminRealm)
				TransferTokenByAdmin("gno.land/r/demo/nope", dummyAddr, 1000)
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
			"[GNOSWAP-COMMUNITY_POOL-001] caller has no permission || community_pool.gno__TransferToken() || only governance(g17s8w2ve7k85fwfnrk59lmlhthkjdted8whvqxd) can transfer token, called from g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm",
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
