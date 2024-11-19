package common

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/consts"
)

var adminRealm = std.NewUserRealm(consts.ADMIN)

func TestSetLimitCaller(t *testing.T) {
	t.Run("initial check", func(t *testing.T) {
		uassert.True(t, GetLimitCaller())
	})

	t.Run("with non-admin privilege, panics", func(t *testing.T) {
		uassert.PanicsWithMessage(t,
			`[GNOSWAP-COMMON-001] caller has no permission || limit_caller.gno__SetLimitCaller() || only admin(g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c) can set limit caller, called from g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm`,
			func() { SetLimitCaller(false) },
		)
	})

	t.Run("with admin privilege, success", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		SetLimitCaller(false)
		uassert.False(t, GetLimitCaller())
	})
}
