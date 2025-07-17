package halt

// Helper function for readability
func allOperationsEnabled() map[OpType]bool {
	return map[OpType]bool{
		OpTypePool:          true,
		OpTypePosition:      true,
		OpTypeProtocolFee:   true,
		OpTypeRouter:        true,
		OpTypeStaker:        true,
		OpTypeLaunchpad:     true,
		OpTypeGovernance:    true,
		OpTypeGovStaker:     true,
		OpTypeXGns:          true,
		OpTypeCommunityPool: true,
		OpTypeEmission:      true,
		OpTypeWithdraw:      true,
	}
}

// Static configuration - clear what each level allows
var haltLevelConfigs = map[HaltLevel]map[OpType]bool{
	HaltLevelNone: allOperationsEnabled(),
	
	HaltLevelSafeMode: func() map[OpType]bool {
		config := allOperationsEnabled()
		config[OpTypeWithdraw] = false  // Only withdrawal disabled
		return config
	}(),
	
	HaltLevelEmergency: map[OpType]bool{
		OpTypeGovernance: true,
		OpTypeWithdraw:   true,
		// All others false by default
	},
	
	HaltLevelComplete: map[OpType]bool{
		// All operations disabled
	},
}

// getOperationDefaultStatus returns the default status for an operation at a given level
func getOperationDefaultStatus(level HaltLevel, op OpType) bool {
	levelConfig, exists := haltLevelConfigs[level]
	if !exists {
		return false // If level doesn't exist, default to disabled
	}
	
	status, exists := levelConfig[op]
	return exists && status // Return false if operation doesn't exist in level config
}

// getAllOperationTypes returns all valid operation types
func getAllOperationTypes() []OpType {
	return []OpType{
		OpTypePool,
		OpTypePosition,
		OpTypeProtocolFee,
		OpTypeRouter,
		OpTypeStaker,
		OpTypeLaunchpad,
		OpTypeGovernance,
		OpTypeGovStaker,
		OpTypeXGns,
		OpTypeCommunityPool,
		OpTypeEmission,
		OpTypeWithdraw,
	}
}

// getLevelDescription returns a human-readable description for a halt level
func getLevelDescription(level HaltLevel) string {
	switch level {
	case HaltLevelNone:
		return "All operations enabled"
	case HaltLevelSafeMode:
		return "All operations enabled except withdrawals"
	case HaltLevelEmergency:
		return "Only governance and withdrawal operations enabled"
	case HaltLevelComplete:
		return "All operations disabled"
	default:
		return "Unknown halt level"
	}
}
