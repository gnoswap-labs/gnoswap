package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestDefaultOperations(t *testing.T) {
	t.Run("defaultOperations contains expected operations", func(t *testing.T) {
		// Verify we have the expected number of default operations
		uassert.Equal(t, 1, len(defaultOperations))

		// Verify withdraw operation exists
		found := false
		for _, op := range defaultOperations {
			if op.opType == OpTypeWithdraw {
				found = true
				uassert.Equal(t, rawWithdraw, op.name)
				uassert.Equal(t, "Withdrawal operations", op.desc)
				break
			}
		}
		uassert.True(t, found)
	})

	t.Run("defaultOperations structure validation", func(t *testing.T) {
		for _, op := range defaultOperations {
			// Verify all fields are properly set
			uassert.True(t, op.opType != OpType(""))
			uassert.True(t, op.name != "")
			uassert.True(t, op.desc != "")
		}
	})
}

func TestDefaultLevels(t *testing.T) {
	t.Run("defaultLevels contains all expected levels", func(t *testing.T) {
		expectedLevels := []LevelID{
			LvNoHalt,
			LvContractHalt,
			LvEmergencyHalt,
			LvCompleteHalt,
		}

		uassert.Equal(t, len(expectedLevels), len(defaultLevels))

		for _, expectedLevel := range expectedLevels {
			found := false
			for _, level := range defaultLevels {
				if level.id == expectedLevel {
					found = true
					break
				}
			}
			uassert.True(t, found)
		}
	})

	t.Run("NoHalt level configuration", func(t *testing.T) {
		var noHaltLevel *struct {
			id      LevelID
			name    string
			desc    string
			allowed map[OpType]bool
		}

		for _, level := range defaultLevels {
			if level.id == LvNoHalt {
				noHaltLevel = &level
				break
			}
		}

		uassert.True(t, noHaltLevel != nil)
		uassert.True(t, noHaltLevel.id == LvNoHalt)
		uassert.True(t, noHaltLevel.name == rawNoHalt)
		uassert.True(t, noHaltLevel.desc == "Normal operation")

		// All operations should be allowed in NoHalt
		expectedOps := []OpType{
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

		for _, op := range expectedOps {
			allowed, exists := noHaltLevel.allowed[op]
			uassert.True(t, exists)
			uassert.True(t, allowed)
		}
	})

	t.Run("ContractHalt level configuration", func(t *testing.T) {
		var contractHaltLevel *struct {
			id      LevelID
			name    string
			desc    string
			allowed map[OpType]bool
		}

		for _, level := range defaultLevels {
			if level.id == LvContractHalt {
				contractHaltLevel = &level
				break
			}
		}

		uassert.True(t, contractHaltLevel != nil)
		uassert.True(t, contractHaltLevel.id == LvContractHalt)
		uassert.True(t, contractHaltLevel.name == rawContractHalt)
		uassert.True(t, contractHaltLevel.desc == "Specific contract operations disabled")

		// All operations should be allowed in ContractHalt by default
		expectedOps := []OpType{
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

		for _, op := range expectedOps {
			allowed, exists := contractHaltLevel.allowed[op]
			uassert.True(t, exists)
			uassert.True(t, allowed)
		}
	})

	t.Run("EmergencyHalt level configuration", func(t *testing.T) {
		var emergencyHaltLevel *struct {
			id      LevelID
			name    string
			desc    string
			allowed map[OpType]bool
		}

		for _, level := range defaultLevels {
			if level.id == LvEmergencyHalt {
				emergencyHaltLevel = &level
				break
			}
		}

		uassert.True(t, emergencyHaltLevel != nil)
		uassert.True(t, emergencyHaltLevel.id == LvEmergencyHalt)
		uassert.True(t, emergencyHaltLevel.name == rawEmergencyHalt)
		uassert.True(t, emergencyHaltLevel.desc == "Only withdrawals allowed")

		// Only governance and withdraw should be allowed
		allowedOps := []OpType{OpTypeGovernance, OpTypeWithdraw}
		for _, op := range allowedOps {
			allowed, exists := emergencyHaltLevel.allowed[op]
			uassert.True(t, exists)
			uassert.True(t, allowed)
		}

		// All other operations should not be in the map or be false
		restrictedOps := []OpType{
			OpTypePool,
			OpTypePosition,
			OpTypeProtocolFee,
			OpTypeRouter,
			OpTypeStaker,
			OpTypeLaunchpad,
			OpTypeGovStaker,
			OpTypeXGns,
			OpTypeCommunityPool,
			OpTypeEmission,
		}

		for _, op := range restrictedOps {
			allowed, exists := emergencyHaltLevel.allowed[op]
			if exists {
				uassert.False(t, allowed)
			}
		}
	})

	t.Run("CompleteHalt level configuration", func(t *testing.T) {
		var completeHaltLevel *struct {
			id      LevelID
			name    string
			desc    string
			allowed map[OpType]bool
		}

		for _, level := range defaultLevels {
			if level.id == LvCompleteHalt {
				completeHaltLevel = &level
				break
			}
		}

		uassert.True(t, completeHaltLevel != nil)
		uassert.True(t, completeHaltLevel.id == LvCompleteHalt)
		uassert.True(t, completeHaltLevel.name == rawCompleteHalt)
		uassert.True(t, completeHaltLevel.desc == "All contract disabled")

		// Only withdraw should be allowed
		allowed, exists := completeHaltLevel.allowed[OpTypeWithdraw]
		uassert.True(t, exists)
		uassert.True(t, allowed)

		// All other operations should not be in the map or be false
		restrictedOps := []OpType{
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
		}

		for _, op := range restrictedOps {
			allowed, exists := completeHaltLevel.allowed[op]
			if exists {
				uassert.False(t, allowed)
			}
		}
	})
}

func TestDefaultLevelProgression(t *testing.T) {
	t.Run("halt level progression makes sense", func(t *testing.T) {
		// Get allowed operations for each level
		levelConfigs := make(map[LevelID]map[OpType]bool)
		for _, level := range defaultLevels {
			levelConfigs[level.id] = level.allowed
		}

		// NoHalt should allow more operations than ContractHalt
		noHaltAllowed := countAllowedOps(levelConfigs[LvNoHalt])
		contractHaltAllowed := countAllowedOps(levelConfigs[LvContractHalt])
		emergencyHaltAllowed := countAllowedOps(levelConfigs[LvEmergencyHalt])
		completeHaltAllowed := countAllowedOps(levelConfigs[LvCompleteHalt])

		// Verify progression: NoHalt >= ContractHalt >= EmergencyHalt >= CompleteHalt
		uassert.True(t, noHaltAllowed >= contractHaltAllowed)
		uassert.True(t, contractHaltAllowed >= emergencyHaltAllowed)
		uassert.True(t, emergencyHaltAllowed >= completeHaltAllowed)

		// CompleteHalt should allow the fewest operations
		uassert.True(t, completeHaltAllowed < noHaltAllowed)
	})

	t.Run("emergency halt allows subset of contract halt", func(t *testing.T) {
		var emergencyLevel, contractLevel map[OpType]bool

		for _, level := range defaultLevels {
			if level.id == LvEmergencyHalt {
				emergencyLevel = level.allowed
			} else if level.id == LvContractHalt {
				contractLevel = level.allowed
			}
		}

		// Every operation allowed in emergency should also be allowed in contract halt
		for op, allowed := range emergencyLevel {
			if allowed {
				contractAllowed, exists := contractLevel[op]
				uassert.True(t, exists)
				uassert.True(t, contractAllowed)
			}
		}
	})

	t.Run("complete halt allows subset of emergency halt", func(t *testing.T) {
		var completeLevel, emergencyLevel map[OpType]bool

		for _, level := range defaultLevels {
			if level.id == LvCompleteHalt {
				completeLevel = level.allowed
			} else if level.id == LvEmergencyHalt {
				emergencyLevel = level.allowed
			}
		}

		// Every operation allowed in complete should also be allowed in emergency
		for op, allowed := range completeLevel {
			if allowed {
				emergencyAllowed, exists := emergencyLevel[op]
				uassert.True(t, exists)
				uassert.True(t, emergencyAllowed)
			}
		}
	})
}

func TestDefaultLevelStructure(t *testing.T) {
	t.Run("all levels have required fields", func(t *testing.T) {
		for _, level := range defaultLevels {
			uassert.True(t, level.id != LevelID(0))
			uassert.True(t, level.name != "")
			uassert.True(t, level.desc != "")
			uassert.True(t, level.allowed != nil)
		}
	})

	t.Run("level IDs are unique", func(t *testing.T) {
		idMap := make(map[LevelID]bool)
		for _, level := range defaultLevels {
			uassert.False(t, idMap[level.id]) // Should not exist yet
			idMap[level.id] = true
		}
	})

	t.Run("level names are unique", func(t *testing.T) {
		nameMap := make(map[string]bool)
		for _, level := range defaultLevels {
			uassert.False(t, nameMap[level.name]) // Should not exist yet
			nameMap[level.name] = true
		}
	})

	t.Run("level allowed maps are not empty", func(t *testing.T) {
		for _, level := range defaultLevels {
			uassert.True(t, len(level.allowed) > 0)
		}
	})
}

func TestDefaultLevelConsistency(t *testing.T) {
	t.Run("withdraw operation is allowed in all levels", func(t *testing.T) {
		// Withdraw should be allowed in all default levels
		for _, level := range defaultLevels {
			allowed, exists := level.allowed[OpTypeWithdraw]
			uassert.True(t, exists)
			uassert.True(t, allowed)
		}
	})

	t.Run("governance operation consistency", func(t *testing.T) {
		// Governance should be allowed in NoHalt, ContractHalt, and EmergencyHalt
		allowedLevels := []LevelID{LvNoHalt, LvContractHalt, LvEmergencyHalt}

		for _, levelID := range allowedLevels {
			for _, level := range defaultLevels {
				if level.id == levelID {
					allowed, exists := level.allowed[OpTypeGovernance]
					uassert.True(t, exists)
					uassert.True(t, allowed)
					break
				}
			}
		}

		// Governance should not be allowed in CompleteHalt
		for _, level := range defaultLevels {
			if level.id == LvCompleteHalt {
				allowed, exists := level.allowed[OpTypeGovernance]
				if exists {
					uassert.False(t, allowed)
				}
				break
			}
		}
	})
}

// Helper function to count allowed operations
func countAllowedOps(allowedMap map[OpType]bool) int {
	count := 0
	for _, allowed := range allowedMap {
		if allowed {
			count++
		}
	}
	return count
}
