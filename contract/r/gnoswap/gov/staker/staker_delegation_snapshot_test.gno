package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
)

// Test CleanStakerDelegationSnapshotByAdmin function
func TestStakerDelegationSnapshot_CleanStakerDelegationSnapshotByAdmin(t *testing.T) {
	tests := []struct {
		name          string
		caller        std.Address
		threshold     int64
		expectPanic   bool
		expectedError string
	}{
		{
			name:        "Admin can clean delegation snapshot",
			caller:      admin,
			threshold:   100,
			expectPanic: false,
		},
		{
			name:          "Non-admin caller should panic",
			caller:        testutils.TestAddress("alice"),
			threshold:     100,
			expectPanic:   true,
			expectedError: "caller(" + testutils.TestAddress("alice").String() + ") has no permission",
		},
		{
			name:          "Invalid caller address should panic",
			caller:        testutils.TestAddress("invalid"),
			threshold:     100,
			expectPanic:   true,
			expectedError: "caller(g1d9h8vctvd9j97h6lta047h6lta047h6l8k5rvt) has no permission",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment
			testing.SetRealm(std.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					CleanStakerDelegationSnapshotByAdmin(cross, tt.threshold)
				})
			} else {
				// Should not panic for admin
				CleanStakerDelegationSnapshotByAdmin(cross, tt.threshold)
			}
		})
	}
}

// Test edge cases and integration scenarios
func TestStakerDelegationSnapshot_EdgeCases(t *testing.T) {
	tests := []struct {
		name         string
		description  string
		testFunction func(t *testing.T)
	}{
		{
			name:        "Multiple admin operations should work",
			description: "Admin should be able to perform multiple operations in sequence",
			testFunction: func(t *testing.T) {
				// Given: Admin context
				testing.SetRealm(std.NewUserRealm(admin))

				// When: Perform multiple operations
				CleanStakerDelegationSnapshotByAdmin(cross, 100)
				SetUnDelegationLockupPeriodByAdmin(cross, 1000)
				CleanStakerDelegationSnapshotByAdmin(cross, 200)
				SetUnDelegationLockupPeriodByAdmin(cross, 2000)

				// Then: Should not panic
				// Operations completed successfully
			},
		},
		{
			name:        "Large threshold values should be handled",
			description: "System should handle large threshold values without issues",
			testFunction: func(t *testing.T) {
				// Given: Admin context
				testing.SetRealm(std.NewUserRealm(admin))

				// When: Use large threshold value
				largeThreshold := int64(9223372036854775807) // max int64

				// Then: Should not panic
				CleanStakerDelegationSnapshotByAdmin(cross, largeThreshold)
			},
		},
		{
			name:        "Large height values should be handled",
			description: "System should handle large block height values without issues",
			testFunction: func(t *testing.T) {
				// Given: Admin context
				testing.SetRealm(std.NewUserRealm(admin))

				// When: Use large height value
				largeHeight := int64(9223372036854775807) // max int64

				// Then: Should not panic
				SetUnDelegationLockupPeriodByAdmin(cross, largeHeight)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute test function
			tt.testFunction(t)
		})
	}
}
