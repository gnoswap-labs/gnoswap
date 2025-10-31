package halt

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestGetters_IsHaltedPool(t *testing.T) {
	tests := []struct {
		name      string
		haltLevel HaltLevel
		expected  bool
	}{
		{"None level", HaltLevelNone, false},
		{"SafeMode", HaltLevelSafeMode, false},
		{"Emergency", HaltLevelEmergency, true},
		{"Complete", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := IsHaltedPool()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetters_IsHaltedPosition(t *testing.T) {
	tests := []struct {
		name      string
		haltLevel HaltLevel
		expected  bool
	}{
		{"None level", HaltLevelNone, false},
		{"SafeMode", HaltLevelSafeMode, false},
		{"Emergency", HaltLevelEmergency, true},
		{"Complete", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := IsHaltedPosition()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetters_IsHaltedProtocolFee(t *testing.T) {
	tests := []struct {
		name      string
		haltLevel HaltLevel
		expected  bool
	}{
		{"None level", HaltLevelNone, false},
		{"SafeMode", HaltLevelSafeMode, false},
		{"Emergency", HaltLevelEmergency, true},
		{"Complete", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := IsHaltedProtocolFee()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetters_IsHaltedRouter(t *testing.T) {
	tests := []struct {
		name      string
		haltLevel HaltLevel
		expected  bool
	}{
		{"None level", HaltLevelNone, false},
		{"SafeMode", HaltLevelSafeMode, false},
		{"Emergency", HaltLevelEmergency, true},
		{"Complete", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := IsHaltedRouter()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetters_IsHaltedStaker(t *testing.T) {
	tests := []struct {
		name      string
		haltLevel HaltLevel
		expected  bool
	}{
		{"None level", HaltLevelNone, false},
		{"SafeMode", HaltLevelSafeMode, false},
		{"Emergency", HaltLevelEmergency, true},
		{"Complete", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := IsHaltedStaker()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetters_IsHaltedLaunchpad(t *testing.T) {
	tests := []struct {
		name      string
		haltLevel HaltLevel
		expected  bool
	}{
		{"None level", HaltLevelNone, false},
		{"SafeMode", HaltLevelSafeMode, false},
		{"Emergency", HaltLevelEmergency, true},
		{"Complete", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := IsHaltedLaunchpad()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetters_IsHaltedGovernance(t *testing.T) {
	tests := []struct {
		name      string
		haltLevel HaltLevel
		expected  bool
	}{
		{"None level", HaltLevelNone, false},
		{"SafeMode", HaltLevelSafeMode, false},
		{"Emergency", HaltLevelEmergency, false},
		{"Complete", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := IsHaltedGovernance()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetters_IsHaltedGovStaker(t *testing.T) {
	tests := []struct {
		name      string
		haltLevel HaltLevel
		expected  bool
	}{
		{"None level", HaltLevelNone, false},
		{"SafeMode", HaltLevelSafeMode, false},
		{"Emergency", HaltLevelEmergency, true},
		{"Complete", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := IsHaltedGovStaker()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetters_IsHaltedXGns(t *testing.T) {
	tests := []struct {
		name      string
		haltLevel HaltLevel
		expected  bool
	}{
		{"None level", HaltLevelNone, false},
		{"SafeMode", HaltLevelSafeMode, false},
		{"Emergency", HaltLevelEmergency, true},
		{"Complete", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := IsHaltedXGns()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetters_IsHaltedCommunityPool(t *testing.T) {
	tests := []struct {
		name      string
		haltLevel HaltLevel
		expected  bool
	}{
		{"None level", HaltLevelNone, false},
		{"SafeMode", HaltLevelSafeMode, false},
		{"Emergency", HaltLevelEmergency, true},
		{"Complete", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := IsHaltedCommunityPool()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetters_IsHaltedEmission(t *testing.T) {
	tests := []struct {
		name      string
		haltLevel HaltLevel
		expected  bool
	}{
		{"None level", HaltLevelNone, false},
		{"SafeMode", HaltLevelSafeMode, false},
		{"Emergency", HaltLevelEmergency, true},
		{"Complete", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := IsHaltedEmission()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetters_IsHaltedWithdraw(t *testing.T) {
	tests := []struct {
		name      string
		haltLevel HaltLevel
		expected  bool
	}{
		{"None level", HaltLevelNone, false},
		{"SafeMode", HaltLevelSafeMode, true},
		{"Emergency", HaltLevelEmergency, false},
		{"Complete", HaltLevelComplete, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := IsHaltedWithdraw()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetters_isHaltedOperation(t *testing.T) {
	tests := []struct {
		name      string
		opType    OpType
		haltLevel HaltLevel
		expected  bool
	}{
		{"Pool in None", OpTypePool, HaltLevelNone, false},
		{"Pool in Emergency", OpTypePool, HaltLevelEmergency, true},
		{"Governance in Emergency", OpTypeGovernance, HaltLevelEmergency, false},
		{"Withdraw in SafeMode", OpTypeWithdraw, HaltLevelSafeMode, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := isHaltedOperation(tt.opType)
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetters_isHaltedOperationWithVersion(t *testing.T) {
	tests := []struct {
		name      string
		opType    OpType
		version   int
		haltLevel HaltLevel
		expected  bool
	}{
		{"Pool version 1 in None", OpTypePool, 1, HaltLevelNone, false},
		{"Pool version 1 in Emergency", OpTypePool, 1, HaltLevelEmergency, true},
		{"Governance version 1 in Emergency", OpTypeGovernance, 1, HaltLevelEmergency, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			haltStates = newHaltStateManagerByConfig(getConfigByLevel(tt.haltLevel))
			result := isHaltedOperationWithVersion(tt.opType, tt.version)
			uassert.Equal(t, result, tt.expected)
		})
	}
}
