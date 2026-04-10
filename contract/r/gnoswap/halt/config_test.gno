package halt

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestConfig_Factories(t *testing.T) {
	none := newNoneConfig()
	safe := newSafeModeConfig()
	emergency := newEmergencyConfig()
	complete := newCompleteConfig()

	uassert.Equal(t, none.IsHalted(OpTypePosition, ActionWithdraw), false)
	uassert.Equal(t, safe.IsHalted(OpTypePosition, ActionWithdraw), true)
	uassert.Equal(t, emergency.IsHalted(OpTypePosition, ActionWithdraw), false)
	uassert.Equal(t, complete.IsHalted(OpTypePosition, ActionWithdraw), true)

	uassert.Equal(t, emergency.IsHalted(OpTypePool, ActionOperate), true)
	uassert.Equal(t, emergency.IsHalted(OpTypeGovernance, ActionOperate), false)
	uassert.Equal(t, emergency.IsHalted(OpTypeProtocolFee, ActionOperate), true)
	uassert.Equal(t, emergency.IsHalted(OpTypeCommunityPool, ActionOperate), true)
}

func TestConfig_GetSetClone(t *testing.T) {
	config := newNoneConfig()
	uassert.NoError(t, config.set(OpTypePool, ActionOperate, true))
	halted, err := config.get(OpTypePool, ActionOperate)
	uassert.NoError(t, err)
	uassert.Equal(t, halted, true)

	clone := config.Clone()
	uassert.NoError(t, config.set(OpTypePool, ActionOperate, false))
	halted, err = clone.get(OpTypePool, ActionOperate)
	uassert.NoError(t, err)
	uassert.Equal(t, halted, true)
}

func TestConfig_InvalidCombination(t *testing.T) {
	config := newNoneConfig()
	_, err := config.get(OpTypeGovernance, ActionWithdraw)
	uassert.ErrorContains(t, err, "action not allowed for domain")
	err = config.set(OpTypeGovernance, ActionWithdraw, true)
	uassert.ErrorContains(t, err, "action not allowed for domain")
}
