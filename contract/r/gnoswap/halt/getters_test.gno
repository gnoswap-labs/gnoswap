package halt

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestGetters_DefaultOperateProjection(t *testing.T) {
	err := setHaltLevel(HaltLevelEmergency)
	uassert.NoError(t, err)

	uassert.Equal(t, IsHaltedPool(), true)
	uassert.Equal(t, IsHaltedGovernance(), false)
	uassert.Equal(t, IsHaltedCommunityPool(), true)

	halted, err := IsHalted(OpTypePool, OpTypeGovernance)
	uassert.NoError(t, err)
	uassert.Equal(t, halted, true)
}

func TestGetters_IsActionHalted(t *testing.T) {
	err := setHaltLevel(HaltLevelSafeMode)
	uassert.NoError(t, err)

	halted, err := IsActionHalted(OpTypePosition, ActionWithdraw)
	uassert.NoError(t, err)
	uassert.Equal(t, halted, true)

	halted, err = IsActionHalted(OpTypePosition, ActionOperate)
	uassert.NoError(t, err)
	uassert.Equal(t, halted, false)
}

func TestGetters_GetHaltConfigJson(t *testing.T) {
	err := setHaltLevel(HaltLevelSafeMode)
	uassert.NoError(t, err)
	jsonStr := GetHaltConfigJson()
	uassert.True(t, len(jsonStr) > 0)
}
