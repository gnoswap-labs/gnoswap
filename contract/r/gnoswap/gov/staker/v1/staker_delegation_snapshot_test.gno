package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

// Test CleanStakerDelegationSnapshotByAdmin function
func TestStakerDelegationSnapshot_CleanStakerDelegationSnapshotByAdmin(t *testing.T) {
	tests := []struct {
		name          string
		caller        address
		threshold     int64
		expectPanic   bool
		expectedError string
	}{
		{
			name:          "Non-admin caller should panic",
			caller:        testutils.TestAddress("alice"),
			threshold:     100,
			expectPanic:   true,
			expectedError: "unauthorized: caller " + testutils.TestAddress("alice").String() + " is not admin or governance",
		},
		{
			name:          "Invalid caller address should panic",
			caller:        testutils.TestAddress("invalid"),
			threshold:     100,
			expectPanic:   true,
			expectedError: "unauthorized: caller g1d9h8vctvd9j97h6lta047h6lta047h6l8k5rvt is not admin or governance",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gs := createTestGovStaker()
			// Given: Setup test environment
			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
						gs.CleanStakerDelegationSnapshotByAdmin(tt.threshold)
					}(cross)
				})
			} else {
				func(cur realm) {
					// Should not panic for admin
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					gs.CleanStakerDelegationSnapshotByAdmin(tt.threshold)
				}(cross)
			}
		})
	}
}

// Test edge cases and integration scenarios
func TestStakerDelegationSnapshot_EdgeCases(t *testing.T) {
	gs := createTestGovStaker()
	tests := []struct {
		name         string
		description  string
		testFunction func(t *testing.T)
	}{
		{
			name:        "Multiple SetUnDelegationLockupPeriodByAdmin operations should work",
			description: "Admin should be able to perform multiple SetUnDelegationLockupPeriodByAdmin operations in sequence",
			testFunction: func(t *testing.T) {
				// Given: Admin context
				testing.SetRealm(testing.NewUserRealm(admin))

				func(cur realm) {
					gs.SetUnDelegationLockupPeriodByAdmin(1000)
					gs.SetUnDelegationLockupPeriodByAdmin(2000)
					gs.SetUnDelegationLockupPeriodByAdmin(3000)
				}(cross)
			},
		},
		{
			name:        "Large height values should be handled",
			description: "System should handle large block height values without issues",
			testFunction: func(t *testing.T) {
				// Given: Admin context
				testing.SetRealm(testing.NewUserRealm(admin))

				// When: Use large height value
				largeHeight := int64(9223372036854775807) // max int64

				// Then: Should not panic
				func(cur realm) {
					gs.SetUnDelegationLockupPeriodByAdmin(largeHeight)
				}(cross)
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
