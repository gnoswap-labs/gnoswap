package halt

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/p/gnoswap/consts"
	phalt "gno.land/p/gnoswap/halt"
)

var (
	adminRealm = std.NewUserRealm(consts.ADMIN)
	govRealm   = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
)

func TestHalts(t *testing.T) {
	t.Run("GetHalt() initial value", func(t *testing.T) {
		// Initially we're in TestnetSafeMode which should report as halted
		uassert.True(t, GetHalt())
	})

	t.Run("Operation specific checks in TestnetSafeMode", func(t *testing.T) {
		// Governance operations should be allowed in TestnetSafeMode
		err := IsHalted(OpTypeGovernance)
		uassert.NoError(t, err)

		// Withdrawals should be disabled in TestnetSafeMode
		err = IsHalted(OpTypeWithdraw)
		uassert.Error(t, err)

		// Swaps should be disabled in TestnetSafeMode
		err = IsHalted(OpTypeSwap)
		uassert.Error(t, err)
	})
}

func TestSetHaltLevelByAdmin(t *testing.T) {
	t.Run("with non-admin privilege, panics", func(t *testing.T) {
		std.TestSetRealm(std.NewCodeRealm("gno.land/r/demo/users"))
		err := SetHaltLevelByAdmin(phalt.LvNoHalt)
		uassert.Error(t, err)
	})

	t.Run("with admin privilege, success", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		// Initially we're in TestnetSafeMode
		uassert.True(t, GetHalt())
		if GetCurrentHaltLevel() != LvTestnetSafeMode {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), LvTestnetSafeMode)
		}

		// Change to NoHalt
		err := SetHaltLevelByAdmin(phalt.LvNoHalt)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != phalt.LvNoHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), phalt.LvNoHalt)
		}

		// Back to CompleteHalt
		err = SetHaltLevelByAdmin(phalt.LvCompleteHalt)
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != phalt.LvCompleteHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), phalt.LvCompleteHalt)
		}
	})
}

func TestSetHalt(t *testing.T) {
	t.Run("with admin (non-governance) privilege, should fail", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		err := SetHalt(false)
		uassert.Error(t, err)
	})

	t.Run("with governance privilege, success", func(t *testing.T) {
		std.TestSetRealm(govRealm)

		// Currently in CompleteHalt from previous test
		uassert.True(t, GetHalt())

		err := SetHalt(false) // try to set to NoHalt
		uassert.NoError(t, err)
		if GetCurrentHaltLevel() != phalt.LvNoHalt {
			t.Fatalf("GetCurrentHaltLevel() = %d, want %d", GetCurrentHaltLevel(), phalt.LvNoHalt)
		}
	})
}
