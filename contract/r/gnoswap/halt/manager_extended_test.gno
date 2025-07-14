package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestManager_SetOperationStatusExtended(t *testing.T) {
	tests := []struct {
		name                 string
		setupManager         func() *Manager
		opType               OpType
		allowed              bool
		expectedHasPanic     bool
		expectedPanicMessage string
		expectedError        bool
		expectedErrorMessage string
	}{
		{
			name: "Fail with composite level",
			setupManager: func() *Manager {
				mgr := NewManager()
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
				compositeID := LevelID(99)
				mgr.levels[compositeID] = composite
				mgr.currentLevel = composite
				mgr.levels[LevelID(0)] = composite
				return mgr
			},
			opType:               OpTypePool,
			allowed:              false,
			expectedError:        true,
			expectedErrorMessage: "cannot modify composite halt levels directly",
		},
		{
			name: "Fail with invalid current level",
			setupManager: func() *Manager {
				mgr := NewManager()
				invalidLevel := NewHaltLevel(LevelID(127), "Invalid", "Invalid level", map[OpType]bool{})
				mgr.currentLevel = invalidLevel
				return mgr
			},
			opType:               OpTypePool,
			allowed:              false,
			expectedError:        true,
			expectedErrorMessage: "invalid current halt level",
		},
		{
			name: "Success modify correct level",
			setupManager: func() *Manager {
				mgr := DefaultManager()
				mgr.SetCurrentLevel(LvNoHalt)
				return mgr
			},
			opType:        OpTypePool,
			allowed:       false,
			expectedError: false,
		},
		{
			name: "Success with new operation type",
			setupManager: func() *Manager {
				mgr := DefaultManager()
				mgr.SetCurrentLevel(LvNoHalt)
				return mgr
			},
			opType:        OpType("new_operation"),
			allowed:       true,
			expectedError: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			mgr := tc.setupManager()

			// when
			err := mgr.SetOperationStatus(tc.opType, tc.allowed)

			// then
			if tc.expectedHasPanic {
				t.Errorf("[%s] expected panic but none occurred", tc.name)
			} else if tc.expectedError {
				uassert.Error(t, err)
				if tc.expectedErrorMessage != "" {
					uassert.Equal(t, tc.expectedErrorMessage, err.Error())
				}
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestManager_StatusExtended(t *testing.T) {
	tests := []struct {
		name                 string
		setupManager         func() *Manager
		opType               OpType
		expectedStatus       string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name: "Return current level name regardless of operation",
			setupManager: func() *Manager {
				mgr := DefaultManager()
				mgr.SetCurrentLevel(LvNoHalt)
				return mgr
			},
			opType:         OpTypePool,
			expectedStatus: "NoHalt",
		},
		{
			name: "Return EmergencyHalt level name",
			setupManager: func() *Manager {
				mgr := DefaultManager()
				mgr.SetCurrentLevel(LvEmergencyHalt)
				return mgr
			},
			opType:         OpTypePosition,
			expectedStatus: "EmergencyHalt",
		},
		{
			name: "Return CompleteHalt level name",
			setupManager: func() *Manager {
				mgr := DefaultManager()
				mgr.SetCurrentLevel(LvCompleteHalt)
				return mgr
			},
			opType:         OpType("nonexistent"),
			expectedStatus: "CompleteHalt",
		},
		{
			name: "Return custom level name",
			setupManager: func() *Manager {
				mgr := NewManager()
				customLevel := NewHaltLevel(LevelID(10), "CustomLevel", "Custom description", map[OpType]bool{
					OpTypePool: true,
				})
				mgr.RegisterHaltLevel(customLevel)
				mgr.SetCurrentLevel(LevelID(10))
				return mgr
			},
			opType:         OpTypePool,
			expectedStatus: "CustomLevel",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			mgr := tc.setupManager()

			// when
			status := mgr.Status(tc.opType)

			// then
			if tc.expectedHasPanic {
				t.Errorf("[%s] expected panic but none occurred", tc.name)
			} else {
				uassert.Equal(t, tc.expectedStatus, status)
			}
		})
	}
}

func TestManager_RegisterOperationExtended(t *testing.T) {
	tests := []struct {
		name                 string
		setupManager         func() *Manager
		operation            Operation
		expectedHasPanic     bool
		expectedPanicMessage string
		expectedName         string
		expectedDesc         string
	}{
		{
			name: "Success overwrite existing operation",
			setupManager: func() *Manager {
				return DefaultManager()
			},
			operation:    NewOperation(OpTypeWithdraw, "New Withdraw", "New withdraw description"),
			expectedName: "New Withdraw",
			expectedDesc: "New withdraw description",
		},
		{
			name: "Success register empty operation",
			setupManager: func() *Manager {
				return NewManager()
			},
			operation:    NewOperation(OpType(""), "", ""),
			expectedName: "",
			expectedDesc: "",
		},
		{
			name: "Success register operation with special characters",
			setupManager: func() *Manager {
				return NewManager()
			},
			operation:    NewOperation(OpType("special@op#1"), "Special & Op", "Description with <chars>"),
			expectedName: "Special & Op",
			expectedDesc: "Description with <chars>",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			mgr := tc.setupManager()

			// when
			mgr.RegisterOperation(tc.operation)

			// then
			if tc.expectedHasPanic {
				t.Errorf("[%s] expected panic but none occurred", tc.name)
			} else {
				registeredOp := mgr.operations[tc.operation.Type()]
				uassert.Equal(t, tc.expectedName, registeredOp.Name())
				uassert.Equal(t, tc.expectedDesc, registeredOp.Desc())
			}
		})
	}
}

func TestManager_RegisterHaltLevelExtended(t *testing.T) {
	tests := []struct {
		name                 string
		setupManager         func() *Manager
		haltLevel            HaltLevel
		expectedHasPanic     bool
		expectedPanicMessage string
		expectedName         string
		expectedDesc         string
		expectedAllowed      bool
	}{
		{
			name: "Success overwrite existing level",
			setupManager: func() *Manager {
				return DefaultManager()
			},
			haltLevel: NewHaltLevel(LvNoHalt, "New NoHalt", "New description", map[OpType]bool{
				OpTypePool: false,
			}),
			expectedName:    "New NoHalt",
			expectedDesc:    "New description",
			expectedAllowed: false,
		},
		{
			name: "Success register level with duplicate ID",
			setupManager: func() *Manager {
				mgr := NewManager()
				level1 := NewHaltLevel(LevelID(10), "Level1", "Description1", map[OpType]bool{
					OpTypePool: true,
				})
				mgr.RegisterHaltLevel(level1)
				return mgr
			},
			haltLevel: NewHaltLevel(LevelID(10), "Level2", "Description2", map[OpType]bool{
				OpTypePool: false,
			}),
			expectedName:    "Level2",
			expectedDesc:    "Description2",
			expectedAllowed: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			mgr := tc.setupManager()

			// when
			mgr.RegisterHaltLevel(tc.haltLevel)

			// then
			if tc.expectedHasPanic {
				t.Errorf("[%s] expected panic but none occurred", tc.name)
			} else {
				registeredLevel := mgr.levels[tc.haltLevel.Level()]
				uassert.Equal(t, tc.expectedName, registeredLevel.Name())
				uassert.Equal(t, tc.expectedDesc, registeredLevel.Desc())
				poolOp := NewOperation(OpTypePool, "Pool", "Pool operations")
				uassert.Equal(t, tc.expectedAllowed, registeredLevel.IsOperationAllowed(poolOp))
			}
		})
	}
}

func TestManager_LevelExtended(t *testing.T) {
	tests := []struct {
		name                 string
		setupManager         func() *Manager
		expectedHasPanic     bool
		expectedPanicMessage string
		expectedLevelID      LevelID
		expectedName         string
		expectedDesc         string
	}{
		{
			name: "Return current level NoHalt",
			setupManager: func() *Manager {
				mgr := DefaultManager()
				mgr.SetCurrentLevel(LvNoHalt)
				return mgr
			},
			expectedLevelID: LvNoHalt,
			expectedName:    "NoHalt",
		},
		{
			name: "Return current level EmergencyHalt",
			setupManager: func() *Manager {
				mgr := DefaultManager()
				mgr.SetCurrentLevel(LvEmergencyHalt)
				return mgr
			},
			expectedLevelID: LvEmergencyHalt,
			expectedName:    "EmergencyHalt",
		},
		{
			name: "Return current level CompleteHalt",
			setupManager: func() *Manager {
				mgr := DefaultManager()
				mgr.SetCurrentLevel(LvCompleteHalt)
				return mgr
			},
			expectedLevelID: LvCompleteHalt,
			expectedName:    "CompleteHalt",
		},
		{
			name: "Level method consistency",
			setupManager: func() *Manager {
				return DefaultManager()
			},
			expectedLevelID: LvNoHalt,
			expectedName:    "NoHalt",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			mgr := tc.setupManager()

			// when
			level := mgr.Level()

			// then
			if tc.expectedHasPanic {
				t.Errorf("[%s] expected panic but none occurred", tc.name)
			} else {
				uassert.True(t, level.Level() == tc.expectedLevelID)
				uassert.Equal(t, tc.expectedName, level.Name())
			}
		})
	}
}

func TestManager_NewManagerExtended(t *testing.T) {
	tests := []struct {
		name                 string
		options              []ManagerOption
		expectedHasPanic     bool
		expectedPanicMessage string
		expectedOpsCount     int
		expectedLevelsCount  int
		expectedLevelID      LevelID
		expectedLevelName    string
	}{
		{
			name: "Success with multiple options",
			options: []ManagerOption{
				WithOperations([]Operation{
					NewOperation(OpType("custom1"), "Custom 1", "First custom operation"),
					NewOperation(OpType("custom2"), "Custom 2", "Second custom operation"),
				}),
				WithLevels([]HaltLevel{
					NewHaltLevel(LevelID(10), "Custom Level 1", "First custom level", map[OpType]bool{
						OpType("custom1"): true,
						OpType("custom2"): false,
					}),
					NewHaltLevel(LevelID(11), "Custom Level 2", "Second custom level", map[OpType]bool{
						OpType("custom1"): false,
						OpType("custom2"): true,
					}),
				}),
				WithInitialLevel(LevelID(10)),
			},
			expectedOpsCount:    2,
			expectedLevelsCount: 2,
			expectedLevelID:     LevelID(10),
			expectedLevelName:   "Custom Level 1",
		},
		{
			name: "Success with empty options",
			options: []ManagerOption{
				WithOperations([]Operation{}),
				WithLevels([]HaltLevel{}),
			},
			expectedOpsCount:    0,
			expectedLevelsCount: 0,
		},
		{
			name: "Success with options order independence",
			options: []ManagerOption{
				WithLevels([]HaltLevel{
					NewHaltLevel(LevelID(10), "Test Level", "Test description", map[OpType]bool{
						OpType("test"): true,
					}),
				}),
				WithOperations([]Operation{
					NewOperation(OpType("test"), "Test", "Test operation"),
				}),
				WithInitialLevel(LevelID(10)),
			},
			expectedOpsCount:    1,
			expectedLevelsCount: 1,
			expectedLevelID:     LevelID(10),
			expectedLevelName:   "Test Level",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// (no setup needed)

			// when
			mgr := NewManager(tc.options...)

			// then
			if tc.expectedHasPanic {
				t.Errorf("[%s] expected panic but none occurred", tc.name)
			} else {
				uassert.Equal(t, tc.expectedOpsCount, len(mgr.operations))
				uassert.Equal(t, tc.expectedLevelsCount, len(mgr.levels))
				if tc.expectedLevelID != LevelID(0) {
					uassert.True(t, mgr.Level().Level() == tc.expectedLevelID)
					uassert.Equal(t, tc.expectedLevelName, mgr.Level().Name())
				}
			}
		})
	}
}

// Helper functions
func setupManagerTest() *Manager {
	return DefaultManager()
}

func setupEmptyManagerTest() *Manager {
	return NewManager()
}
