package halt

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	_ "gno.land/r/gnoswap/rbac"
)

func cleanup(t *testing.T) {
	t.Helper()
	err := setHaltLevel(HaltLevelNone)
	uassert.NoError(t, err)
}

func TestHalt_SetHaltLevel_Internal(t *testing.T) {
	cleanup(t)
	uassert.NoError(t, setHaltLevel(HaltLevelEmergency))
	config := GetHaltConfig()
	halted, err := config.get(OpTypePool, ActionOperate)
	uassert.NoError(t, err)
	uassert.Equal(t, halted, true)
	halted, err = config.get(OpTypePosition, ActionRecover)
	uassert.NoError(t, err)
	uassert.Equal(t, halted, false)
	halted, err = config.get(OpTypeGovernance, ActionOperate)
	uassert.NoError(t, err)
	uassert.Equal(t, halted, false)
}

func TestHalt_SetActionStatus_Internal(t *testing.T) {
	cleanup(t)
	uassert.NoError(t, haltStates.setActionHalted(OpTypePosition, ActionRecover, true))
	halted, err := IsActionHalted(OpTypePosition, ActionRecover)
	uassert.NoError(t, err)
	uassert.Equal(t, halted, true)
}

func TestHalt_SetOperationStatus_Internal(t *testing.T) {
	cleanup(t)
	uassert.NoError(t, haltStates.setActionHalted(OpTypePool, ActionOperate, true))
	uassert.Equal(t, IsHaltedPool(), true)
}

func TestHalt_Setters_WithAuthorization(t *testing.T) {
	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govAddr := access.MustGetAddress(prbac.ROLE_GOVERNANCE.String())

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	SetActionStatus(cross, OpTypePosition, ActionRecover, true)
	halted, err := IsActionHalted(OpTypePosition, ActionRecover)
	uassert.NoError(t, err)
	uassert.Equal(t, halted, true)

	testing.SetRealm(testing.NewUserRealm(govAddr))
	SetOperationStatus(cross, OpTypePool, true)
	uassert.Equal(t, IsHaltedPool(), true)
}
