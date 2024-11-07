package emission

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v2/consts"
)

func TestChangeDistributionPctByAdmin(t *testing.T) {
	t.Run("panic if not admin", func(t *testing.T) {
		uassert.PanicsWithMessage(
			t,
			"only admin can change distribution percentages",
			func() {
				ChangeDistributionPctByAdmin(0, 0, 0, 0, 0, 0, 0, 0)
			},
		)
	})

	t.Run("panic if sum of percentages is not 100%", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		std.TestSetRealm(adminRealm)

		uassert.PanicsWithMessage(
			t,
			"sum of all pct should be 100% (10000 bps), got 9999",
			func() {
				ChangeDistributionPctByAdmin(1, 0, 2, 0, 3, 0, 4, 9999)
			},
		)
	})

	t.Run("panic if target is invliad", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		std.TestSetRealm(adminRealm)

		uassert.PanicsWithMessage(
			t,
			"invalid target",
			func() {
				ChangeDistributionPctByAdmin(9, 10000, 2, 0, 3, 0, 4, 0)
			},
		)
	})

	t.Run("success if admin", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		std.TestSetRealm(adminRealm)

		uassert.Equal(t, uint64(7500), GetDistributionPct(1))
		uassert.Equal(t, uint64(2000), GetDistributionPct(2))
		uassert.Equal(t, uint64(500), GetDistributionPct(3))
		uassert.Equal(t, uint64(0), GetDistributionPct(4))

		ChangeDistributionPctByAdmin(1, 5000, 2, 3000, 3, 1000, 4, 1000)
	})
}

func TestChangeDistributionPct(t *testing.T) {
	t.Run("panic if not governance", func(t *testing.T) {
		uassert.PanicsWithMessage(
			t,
			"only governance can change distribution percentages",
			func() {
				ChangeDistributionPct(1, 0, 2, 0, 3, 0, 4, 0)
			},
		)
	})

	t.Run("success if governance", func(t *testing.T) {
		govRealm := std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
		std.TestSetRealm(govRealm)

		ChangeDistributionPct(1, 5000, 2, 3000, 3, 1000, 4, 1000)
	})
}
