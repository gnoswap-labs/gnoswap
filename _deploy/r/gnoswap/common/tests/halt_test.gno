package common

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/consts"
)

var (
	adminRealm = std.NewUserRealm(consts.ADMIN)
	govRealm   = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
)

func TestHalts(t *testing.T) {
	t.Run("GetHalt() initial value", func(t *testing.T) {
		uassert.False(t, GetHalt())
	})

	t.Run("IsHalted() success", func(t *testing.T) {
		uassert.NotPanics(t, IsHalted)
	})
}

func TestSetHaltByAdmin(t *testing.T) {
	t.Run("with non-admin privilege, panics", func(t *testing.T) {
		uassert.PanicsWithMessage(
			t,
			`[GNOSWAP-COMMON-001] caller has no permission || halt.gno__SetHaltByAdmin() || only admin(g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c) can set halt, called from g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm`,
			func() { SetHaltByAdmin(false) },
		)
	})

	t.Run("with governance privilege, panics", func(t *testing.T) {
		std.TestSetRealm(govRealm)
		uassert.PanicsWithMessage(
			t,
			`[GNOSWAP-COMMON-001] caller has no permission || halt.gno__SetHaltByAdmin() || only admin(g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c) can set halt, called from g17s8w2ve7k85fwfnrk59lmlhthkjdted8whvqxd`,
			func() { SetHaltByAdmin(false) },
		)
	})

	t.Run("with admin privilege, success", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		uassert.False(t, GetHalt())

		SetHaltByAdmin(true)
		uassert.True(t, GetHalt())
	})
}

func TestSetHalt(t *testing.T) {
	t.Run("with non-governance privilege, panics", func(t *testing.T) {
		uassert.PanicsWithMessage(
			t,
			`[GNOSWAP-COMMON-001] caller has no permission || halt.gno__SetHalt() || only governance(g17s8w2ve7k85fwfnrk59lmlhthkjdted8whvqxd) can set halt, called from g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm`,
			func() { SetHalt(false) },
		)
	})

	t.Run("with admin privilege, panics", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		uassert.PanicsWithMessage(
			t,
			`[GNOSWAP-COMMON-001] caller has no permission || halt.gno__SetHalt() || only governance(g17s8w2ve7k85fwfnrk59lmlhthkjdted8whvqxd) can set halt, called from g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c`,
			func() { SetHalt(false) },
		)
	})

	t.Run("with governance privilege, success", func(t *testing.T) {
		std.TestSetRealm(govRealm)

		uassert.True(t, GetHalt())

		SetHalt(false)
		uassert.False(t, GetHalt())
	})
}
