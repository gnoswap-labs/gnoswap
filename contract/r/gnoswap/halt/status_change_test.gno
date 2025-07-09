// This tests for changing halt status and permissions
package halt

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
)

func TestChangeHaltStatus(t *testing.T) {
	var (
		adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
		adminRealm   = std.NewUserRealm(adminAddr)
	)

	t.Run("complex transition sequence with operation status preservation", func(t *testing.T) {
		// Start from NoHalt
		testing.SetRealm(adminRealm)
		err := SetHalt(cross, false)
		uassert.NoError(t, err)

		// Enable withdrawals
		err = SetOperationStatusByAdmin(cross, OpTypeWithdraw, true)
		uassert.NoError(t, err)

		// Verify withdrawals are enabled
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)

		// Switch to EmergencyHalt
		err = SetHalt(cross, true, LvEmergencyHalt)
		uassert.NoError(t, err)

		// Verify only essential operations are allowed
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)
		err = IsHalted(OpTypePool)
		uassert.Error(t, err)

		// Switch back to NoHalt
		err = SetHalt(cross, false)
		uassert.NoError(t, err)

		// Verify operation states are preserved
		err = IsHalted(OpTypeWithdraw)
		uassert.NoError(t, err)
	})

	t.Run("operation status inheritance", func(t *testing.T) {
		// Reset to NoHalt
		testing.SetRealm(adminRealm)
		err := SetHalt(cross, false)
		uassert.NoError(t, err)

		// Disable pool operations
		err = SetOperationStatusByAdmin(cross, OpTypePool, false)
		uassert.NoError(t, err)

		// Verify pool is disabled
		err = IsHalted(OpTypePool)
		uassert.Error(t, err)

		// Switch through different modes and verify pool stays disabled
		modes := []LevelID{
			LvEmergencyHalt,
			LvCompleteHalt,
			LvNoHalt,
		}

		for _, mode := range modes {
			if mode == LvNoHalt {
				err = SetHalt(cross, false)
			} else {
				err = SetHalt(cross, true, mode)
			}
			uassert.NoError(t, err)

			// Pool should remain disabled or be halted by the mode
			err = IsHalted(OpTypePool)
			uassert.Error(t, err)
		}
	})
}

// Integration tests for complex permission scenarios
func TestChangePermissions(t *testing.T) {
	var (
		adminAddr, _      = access.GetAddress(access.ROLE_ADMIN)
		adminRealm        = std.NewUserRealm(adminAddr)
		govRealm          = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
		unauthorizedRealm = std.NewCodeRealm("gno.land/r/demo/unauthorized")
	)

	t.Run("permission interaction between admin and governance", func(t *testing.T) {
		// Start from NoHalt
		testing.SetRealm(adminRealm)
		err := SetHalt(cross, false)
		uassert.NoError(t, err)

		// Admin disables an operation
		err = SetOperationStatusByAdmin(cross, OpTypePool, false)
		uassert.NoError(t, err)

		// Governance tries to enable the same operation
		testing.SetRealm(govRealm)
		err = SetOperationStatus(cross, OpTypePool, true)
		uassert.NoError(t, err)

		// Operation should now be enabled
		err = IsHalted(OpTypePool)
		uassert.NoError(t, err)

		// Admin overrides governance
		testing.SetRealm(adminRealm)
		err = SetOperationStatusByAdmin(cross, OpTypePool, false)
		uassert.NoError(t, err)

		// Operation should be disabled again
		err = IsHalted(OpTypePool)
		uassert.Error(t, err)
	})

	t.Run("complex mode transition permissions", func(t *testing.T) {
		// Start from NoHalt
		testing.SetRealm(adminRealm)
		err := SetHalt(cross, false)
		uassert.NoError(t, err)

		// Unauthorized user tries multiple operations
		testing.SetRealm(unauthorizedRealm)

		// Try to set halt level
		err = SetHalt(cross, true, LvEmergencyHalt)
		uassert.Error(t, err)

		// Try to enable operations
		err = SetOperationStatus(cross, OpTypePool, true)
		uassert.Error(t, err)

		// Try to enable withdrawals
		err = EnableWithdrawalsForTestnet(cross)
		uassert.Error(t, err)

		// Verify nothing changed
		testing.SetRealm(adminRealm)
		uassert.True(t, GetCurrentHaltLevel() == LvNoHalt)
	})
}
