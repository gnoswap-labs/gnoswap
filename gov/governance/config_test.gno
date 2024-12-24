package governance

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
)

var (
	adminAddr    = testutils.TestAddress("admin")
	notAdminAddr = testutils.TestAddress("notadmin")
)

// we cannot call init() in test, so we mock it here.
// it's totally same as init()
func mockInit(t *testing.T) {
	t.Helper()
	config = Config{
		VotingStartDelay:              uint64(86400),
		VotingPeriod:                  uint64(604800),
		VotingWeightSmoothingDuration: uint64(86400),
		Quorum:                        uint64(50),
		ProposalCreationThreshold:     uint64(1_000_000_000),
		ExecutionDelay:                uint64(86400),
		ExecutionWindow:               uint64(2592000),
	}

	configVersions[uint64(len(configVersions)+1)] = config
}

func resetGlobalConfig(t *testing.T) {
	t.Helper()
	config = Config{}
	configVersions = make(map[uint64]Config)
}

func TestInitialConfig(t *testing.T) {
	resetGlobalConfig(t)
	mockInit(t)

	tests := []struct {
		name     string
		got      uint64
		expected uint64
	}{
		{"VotingStartDelay", config.VotingStartDelay, 86400},
		{"VotingPeriod", config.VotingPeriod, 604800},
		{"VotingWeightSmoothingDuration", config.VotingWeightSmoothingDuration, 86400},
		{"Quorum", config.Quorum, 50},
		{"ProposalCreationThreshold", config.ProposalCreationThreshold, 1_000_000_000},
		{"ExecutionDelay", config.ExecutionDelay, 86400},
		{"ExecutionWindow", config.ExecutionWindow, 2592000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.got != tt.expected {
				t.Errorf("Incorrect initial %s: got %d, want %d",
					tt.name, tt.got, tt.expected)
			}
		})
	}

	if len(configVersions) != 1 {
		t.Errorf("Expected 1 config version, got %d", len(configVersions))
	}
}

func TestReconfigureByAdmin(t *testing.T) {
	resetGlobalConfig(t)
	mockInit(t)

	tests := []struct {
		name          string
		caller        std.Address
		newConfig     Config
		expectError   bool
		errorContains string
	}{
		{
			name:   "Valid admin reconfiguration",
			caller: adminAddr,
			newConfig: Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  700000,
				VotingWeightSmoothingDuration: 90000,
				Quorum:                        60,
				ProposalCreationThreshold:     2_000_000_000,
				ExecutionDelay:                90000,
				ExecutionWindow:               3000000,
			},
			expectError: false,
		},
		{
			name:   "Non-admin caller",
			caller: testutils.TestAddress("notadmin"),
			newConfig: Config{
				VotingStartDelay: 86400,
			},
			expectError:   true,
			errorContains: "admin",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var err error
			func() {
				defer func() {
					if r := recover(); r != nil {
						err = r.(error)
					}
				}()

				ReconfigureByAdmin(
					tt.newConfig.VotingStartDelay,
					tt.newConfig.VotingPeriod,
					tt.newConfig.VotingWeightSmoothingDuration,
					tt.newConfig.Quorum,
					tt.newConfig.ProposalCreationThreshold,
					tt.newConfig.ExecutionDelay,
					tt.newConfig.ExecutionWindow,
				)
			}()

			if tt.expectError {
				if err == nil {
					t.Errorf("Expected error containing '%s', got none", tt.errorContains)
				}
				return
			}

			if config.VotingStartDelay != tt.newConfig.VotingStartDelay {
				t.Errorf("VotingStartDelay not updated correctly: got %d, want %d",
					config.VotingStartDelay, tt.newConfig.VotingStartDelay)
			}
		})
	}
}

func TestGetConfigVersion(t *testing.T) {
	// don't call mockInit here.
	resetGlobalConfig(t)

	tests := []struct {
		name        string
		version     uint64
		expectError bool
	}{
		{
			name:        "Get current config (version 0)",
			version:     0,
			expectError: false,
		},
		{
			name:        "Get existing version",
			version:     1,
			expectError: false,
		},
		{
			name:        "Get non-existent version",
			version:     999,
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var result Config

			if tt.expectError {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("expected panic, got none")
					}
				}()
				result = GetConfigVersion(tt.version)
			}

			expectedConfig := config
			if tt.version != 0 {
				expectedConfig = configVersions[tt.version]
			}

			if result.VotingStartDelay != expectedConfig.VotingStartDelay {
				t.Errorf("Config mismatch: got %+v, want %+v",
					result, expectedConfig)
			}
		})
	}
}

func TestReconfigure(t *testing.T) {
	resetGlobalConfig(t)
	mockInit(t)

	newConfig := Config{
		VotingStartDelay:              100000,
		VotingPeriod:                  700000,
		VotingWeightSmoothingDuration: 90000,
		Quorum:                        60,
		ProposalCreationThreshold:     2_000_000_000,
		ExecutionDelay:                90000,
		ExecutionWindow:               3000000,
	}

	initialVersion := GetLatestConfigVersion()

	version := reconfigure(
		newConfig.VotingStartDelay,
		newConfig.VotingPeriod,
		newConfig.VotingWeightSmoothingDuration,
		newConfig.Quorum,
		newConfig.ProposalCreationThreshold,
		newConfig.ExecutionDelay,
		newConfig.ExecutionWindow,
	)

	if version != initialVersion+1 {
		t.Errorf("Expected version %d, got %d", initialVersion+1, version)
	}

	if config.VotingStartDelay != newConfig.VotingStartDelay {
		t.Errorf("Config not updated correctly")
	}

	storedConfig := configVersions[version]
	if storedConfig.VotingStartDelay != newConfig.VotingStartDelay {
		t.Errorf("Config version not stored correctly")
	}
}
