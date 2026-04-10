package halt

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestTypes_HaltLevelDescription(t *testing.T) {
	uassert.Equal(t, HaltLevelSafeMode.Description(), "Shared recovery actions halted")
	uassert.Equal(t, HaltLevelEmergency.Description(), "Governance operate and recovery actions remain enabled")
}

func TestTypes_DomainValidation(t *testing.T) {
	uassert.Equal(t, OpTypePool.IsValid(), true)
	uassert.Equal(t, OpType("withdraw").IsValid(), false)
}

func TestTypes_ActionValidation(t *testing.T) {
	uassert.Equal(t, ActionRecover.IsValid(), true)
	uassert.Equal(t, Action("withdraw").IsValid(), false)
	uassert.Equal(t, IsAllowedAction(OpTypePosition, ActionRecover), true)
	uassert.Equal(t, IsAllowedAction(OpTypeGovernance, ActionRecover), false)
	uassert.Equal(t, policyKey(OpTypePool, ActionOperate), "pool:operate")
	uassert.Equal(t, IsAllowedAction(OpTypeProtocolFee, ActionOperate), true)
	uassert.Equal(t, IsAllowedAction(OpTypeCommunityPool, ActionOperate), true)
}
