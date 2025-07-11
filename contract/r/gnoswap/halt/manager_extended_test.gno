package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestManagerSetOperationStatusEdgeCases(t *testing.T) {
	t.Run("SetOperationStatus with composite level should fail", func(t *testing.T) {
		mgr := NewManager()

		// Create a composite level
		level1 := NewHaltLevel(LvNoHalt, "Level1", "Description1", map[OpType]bool{
			OpTypePool: true,
		})
		level2 := NewHaltLevel(LvEmergencyHalt, "Level2", "Description2", map[OpType]bool{
			OpTypePool: false,
		})

		composite := &CompositeHaltLevel{
			baseInfo: newBaseInfo("Composite", "Composite level"),
			levels:   HaltLevels{level1, level2},
			operator: CompositeOpAnd,
		}

		// Register the composite level with a custom ID
		compositeID := LevelID(99)
		mgr.levels[compositeID] = composite
		mgr.currentLevel = composite

		// Also register it with ID 0 (since composite.Level() returns 0)
		mgr.levels[LevelID(0)] = composite

		// Try to set operation status on composite level
		err := mgr.SetOperationStatus(OpTypePool, false)
		uassert.Error(t, err)
		uassert.Equal(t, "cannot modify composite halt levels directly", err.Error())
	})

	t.Run("SetOperationStatus with invalid current level", func(t *testing.T) {
		mgr := NewManager()

		// Set current level to something not in the levels map
		// Use a proper map to avoid runtime errors
		invalidLevel := NewHaltLevel(LevelID(127), "Invalid", "Invalid level", map[OpType]bool{})
		mgr.currentLevel = invalidLevel

		err := mgr.SetOperationStatus(OpTypePool, false)
		uassert.Error(t, err)
		uassert.Equal(t, "invalid current halt level", err.Error())
	})

	t.Run("SetOperationStatus modifies the correct level", func(t *testing.T) {
		mgr := DefaultManager()

		// Set to NoHalt
		err := mgr.SetCurrentLevel(LvNoHalt)
		uassert.NoError(t, err)

		// Initially pool should be allowed
		poolOp := NewOperation(OpTypePool, "Pool", "Pool operations")
		uassert.True(t, mgr.Level().IsOperationAllowed(poolOp))

		// Disable pool operation
		err = mgr.SetOperationStatus(OpTypePool, false)
		uassert.NoError(t, err)

		// Now pool should be disabled
		uassert.False(t, mgr.Level().IsOperationAllowed(poolOp))

		// But other levels should not be affected
		err = mgr.SetCurrentLevel(LvEmergencyHalt)
		uassert.NoError(t, err)
		err = mgr.SetCurrentLevel(LvNoHalt)
		uassert.NoError(t, err)

		// Pool should still be disabled in NoHalt
		uassert.False(t, mgr.Level().IsOperationAllowed(poolOp))
	})

	t.Run("SetOperationStatus with new operation type", func(t *testing.T) {
		mgr := DefaultManager()

		// Set to NoHalt
		err := mgr.SetCurrentLevel(LvNoHalt)
		uassert.NoError(t, err)

		// Add new operation type that doesn't exist in the level
		newOpType := OpType("new_operation")
		newOp := NewOperation(newOpType, "New Op", "New operation")

		// Initially should not be allowed (not in map)
		uassert.False(t, mgr.Level().IsOperationAllowed(newOp))

		// Enable the new operation
		err = mgr.SetOperationStatus(newOpType, true)
		uassert.NoError(t, err)

		// Now should be allowed
		uassert.True(t, mgr.Level().IsOperationAllowed(newOp))
	})
}

func TestManagerStatusMethod(t *testing.T) {
	t.Run("Status returns current level name regardless of operation", func(t *testing.T) {
		mgr := DefaultManager()

		// Test with different levels
		levels := []struct {
			levelID      LevelID
			expectedName string
		}{
			{LvNoHalt, "NoHalt"},
			{LvEmergencyHalt, "EmergencyHalt"},
			{LvCompleteHalt, "CompleteHalt"},
		}

		for _, level := range levels {
			err := mgr.SetCurrentLevel(level.levelID)
			uassert.NoError(t, err)

			// Status should return the same name regardless of operation type
			status1 := mgr.Status(OpTypePool)
			status2 := mgr.Status(OpTypePosition)
			status3 := mgr.Status(OpType("nonexistent"))

			uassert.Equal(t, level.expectedName, status1)
			uassert.Equal(t, level.expectedName, status2)
			uassert.Equal(t, level.expectedName, status3)
		}
	})

	t.Run("Status with custom level", func(t *testing.T) {
		mgr := NewManager()

		customLevel := NewHaltLevel(LevelID(10), "CustomLevel", "Custom description", map[OpType]bool{
			OpTypePool: true,
		})
		mgr.RegisterHaltLevel(customLevel)

		err := mgr.SetCurrentLevel(LevelID(10))
		uassert.NoError(t, err)

		status := mgr.Status(OpTypePool)
		uassert.Equal(t, "CustomLevel", status)
	})
}

func TestManagerRegisterOperationEdgeCases(t *testing.T) {
	t.Run("RegisterOperation overwrites existing operation", func(t *testing.T) {
		mgr := DefaultManager()

		// Create new operation with same type but different name
		newOp := NewOperation(OpTypeWithdraw, "New Withdraw", "New withdraw description")

		// Register should overwrite the existing one
		mgr.RegisterOperation(newOp)

		// Verify the new operation is registered
		registeredOp := mgr.operations[OpTypeWithdraw]
		uassert.Equal(t, "New Withdraw", registeredOp.Name())
		uassert.Equal(t, "New withdraw description", registeredOp.Desc())
	})

	t.Run("RegisterOperation with empty operation", func(t *testing.T) {
		mgr := NewManager()

		emptyOp := NewOperation(OpType(""), "", "")
		mgr.RegisterOperation(emptyOp)

		// Should be registered even with empty values
		registeredOp := mgr.operations[OpType("")]
		uassert.Equal(t, "", registeredOp.Name())
		uassert.Equal(t, "", registeredOp.Desc())
	})

	t.Run("RegisterOperation with special characters", func(t *testing.T) {
		mgr := NewManager()

		specialOp := NewOperation(OpType("special@op#1"), "Special & Op", "Description with <chars>")
		mgr.RegisterOperation(specialOp)

		registeredOp := mgr.operations[OpType("special@op#1")]
		uassert.Equal(t, "Special & Op", registeredOp.Name())
		uassert.Equal(t, "Description with <chars>", registeredOp.Desc())
	})
}

func TestManagerRegisterHaltLevelEdgeCases(t *testing.T) {
	t.Run("RegisterHaltLevel overwrites existing level", func(t *testing.T) {
		mgr := DefaultManager()

		// Create new level with same ID but different name
		newLevel := NewHaltLevel(LvNoHalt, "New NoHalt", "New description", map[OpType]bool{
			OpTypePool: false, // Different from default
		})

		// Register should overwrite the existing one
		mgr.RegisterHaltLevel(newLevel)

		// Verify the new level is registered
		registeredLevel := mgr.levels[LvNoHalt]
		uassert.Equal(t, "New NoHalt", registeredLevel.Name())
		uassert.Equal(t, "New description", registeredLevel.Desc())

		// Verify the operation configuration is also different
		poolOp := NewOperation(OpTypePool, "Pool", "Pool operations")
		uassert.False(t, registeredLevel.IsOperationAllowed(poolOp))
	})

	t.Run("RegisterHaltLevel with duplicate level ID", func(t *testing.T) {
		mgr := NewManager()

		// Create two levels with same ID but different names
		level1 := NewHaltLevel(LevelID(10), "Level1", "Description1", map[OpType]bool{
			OpTypePool: true,
		})
		level2 := NewHaltLevel(LevelID(10), "Level2", "Description2", map[OpType]bool{
			OpTypePool: false,
		})

		mgr.RegisterHaltLevel(level1)
		mgr.RegisterHaltLevel(level2) // Should overwrite level1

		// Verify level2 is registered (overwrote level1)
		registeredLevel := mgr.levels[LevelID(10)]
		uassert.Equal(t, "Level2", registeredLevel.Name())
		uassert.Equal(t, "Description2", registeredLevel.Desc())

		poolOp := NewOperation(OpTypePool, "Pool", "Pool operations")
		uassert.False(t, registeredLevel.IsOperationAllowed(poolOp))
	})
}

func TestManagerLevelMethod(t *testing.T) {
	t.Run("Level returns current level", func(t *testing.T) {
		mgr := DefaultManager()

		// Test with different levels
		levels := []LevelID{LvNoHalt, LvEmergencyHalt, LvCompleteHalt}

		for _, levelID := range levels {
			err := mgr.SetCurrentLevel(levelID)
			uassert.NoError(t, err)

			currentLevel := mgr.Level()
			uassert.True(t, currentLevel.Level() == levelID)
		}
	})

	t.Run("Level method consistency", func(t *testing.T) {
		mgr := DefaultManager()

		// Multiple calls should return the same level
		level1 := mgr.Level()
		level2 := mgr.Level()

		uassert.True(t, level1.Level() == level2.Level())
		uassert.Equal(t, level1.Name(), level2.Name())
		uassert.Equal(t, level1.Desc(), level2.Desc())
	})

	t.Run("Level method after operations", func(t *testing.T) {
		mgr := DefaultManager()

		// Set to NoHalt
		err := mgr.SetCurrentLevel(LvNoHalt)
		uassert.NoError(t, err)

		initialLevel := mgr.Level()

		// Modify operation status
		err = mgr.SetOperationStatus(OpTypePool, false)
		uassert.NoError(t, err)

		// Level should still return the same level object
		modifiedLevel := mgr.Level()
		uassert.True(t, initialLevel.Level() == modifiedLevel.Level())
		uassert.Equal(t, initialLevel.Name(), modifiedLevel.Name())
		uassert.Equal(t, initialLevel.Desc(), modifiedLevel.Desc())

		// But operation should be disabled
		poolOp := NewOperation(OpTypePool, "Pool", "Pool operations")
		uassert.False(t, modifiedLevel.IsOperationAllowed(poolOp))
	})
}

func TestManagerWithOptionsComplexScenarios(t *testing.T) {
	t.Run("NewManager with multiple options", func(t *testing.T) {
		// Create custom operations
		customOps := []Operation{
			NewOperation(OpType("custom1"), "Custom 1", "First custom operation"),
			NewOperation(OpType("custom2"), "Custom 2", "Second custom operation"),
		}

		// Create custom levels
		customLevels := []HaltLevel{
			NewHaltLevel(LevelID(10), "Custom Level 1", "First custom level", map[OpType]bool{
				OpType("custom1"): true,
				OpType("custom2"): false,
			}),
			NewHaltLevel(LevelID(11), "Custom Level 2", "Second custom level", map[OpType]bool{
				OpType("custom1"): false,
				OpType("custom2"): true,
			}),
		}

		// Create manager with all options
		mgr := NewManager(
			WithOperations(customOps),
			WithLevels(customLevels),
			WithInitialLevel(LevelID(10)),
		)

		// Verify all operations are registered
		for _, op := range customOps {
			registeredOp, exists := mgr.operations[op.Type()]
			uassert.True(t, exists)
			uassert.Equal(t, op.Name(), registeredOp.Name())
			uassert.Equal(t, op.Desc(), registeredOp.Desc())
		}

		// Verify all levels are registered
		for _, level := range customLevels {
			registeredLevel, exists := mgr.levels[level.Level()]
			uassert.True(t, exists)
			uassert.Equal(t, level.Name(), registeredLevel.Name())
			uassert.Equal(t, level.Desc(), registeredLevel.Desc())
		}

		// Verify initial level is set correctly
		uassert.True(t, mgr.Level().Level() == LevelID(10))
		uassert.Equal(t, "Custom Level 1", mgr.Level().Name())
	})

	t.Run("NewManager with empty options", func(t *testing.T) {
		mgr := NewManager(
			WithOperations([]Operation{}),
			WithLevels([]HaltLevel{}),
		)

		// Should have empty maps
		uassert.Equal(t, 0, len(mgr.operations))
		uassert.Equal(t, 0, len(mgr.levels))
		uassert.Equal(t, nil, mgr.currentLevel)
	})

	t.Run("NewManager options order independence", func(t *testing.T) {
		customOp := NewOperation(OpType("test"), "Test", "Test operation")
		customLevel := NewHaltLevel(LevelID(10), "Test Level", "Test description", map[OpType]bool{
			OpType("test"): true,
		})

		// Create manager with options in one order
		mgr1 := NewManager(
			WithOperations([]Operation{customOp}),
			WithLevels([]HaltLevel{customLevel}),
			WithInitialLevel(LevelID(10)),
		)

		// Create manager with options in different order
		mgr2 := NewManager(
			WithLevels([]HaltLevel{customLevel}),
			WithOperations([]Operation{customOp}),
			WithInitialLevel(LevelID(10)),
		)

		// Both should have the same result
		uassert.True(t, mgr1.Level().Level() == mgr2.Level().Level())
		uassert.Equal(t, mgr1.Level().Name(), mgr2.Level().Name())
		uassert.Equal(t, len(mgr1.operations), len(mgr2.operations))
		uassert.Equal(t, len(mgr1.levels), len(mgr2.levels))
	})
}
