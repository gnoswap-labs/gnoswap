package halt

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestTypes_HaltLevelDescription(t *testing.T) {
	uassert.Equal(t, HaltLevelSafeMode.Description(), "Shared withdrawal actions halted")
	uassert.Equal(t, HaltLevelEmergency.Description(), "Governance operate and withdrawal actions remain enabled")
}

func TestTypes_DomainValidation(t *testing.T) {
	uassert.Equal(t, OpTypePool.IsValid(), true)
	uassert.Equal(t, OpType("withdraw").IsValid(), false)
}

func TestTypes_ActionValidation(t *testing.T) {
	uassert.Equal(t, ActionWithdraw.IsValid(), true)
	uassert.Equal(t, Action("invalid").IsValid(), false)
	uassert.Equal(t, IsAllowedAction(OpTypePosition, ActionWithdraw), true)
	uassert.Equal(t, IsAllowedAction(OpTypeGovernance, ActionWithdraw), false)
	uassert.Equal(t, policyKey(OpTypePool, ActionOperate), "pool:operate")
	uassert.Equal(t, IsAllowedAction(OpTypeProtocolFee, ActionOperate), true)
	uassert.Equal(t, IsAllowedAction(OpTypeCommunityPool, ActionOperate), true)
}
