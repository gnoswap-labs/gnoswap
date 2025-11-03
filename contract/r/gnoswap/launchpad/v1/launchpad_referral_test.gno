package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/referral"
)

func TestLaunchpadDeposit_registerReferral(t *testing.T) {
	tests := []struct {
		name               string
		setupFunc          func() (string, address)
		expectedReferrer   string
		expectedSuccess    bool
		validateFunc       func(t *testing.T, actualReferrer string, success bool)
	}{
		{
			name: "successful registration with valid referrer",
			setupFunc: func() (string, address) {
				// Reset referral state
				resetTestStore()

				referrerAddr := testutils.TestAddress("referrer1")
				callerAddr := testutils.TestAddress("caller1")

				return referrerAddr.String(), callerAddr
			},
			expectedSuccess: true,
			validateFunc: func(t *testing.T, actualReferrer string, success bool) {
				uassert.True(t, success, "registration should succeed")
				uassert.NotEmpty(t, actualReferrer, "referrer should not be empty")
			},
		},
		{
			name: "registration with empty referrer string",
			setupFunc: func() (string, address) {
				resetTestStore()

				callerAddr := testutils.TestAddress("caller2")

				return "", callerAddr
			},
			expectedSuccess: false,
			validateFunc: func(t *testing.T, actualReferrer string, success bool) {
				uassert.False(t, success, "registration with empty referrer should fail")
				// Should return existing referral or empty string
			},
		},
		{
			name: "self-referral attempt (same address)",
			setupFunc: func() (string, address) {
				resetTestStore()

				callerAddr := testutils.TestAddress("caller3")
				// Try to use same address as referrer
				referrerAddr := callerAddr

				return referrerAddr.String(), callerAddr
			},
			expectedSuccess: false,
			validateFunc: func(t *testing.T, actualReferrer string, success bool) {
				uassert.False(t, success, "self-referral should fail")
			},
		},
		{
			name: "already registered user tries to change referrer",
			setupFunc: func() (string, address) {
				resetTestStore()

				firstReferrerAddr := testutils.TestAddress("first_referrer")
				secondReferrerAddr := testutils.TestAddress("second_referrer")
				callerAddr := testutils.TestAddress("caller4")

				// First registration
				referral.TryRegister(cross, callerAddr, firstReferrerAddr.String())

				// Try to register again with different referrer
				return secondReferrerAddr.String(), callerAddr
			},
			expectedSuccess: false,
			validateFunc: func(t *testing.T, actualReferrer string, success bool) {
				uassert.False(t, success, "changing referrer should fail")
				// Should return the original referrer
				existingReferrer := referral.GetReferral(testutils.TestAddress("caller4").String())
				uassert.Equal(t, existingReferrer, actualReferrer, "should return existing referrer")
			},
		},
		{
			name: "registration failure returns existing referral",
			setupFunc: func() (string, address) {
				resetTestStore()

				existingReferrerAddr := testutils.TestAddress("existing_referrer")
				newReferrerAddr := testutils.TestAddress("new_referrer")
				callerAddr := testutils.TestAddress("caller5")

				// Register with existing referrer first
				referral.TryRegister(cross, callerAddr, existingReferrerAddr.String())

				// Try to register with new referrer (should fail and return existing)
				return newReferrerAddr.String(), callerAddr
			},
			expectedSuccess: false,
			validateFunc: func(t *testing.T, actualReferrer string, success bool) {
				uassert.False(t, success, "re-registration should fail")

				// Verify it returns the existing referrer
				expectedReferrer := testutils.TestAddress("existing_referrer").String()
				existingReferrer := referral.GetReferral(testutils.TestAddress("caller5").String())
				uassert.Equal(t, expectedReferrer, existingReferrer, "should have original referrer")
			},
		},
		{
			name: "invalid referrer address format",
			setupFunc: func() (string, address) {
				resetTestStore()

				callerAddr := testutils.TestAddress("caller6")
				invalidReferrer := "invalid_address_format"

				return invalidReferrer, callerAddr
			},
			expectedSuccess: false,
			validateFunc: func(t *testing.T, actualReferrer string, success bool) {
				uassert.False(t, success, "invalid address format should fail")
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			referrer, caller := tt.setupFunc()

			// Execute
			actualReferrer, success := registerReferral(referrer, caller)

			// Validate
			if tt.validateFunc != nil {
				tt.validateFunc(t, actualReferrer, success)
			}

			uassert.Equal(t, tt.expectedSuccess, success, "success flag should match expected")
		})
	}
}

// TestLaunchpadDeposit_registerReferral_ReturnValues tests the return value behavior
func TestLaunchpadDeposit_registerReferral_ReturnValues(t *testing.T) {
	tests := []struct {
		name                    string
		referrer                string
		caller                  address
		setupExistingReferral   bool
		existingReferralAddress string
		expectedSuccess         bool
		checkActualReferrer     bool
	}{
		{
			name:                  "success returns provided referrer",
			referrer:              testutils.TestAddress("ref1").String(),
			caller:                testutils.TestAddress("user1"),
			setupExistingReferral: false,
			expectedSuccess:       true,
			checkActualReferrer:   true,
		},
		{
			name:                    "failure returns existing referrer",
			referrer:                testutils.TestAddress("ref2").String(),
			caller:                  testutils.TestAddress("user2"),
			setupExistingReferral:   true,
			existingReferralAddress: testutils.TestAddress("existing_ref").String(),
			expectedSuccess:         false,
			checkActualReferrer:     true,
		},
		{
			name:                  "empty referrer fails",
			referrer:              "",
			caller:                testutils.TestAddress("user3"),
			setupExistingReferral: false,
			expectedSuccess:       false,
			checkActualReferrer:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset state
			resetTestStore()

			// Setup existing referral if needed
			if tt.setupExistingReferral {
				referral.TryRegister(cross, tt.caller, tt.existingReferralAddress)
			}

			// Execute
			actualReferrer, success := registerReferral(tt.referrer, tt.caller)

			// Validate success flag
			uassert.Equal(t, tt.expectedSuccess, success)

			// Validate actual referrer based on test case
			if tt.checkActualReferrer {
				if success {
					// On success, should return the provided referrer
					uassert.Equal(t, tt.referrer, actualReferrer)
				} else if tt.setupExistingReferral {
					// On failure with existing referral, should return existing
					uassert.Equal(t, tt.existingReferralAddress, actualReferrer)
				}
			}
		})
	}
}

// TestLaunchpadDeposit_registerReferral_EdgeCases tests edge cases
func TestLaunchpadDeposit_registerReferral_EdgeCases(t *testing.T) {
	tests := []struct {
		name            string
		referrer        string
		caller          address
		expectedSuccess bool
	}{
		{
			name:            "very long referrer string",
			referrer:        "g1" + string(make([]byte, 1000)),
			caller:          testutils.TestAddress("user1"),
			expectedSuccess: false,
		},
		{
			name:            "referrer with special characters",
			referrer:        "g1@#$%^&*()",
			caller:          testutils.TestAddress("user2"),
			expectedSuccess: false,
		},
		{
			name:            "referrer with spaces",
			referrer:        "g1 address with spaces",
			caller:          testutils.TestAddress("user3"),
			expectedSuccess: false,
		},
		{
			name:            "zero address as referrer",
			referrer:        "g100000000000000000000000000000000000000",
			caller:          testutils.TestAddress("user4"),
			expectedSuccess: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset state
			resetTestStore()

			// Execute
			_, success := registerReferral(tt.referrer, tt.caller)

			// Validate
			uassert.Equal(t, tt.expectedSuccess, success)
		})
	}
}
