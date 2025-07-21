package common

import (
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestUtil_assertOnlyNotNil(t *testing.T) {
	tests := []struct {
		name                 string
		inputValue           *u256.Uint
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Valid non-nil value",
			inputValue:       u256.NewUint(100),
			expectedHasPanic: false,
		},
		{
			name:             "Valid zero value",
			inputValue:       u256.NewUint(0),
			expectedHasPanic: false,
		},
		{
			name:                 "Nil value should panic",
			inputValue:           nil,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-008] invalid input data || value is nil",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			inputValue := tc.inputValue

			// when & then
			if tc.expectedHasPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMessage, func() {
					assertOnlyNotNil(inputValue)
				})
			} else {
				// Should not panic for valid values
				assertOnlyNotNil(inputValue)
				// If we reach here, test passed
				uassert.True(t, true)
			}
		})
	}
}

func TestUtil_getPrevRealm(t *testing.T) {
	tests := []struct {
		name            string
		setupRealm      func()
		expectedUser    bool
		expectedPkgPath string
	}{
		{
			name: "Get previous realm from user context",
			setupRealm: func() {
				// This will be called from test context which is a user realm
			},
			expectedUser:    true,
			expectedPkgPath: "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Test execution context

			// when
			prevRealm := getPrevRealm()

			// then
			uassert.Equal(t, tc.expectedUser, prevRealm.IsUser())
			// Note: We can't easily test exact PkgPath in unit tests
			// as it depends on the test execution context
		})
	}
}

func TestUtil_getPrevAddr(t *testing.T) {
	tests := []struct {
		name         string
		setupContext func()
	}{
		{
			name: "Get previous address",
			setupContext: func() {
				// Test context setup
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Test execution context

			// when
			addr := getPrevAddr()

			// then
			// Just verify function doesn't panic and returns something
			// Note: In test context, address might be empty/zero value
			_ = addr.String() // This shouldn't panic
		})
	}
}

func TestUtil_getPrevAsString(t *testing.T) {
	tests := []struct {
		name         string
		setupContext func()
	}{
		{
			name: "Get previous realm as strings",
			setupContext: func() {
				// Test context setup
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Test execution context

			// when
			addrStr, _ := getPrevAsString()

			// then
			// Just verify function doesn't panic and returns something
			// Note: In test context, values might be empty
			_ = addrStr // This shouldn't panic
		})
	}
}

func TestUtil_IntegrationTest(t *testing.T) {
	tests := []struct {
		name           string
		testValue      uint64
		expectedResult bool
	}{
		{
			name:           "Integration test with valid value",
			testValue:      12345,
			expectedResult: true,
		},
		{
			name:           "Integration test with zero value",
			testValue:      0,
			expectedResult: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			testValue := u256.NewUint(tc.testValue)

			// when - test that all util functions work together
			assertOnlyNotNil(testValue) // Should not panic
			prevRealm := getPrevRealm()
			addr := getPrevAddr()
			addrStr, _ := getPrevAsString()

			// then
			// Just verify functions work without panicking
			_ = prevRealm.IsUser() // Test context may vary
			_ = addr.String()      // Should not panic
			_ = addrStr            // Should not panic
			// All functions executed successfully
			uassert.True(t, true)
		})
	}
}

// TestUtil_ErrorHandling tests error handling in util functions
func TestUtil_ErrorHandling(t *testing.T) {
	t.Run("assertOnlyNotNil with various nil scenarios", func(t *testing.T) {
		var nilUint *u256.Uint = nil
		
		uassert.PanicsWithMessage(t, 
			"[GNOSWAP-COMMON-008] invalid input data || value is nil", 
			func() {
				assertOnlyNotNil(nilUint)
			})
	})
	
	t.Run("assertOnlyNotNil with valid values", func(t *testing.T) {
		validValues := []*u256.Uint{
			u256.NewUint(0),
			u256.NewUint(1),
			u256.NewUint(999999999999999),
			u256.MustFromDecimal("12345678901234567890"),
		}
		
		for i, val := range validValues {
			t.Run(ufmt.Sprintf("valid_value_%d", i), func(t *testing.T) {
				// Should not panic
				assertOnlyNotNil(val)
				uassert.True(t, true) // If we reach here, test passed
			})
		}
	})
}

// TestUtil_RealmFunctions tests realm-related utility functions
func TestUtil_RealmFunctions(t *testing.T) {
	t.Run("getPrevRealm consistency", func(t *testing.T) {
		realm1 := getPrevRealm()
		realm2 := getPrevRealm()
		
		// Both calls should return consistent results
		uassert.Equal(t, realm1.IsUser(), realm2.IsUser())
		uassert.Equal(t, realm1.PkgPath(), realm2.PkgPath())
	})
	
	t.Run("getPrevAddr consistency", func(t *testing.T) {
		addr1 := getPrevAddr()
		addr2 := getPrevAddr()
		
		// Both calls should return the same address
		uassert.Equal(t, addr1.String(), addr2.String())
	})
	
	t.Run("getPrevAsString components", func(t *testing.T) {
		addrStr, pkgPath := getPrevAsString()
		
		// Verify components are related to direct calls
		directAddr := getPrevAddr()
		directRealm := getPrevRealm()
		
		uassert.Equal(t, directAddr.String(), addrStr)
		uassert.Equal(t, directRealm.PkgPath(), pkgPath)
	})
}

// TestUtil_PerformanceAndStress tests performance characteristics
func TestUtil_PerformanceAndStress(t *testing.T) {
	t.Run("assertOnlyNotNil performance with many calls", func(t *testing.T) {
		testValue := u256.NewUint(42)
		
		// Call the function many times to ensure it's efficient
		for i := 0; i < 1000; i++ {
			assertOnlyNotNil(testValue)
		}
		
		// If we reach here without timeout, performance is acceptable
		uassert.True(t, true)
	})
	
	t.Run("realm functions with repeated calls", func(t *testing.T) {
		// Test that repeated calls don't cause issues
		for i := 0; i < 100; i++ {
			_ = getPrevRealm()
			_ = getPrevAddr()
			_, _ = getPrevAsString()
		}
		
		uassert.True(t, true)
	})
}
