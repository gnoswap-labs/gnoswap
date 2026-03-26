package halt

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestConfig_Constants(t *testing.T) {
	// ConfigNone: all operations enabled (no bits set)
	uassert.Equal(t, ConfigNone, uint64(0))

	// ConfigSafeMode: only withdraw halted
	uassert.Equal(t, ConfigSafeMode, uint64(OpTypeWithdraw))

	// ConfigEmergency: all halted except governance and withdraw
	expectedEmergency := uint64(OpTypeAll) &^ uint64(OpTypeGovernance|OpTypeWithdraw)
	uassert.Equal(t, ConfigEmergency, expectedEmergency)

	// ConfigComplete: all operations halted
	uassert.Equal(t, ConfigComplete, uint64(OpTypeAll))
}

func TestConfig_AllConfigLevelsIntegration(t *testing.T) {
	tests := []struct {
		name          string
		config        uint64
		expectedState map[OpType]bool
	}{
		{
			name:   "None config halts nothing",
			config: ConfigNone,
			expectedState: map[OpType]bool{
				OpTypePool:       false,
				OpTypeGovernance: false,
				OpTypeRouter:     false,
				OpTypeWithdraw:   false,
			},
		},
		{
			name:   "Safe mode halts withdraw only",
			config: ConfigSafeMode,
			expectedState: map[OpType]bool{
				OpTypePool:       false,
				OpTypeGovernance: false,
				OpTypeRouter:     false,
				OpTypeWithdraw:   true,
			},
		},
		{
			name:   "Emergency halts most except governance and withdraw",
			config: ConfigEmergency,
			expectedState: map[OpType]bool{
				OpTypePool:       true,
				OpTypeGovernance: false,
				OpTypeRouter:     true,
				OpTypeWithdraw:   false,
			},
		},
		{
			name:   "Complete halts all",
			config: ConfigComplete,
			expectedState: map[OpType]bool{
				OpTypePool:       true,
				OpTypeGovernance: true,
				OpTypeRouter:     true,
				OpTypeWithdraw:   true,
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			for op, expected := range tc.expectedState {
				halted := tc.config&uint64(op) != 0
				uassert.Equal(t, halted, expected)
			}
		})
	}
}
