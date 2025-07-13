package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestManager_DefaultManager(t *testing.T) {
	tests := []struct {
		name                 string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success creates default manager with NoHalt level",
			expectedHasPanic: false,
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
			// when
			mgr := DefaultManager()

			// then
			uassert.Equal(t, "NoHalt", mgr.Level().Name())
			_, exists := mgr.operations[OpTypeWithdraw]
			uassert.True(t, exists)
		})
	}
}

func TestManager_NewManager(t *testing.T) {
	tests := []struct {
		name                 string
		setupFn              func() *Manager
		expectedLevelName    string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name: "Success with custom operations and levels",
			setupFn: func() *Manager {
				customOp := NewOperation(OpType("customOp"), "Custom Op", "Custom operation")
				customLevel := NewHaltLevel(LevelID(10), "CustomLevel", "Custom level", map[OpType]bool{
					OpType("customOp"): true,
				})
				return NewManager(
					WithOperations([]Operation{customOp}),
					WithLevels([]HaltLevel{customLevel}),
					WithInitialLevel(LevelID(10)),
				)
			},
			expectedLevelName: "CustomLevel",
			expectedHasPanic:  false,
		},
		{
			name: "Error with invalid initial level",
			setupFn: func() *Manager {
				return NewManager(WithInitialLevel(LevelID(255)))
			},
			expectedHasPanic:     true,
			expectedPanicMessage: "invalid halt level: 255",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.True(t, tc.expectedHasPanic)
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// when
			mgr := tc.setupFn()

			// then
			if !tc.expectedHasPanic {
				uassert.Equal(t, tc.expectedLevelName, mgr.currentLevel.Name())
			}
		})
	}
}

func TestManager_SetCurrentLevel(t *testing.T) {
	tests := []struct {
		name                 string
		inputLevel           LevelID
		expectedLevelName    string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:              "Success set to ContractHalt",
			inputLevel:        LvContractHalt,
			expectedLevelName: "ContractHalt",
			expectedHasPanic:  false,
		},
		{
			name:                 "Error with invalid level",
			inputLevel:           LevelID(255),
			expectedHasPanic:     true,
			expectedPanicMessage: "invalid halt level: 255",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.True(t, tc.expectedHasPanic)
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			mgr := DefaultManager()

			// when
			err := mgr.SetCurrentLevel(tc.inputLevel)

			// then
			if tc.expectedHasPanic {
				uassert.True(t, err != nil)
			} else {
				uassert.True(t, err == nil)
				uassert.Equal(t, tc.expectedLevelName, mgr.Level().Name())
			}
		})
	}
}

func TestManager_Status(t *testing.T) {
	tests := []struct {
		name                 string
		inputLevel           LevelID
		inputOpType          OpType
		expectedStatus       string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success returns EmergencyHalt status",
			inputLevel:       LvEmergencyHalt,
			inputOpType:      OpTypePool,
			expectedStatus:   "EmergencyHalt",
			expectedHasPanic: false,
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
			mgr := DefaultManager()
			err := mgr.SetCurrentLevel(tc.inputLevel)
			uassert.True(t, err == nil)

			// when
			status := mgr.Status(tc.inputOpType)

			// then
			uassert.Equal(t, tc.expectedStatus, status)
		})
	}
}

func TestManager_RegisterHaltLevel(t *testing.T) {
	tests := []struct {
		name                 string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success register custom halt level",
			expectedHasPanic: false,
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
			mgr := DefaultManager()
			const CustomHaltLevel = LevelID(5)
			customLevel := NewHaltLevel(CustomHaltLevel, "CustomHalt", "Custom halt level", map[OpType]bool{
				OpTypePool: false,
			})

			// when
			mgr.RegisterHaltLevel(customLevel)
			err := mgr.SetCurrentLevel(CustomHaltLevel)

			// then
			uassert.True(t, err == nil)
			uassert.Equal(t, "CustomHalt", mgr.Level().Name())
		})
	}
}

func TestManager_RegisterOperation(t *testing.T) {
	tests := []struct {
		name                 string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success register custom operation",
			expectedHasPanic: false,
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
			mgr := DefaultManager()
			customOp := NewOperation(OpType("customTest"), "Custom Test", "Custom test operation")

			// when
			mgr.RegisterOperation(customOp)

			// then
			_, exists := mgr.operations[OpType("customTest")]
			uassert.True(t, exists)
		})
	}
}
