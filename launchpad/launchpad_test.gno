package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/r/gnoswap/v1/common"
)

func setupTest(t *testing.T) {
	projects = make(map[string]Project)
	projectTiersWithoutDeposit = make(map[string]bool)
}

func createTestAddress(t *testing.T) std.Address {
	addr := testutils.TestAddress("test")
	return addr
}

func TestValidateProjectInput(t *testing.T) {
	now := uint64(time.Now().Unix())
	testCases := []struct {
		name        string
		input       ProjectInput
		shouldError bool
	}{
		{
			name: "Valid input",
			input: ProjectInput{
				Name:          "Test Project",
				TokenPath:     "test/token",
				Recipient:     createTestAddress(t),
				DepositAmount: 1000,
				Tier30Ratio:   30,
				Tier90Ratio:   30,
				Tier180Ratio:  40,
				StartTime:     now + 3600, // 1 hour in future
			},
			shouldError: false,
		},
		{
			name: "Invalid tier ratios",
			input: ProjectInput{
				Name:          "Test Project",
				TokenPath:     "test/token",
				Recipient:     createTestAddress(t),
				DepositAmount: 1000,
				Tier30Ratio:   30,
				Tier90Ratio:   30,
				Tier180Ratio:  30, // Sum != 100
				StartTime:     now + 3600,
			},
			shouldError: true,
		},
		{
			name: "Start time in past",
			input: ProjectInput{
				Name:          "Test Project",
				TokenPath:     "test/token",
				Recipient:     createTestAddress(t),
				DepositAmount: 1000,
				Tier30Ratio:   30,
				Tier90Ratio:   30,
				Tier180Ratio:  40,
				StartTime:     now - 3600, // 1 hour in past
			},
			shouldError: true,
		},
		{
			name: "Zero deposit amount",
			input: ProjectInput{
				Name:          "Test Project",
				TokenPath:     "test/token",
				Recipient:     createTestAddress(t),
				DepositAmount: 0,
				Tier30Ratio:   30,
				Tier90Ratio:   30,
				Tier180Ratio:  40,
				StartTime:     now + 3600,
			},
			shouldError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			err := validateProjectInput(tc.input, now)
			if tc.shouldError && err == nil {
				t.Errorf("Expected error but got none")
			}
			if !tc.shouldError && err != nil {
				t.Errorf("Unexpected error: %v", err)
			}
		})
	}
}
