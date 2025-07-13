package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestLevelExtended_LevelID(t *testing.T) {
	tests := []struct {
		name   string
		testFn func(t *testing.T)
	}{
		{
			name: "LevelID constants are correctly defined",
			testFn: func(t *testing.T) {
				uassert.Equal(t, uint8(1), LvNoHalt.Nth())
				uassert.Equal(t, uint8(2), LvContractHalt.Nth())
				uassert.Equal(t, uint8(3), LvEmergencyHalt.Nth())
				uassert.Equal(t, uint8(4), LvCompleteHalt.Nth())
			},
		},
		{
			name: "LevelID string representation",
			testFn: func(t *testing.T) {
				uassert.Equal(t, "NoHalt", LvNoHalt.String())
				uassert.Equal(t, "ContractHalt", LvContractHalt.String())
				uassert.Equal(t, "EmergencyHalt", LvEmergencyHalt.String())
				uassert.Equal(t, "CompleteHalt", LvCompleteHalt.String())
			},
		},
		{
			name: "LevelID unknown value",
			testFn: func(t *testing.T) {
				unknownLevel := LevelID(99)
				uassert.Equal(t, "Unknown", unknownLevel.String())
				uassert.Equal(t, uint8(99), unknownLevel.Nth())
			},
		},
		{
			name: "LevelID Name method",
			testFn: func(t *testing.T) {
				uassert.Equal(t, "NoHalt", LvNoHalt.Name())
				uassert.Equal(t, "EmergencyHalt", LvEmergencyHalt.Name())
				uassert.Equal(t, "Unknown", LevelID(255).Name())
			},
		},
		{
			name: "LevelID Desc method",
			testFn: func(t *testing.T) {
				uassert.Equal(t, "Level NoHalt", LvNoHalt.Desc())
				uassert.Equal(t, "Level EmergencyHalt", LvEmergencyHalt.Desc())
				uassert.Equal(t, "Level Unknown", LevelID(100).Desc())
			},
		},
		{
			name: "LevelID Level method",
			testFn: func(t *testing.T) {
				uassert.True(t, LvNoHalt.Level() == LvNoHalt)
				uassert.True(t, LvCompleteHalt.Level() == LvCompleteHalt)
			},
		},
		{
			name: "LevelID IsOperationAllowed always returns true",
			testFn: func(t *testing.T) {
				testOp := NewOperation(OpTypePool, "Test", "Test operation")

				// Default implementation always returns true
				uassert.True(t, LvNoHalt.IsOperationAllowed(testOp))
				uassert.True(t, LvCompleteHalt.IsOperationAllowed(testOp))
				uassert.True(t, LevelID(255).IsOperationAllowed(testOp))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.testFn(t)
		})
	}
}

func TestLevelExtended_LevelIDFromString(t *testing.T) {
	tests := []struct {
		name   string
		testFn func(t *testing.T)
	}{
		{
			name: "valid level strings",
			testFn: func(t *testing.T) {
				tests := []struct {
					input    string
					expected LevelID
				}{
					{"NoHalt", LvNoHalt},
					{"ContractHalt", LvContractHalt},
					{"EmergencyHalt", LvEmergencyHalt},
					{"CompleteHalt", LvCompleteHalt},
				}

				for _, tt := range tests {
					result, err := LevelIDFromString(tt.input)
					uassert.NoError(t, err)
					uassert.True(t, result == tt.expected)
				}
			},
		},
		{
			name: "invalid level strings",
			testFn: func(t *testing.T) {
				tests := []string{
					"invalid",
					"nohalt",    // case sensitive
					"NOHALT",    // case sensitive
					"NoHalt ",   // trailing space
					" NoHalt",   // leading space
					"",          // empty string
					"Unknown",   // unknown level
					"123",       // numeric
					"NoHalt123", // with numbers
				}

				for _, input := range tests {
					result, err := LevelIDFromString(input)
					uassert.Error(t, err)
					uassert.True(t, result == LevelID(0))
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.testFn(t)
		})
	}
}

func TestLevelExtended_BasicHaltLevel(t *testing.T) {
	t.Run("NewHaltLevel creates valid BasicHaltLevel", func(t *testing.T) {
		allowedOps := map[OpType]bool{
			OpTypePool:     true,
			OpTypePosition: false,
			OpTypeRouter:   true,
		}

		level := NewHaltLevel(LvNoHalt, "Test Level", "Test description", allowedOps)

		uassert.True(t, level.Level() == LvNoHalt)
		uassert.Equal(t, "Test Level", level.Name())
		uassert.Equal(t, "Test description", level.Desc())
	})

	t.Run("BasicHaltLevel IsOperationAllowed", func(t *testing.T) {
		allowedOps := map[OpType]bool{
			OpTypePool:     true,
			OpTypePosition: false,
			OpTypeRouter:   true,
		}

		level := NewHaltLevel(LvNoHalt, "Test Level", "Test description", allowedOps)

		poolOp := NewOperation(OpTypePool, "Pool", "Pool operations")
		positionOp := NewOperation(OpTypePosition, "Position", "Position operations")
		routerOp := NewOperation(OpTypeRouter, "Router", "Router operations")
		unknownOp := NewOperation(OpType("unknown"), "Unknown", "Unknown operations")

		uassert.True(t, level.IsOperationAllowed(poolOp))
		uassert.False(t, level.IsOperationAllowed(positionOp))
		uassert.True(t, level.IsOperationAllowed(routerOp))
		uassert.False(t, level.IsOperationAllowed(unknownOp)) // not in map
	})

	t.Run("BasicHaltLevel with empty allowedOps", func(t *testing.T) {
		allowedOps := map[OpType]bool{}
		level := NewHaltLevel(LvNoHalt, "Empty Level", "Empty description", allowedOps)

		testOp := NewOperation(OpTypePool, "Test", "Test operation")
		uassert.False(t, level.IsOperationAllowed(testOp))
	})

	t.Run("BasicHaltLevel map isolation", func(t *testing.T) {
		// Test that the internal map is isolated from the original
		originalMap := map[OpType]bool{
			OpTypePool: true,
		}

		level := NewHaltLevel(LvNoHalt, "Test Level", "Test description", originalMap)

		// Modify original map
		originalMap[OpTypePool] = false
		originalMap[OpTypePosition] = true

		// Level should not be affected
		poolOp := NewOperation(OpTypePool, "Pool", "Pool operations")
		positionOp := NewOperation(OpTypePosition, "Position", "Position operations")

		uassert.True(t, level.IsOperationAllowed(poolOp))      // still true
		uassert.False(t, level.IsOperationAllowed(positionOp)) // still false
	})
}

func TestLevelExtended_HaltLevels(t *testing.T) {
	t.Run("HaltLevels Iter with no matches", func(t *testing.T) {
		// Create levels directly to avoid the NewHaltLevel issue
		base1 := newBaseInfo("Level1", "Description1")
		ops1 := make(map[OpType]bool)
		level1 := BasicHaltLevel{base1, LvNoHalt, ops1}

		base2 := newBaseInfo("Level2", "Description2")
		ops2 := make(map[OpType]bool)
		level2 := BasicHaltLevel{base2, LvEmergencyHalt, ops2}

		levels := HaltLevels{level1, level2}

		// Function that never returns true
		result := levels.Iter(func(level HaltLevel) bool {
			return false
		})

		uassert.False(t, result)
	})

	t.Run("HaltLevels Iter with first match", func(t *testing.T) {
		// Create levels directly
		base1 := newBaseInfo("Level1", "Description1")
		ops1 := make(map[OpType]bool)
		level1 := BasicHaltLevel{base1, LvNoHalt, ops1}

		base2 := newBaseInfo("Level2", "Description2")
		ops2 := make(map[OpType]bool)
		level2 := BasicHaltLevel{base2, LvEmergencyHalt, ops2}

		levels := HaltLevels{level1, level2}

		// Function that returns true for first element
		result := levels.Iter(func(level HaltLevel) bool {
			return level.Level() == LvNoHalt
		})

		uassert.True(t, result)
	})

	t.Run("HaltLevels Iter with last match", func(t *testing.T) {
		// Create levels directly
		base1 := newBaseInfo("Level1", "Description1")
		ops1 := make(map[OpType]bool)
		level1 := BasicHaltLevel{base1, LvNoHalt, ops1}

		base2 := newBaseInfo("Level2", "Description2")
		ops2 := make(map[OpType]bool)
		level2 := BasicHaltLevel{base2, LvEmergencyHalt, ops2}

		levels := HaltLevels{level1, level2}

		// Function that returns true for last element
		result := levels.Iter(func(level HaltLevel) bool {
			return level.Level() == LvEmergencyHalt
		})

		uassert.True(t, result)
	})

	t.Run("HaltLevels Iter with empty slice", func(t *testing.T) {
		levels := HaltLevels{}

		result := levels.Iter(func(level HaltLevel) bool {
			return true
		})

		uassert.False(t, result)
	})

	t.Run("HaltLevels Iter execution order", func(t *testing.T) {
		// Create levels directly
		base1 := newBaseInfo("Level1", "Description1")
		ops1 := make(map[OpType]bool)
		level1 := BasicHaltLevel{base1, LvNoHalt, ops1}

		base2 := newBaseInfo("Level2", "Description2")
		ops2 := make(map[OpType]bool)
		level2 := BasicHaltLevel{base2, LvEmergencyHalt, ops2}

		base3 := newBaseInfo("Level3", "Description3")
		ops3 := make(map[OpType]bool)
		level3 := BasicHaltLevel{base3, LvCompleteHalt, ops3}

		levels := HaltLevels{level1, level2, level3}

		var visitedLevels []LevelID
		levels.Iter(func(level HaltLevel) bool {
			visitedLevels = append(visitedLevels, level.Level())
			return false // continue iteration
		})

		uassert.Equal(t, 3, len(visitedLevels))
		uassert.True(t, visitedLevels[0] == LvNoHalt)
		uassert.True(t, visitedLevels[1] == LvEmergencyHalt)
		uassert.True(t, visitedLevels[2] == LvCompleteHalt)
	})
}

func TestLevelExtended_CompositeOp(t *testing.T) {
	t.Run("CompositeOp string representation", func(t *testing.T) {
		uassert.Equal(t, "and", CompositeOpAnd.String())
		uassert.Equal(t, "or", CompositeOpOr.String())
		uassert.Equal(t, "undefined", CompositeOp(255).String())
	})

	t.Run("CompositeOpFromString case insensitive", func(t *testing.T) {
		tests := []struct {
			input    string
			expected CompositeOp
		}{
			{"and", CompositeOpAnd},
			{"AND", CompositeOpAnd},
			{"And", CompositeOpAnd},
			{"or", CompositeOpOr},
			{"OR", CompositeOpOr},
			{"Or", CompositeOpOr},
		}

		for _, tt := range tests {
			result, err := CompositeOpFromString(tt.input)
			uassert.NoError(t, err)
			uassert.True(t, result == tt.expected)
		}
	})
}

func TestLevelExtended_CompositeHaltLevel(t *testing.T) {
	t.Run("CompositeHaltLevel with AND operator", func(t *testing.T) {
		// Create two levels with different allowed operations
		level1 := NewHaltLevel(LvNoHalt, "Level1", "Description1", map[OpType]bool{
			OpTypePool:     true,
			OpTypePosition: false,
		})

		level2 := NewHaltLevel(LvEmergencyHalt, "Level2", "Description2", map[OpType]bool{
			OpTypePool:     true,
			OpTypePosition: true,
		})

		// Create composite level with AND operator
		composite := &CompositeHaltLevel{
			baseInfo: newBaseInfo("Composite", "Composite level"),
			levels:   HaltLevels{level1, level2},
			operator: CompositeOpAnd,
		}

		poolOp := NewOperation(OpTypePool, "Pool", "Pool operations")
		positionOp := NewOperation(OpTypePosition, "Position", "Position operations")

		// For AND: both levels must allow the operation
		uassert.True(t, composite.IsOperationAllowed(poolOp))      // both allow
		uassert.False(t, composite.IsOperationAllowed(positionOp)) // level1 doesn't allow
	})

	t.Run("CompositeHaltLevel with OR operator", func(t *testing.T) {
		// Create two levels with different allowed operations
		level1 := NewHaltLevel(LvNoHalt, "Level1", "Description1", map[OpType]bool{
			OpTypePool:     true,
			OpTypePosition: false,
		})

		level2 := NewHaltLevel(LvEmergencyHalt, "Level2", "Description2", map[OpType]bool{
			OpTypePool:     false,
			OpTypePosition: true,
		})

		// Create composite level with OR operator
		composite := &CompositeHaltLevel{
			baseInfo: newBaseInfo("Composite", "Composite level"),
			levels:   HaltLevels{level1, level2},
			operator: CompositeOpOr,
		}

		poolOp := NewOperation(OpTypePool, "Pool", "Pool operations")
		positionOp := NewOperation(OpTypePosition, "Position", "Position operations")
		routerOp := NewOperation(OpTypeRouter, "Router", "Router operations")

		// For OR: at least one level must allow the operation
		uassert.True(t, composite.IsOperationAllowed(poolOp))     // level1 allows
		uassert.True(t, composite.IsOperationAllowed(positionOp)) // level2 allows
		uassert.False(t, composite.IsOperationAllowed(routerOp))  // neither allows
	})

	t.Run("CompositeHaltLevel with undefined operator", func(t *testing.T) {
		level1 := NewHaltLevel(LvNoHalt, "Level1", "Description1", map[OpType]bool{
			OpTypePool: true,
		})

		composite := &CompositeHaltLevel{
			baseInfo: newBaseInfo("Composite", "Composite level"),
			levels:   HaltLevels{level1},
			operator: CompositeOp(255), // undefined operator
		}

		poolOp := NewOperation(OpTypePool, "Pool", "Pool operations")

		// Undefined operator should return false
		uassert.False(t, composite.IsOperationAllowed(poolOp))
	})

	t.Run("CompositeHaltLevel with empty levels", func(t *testing.T) {
		composite := &CompositeHaltLevel{
			baseInfo: newBaseInfo("Composite", "Composite level"),
			levels:   HaltLevels{},
			operator: CompositeOpAnd,
		}

		poolOp := NewOperation(OpTypePool, "Pool", "Pool operations")

		// Empty levels with AND should return true (vacuous truth)
		uassert.True(t, composite.IsOperationAllowed(poolOp))

		// Change to OR operator
		composite.operator = CompositeOpOr
		// Empty levels with OR should return false
		uassert.False(t, composite.IsOperationAllowed(poolOp))
	})

	t.Run("CompositeHaltLevel Level method", func(t *testing.T) {
		composite := &CompositeHaltLevel{
			baseInfo: newBaseInfo("Composite", "Composite level"),
			levels:   HaltLevels{},
			operator: CompositeOpAnd,
		}

		// Should return placeholder value 0
		uassert.True(t, composite.Level() == LevelID(0))
	})

	t.Run("CompositeHaltLevel implements HaltLevel interface", func(t *testing.T) {
		composite := &CompositeHaltLevel{
			baseInfo: newBaseInfo("Test", "Test description"),
			levels:   HaltLevels{},
			operator: CompositeOpAnd,
		}

		// Should implement HaltLevel interface
		var level HaltLevel = composite
		uassert.Equal(t, "Test", level.Name())
		uassert.Equal(t, "Test description", level.Desc())
		uassert.True(t, level.Level() == LevelID(0))
	})
}
