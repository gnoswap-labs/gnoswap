package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
)

// Helper functions
func getAdminAddress(t *testing.T) address {
	t.Helper()
	return adminAddr
}

func getGovernanceAddress(t *testing.T) address {
	t.Helper()
	addr, _ := access.GetAddress(prbac.ROLE_GOVERNANCE.String())
	return addr
}

func setupPermission(t *testing.T, caller address) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(caller))
	testing.SetRealm(testing.NewUserRealm(caller))
}

// Common test error messages
const unauthorizedMsg = "unauthorized: caller %s is not admin or governance"

func TestGetDepositGnsAmount(t *testing.T) {
	expected := int64(1_000_000_000)
	actual := getMockInstance().getDepositGnsAmount()
	uassert.Equal(t, expected, actual)
}

func TestSetDepositGnsAmount(t *testing.T) {
	testPermissionBasedFunction(t, []permissionTest{
		{
			name:           "governance success",
			caller:         getGovernanceAddress(t),
			inputAmount:    3_000_000_000,
			expectedAmount: 3_000_000_000,
			shouldAbort:    false,
		},
		{
			name:           "admin success",
			caller:         getAdminAddress(t),
			inputAmount:    2_000_000_000,
			expectedAmount: 2_000_000_000,
			shouldAbort:    false,
		},
		{
			name:           "non-governance failure",
			caller:         testutils.TestAddress("non-governance"),
			inputAmount:    3_000_000_000,
			expectedAmount: 0,
			shouldAbort:    true,
			expectedMsg:    ufmt.Sprintf(unauthorizedMsg, testutils.TestAddress("non-governance")),
		},
		{
			name:           "unauthorized failure",
			caller:         testutils.TestAddress("unauthorized"),
			inputAmount:    3_000_000_000,
			expectedAmount: 0,
			shouldAbort:    true,
			expectedMsg:    ufmt.Sprintf(unauthorizedMsg, testutils.TestAddress("unauthorized")),
		},
	}, mockInstanceSetDepositGnsAmount, func() int64 {
		testing.SetRealm(adminRealm)
		return getMockInstance().getDepositGnsAmount()
	})
}

func TestSetMinimumRewardAmount(t *testing.T) {
	testPermissionBasedFunction(t, []permissionTest{
		{
			name:           "governance success",
			caller:         getGovernanceAddress(t),
			inputAmount:    1_000_000_000,
			expectedAmount: 1_000_000_000,
			shouldAbort:    false,
		},
		{
			name:           "non-governance failure",
			caller:         testutils.TestAddress("non-governance"),
			inputAmount:    1_000_000_000,
			expectedAmount: 0,
			shouldAbort:    true,
			expectedMsg:    ufmt.Sprintf(unauthorizedMsg, testutils.TestAddress("non-governance")),
		},
		{
			name:           "unauthorized failure",
			caller:         testutils.TestAddress("unauthorized"),
			inputAmount:    1_000_000_000,
			expectedAmount: 0,
			shouldAbort:    true,
			expectedMsg:    ufmt.Sprintf(unauthorizedMsg, testutils.TestAddress("unauthorized")),
		},
	}, mockInstanceSetMinimumRewardAmount, func() int64 {
		testing.SetRealm(adminRealm)
		return getMockInstance().GetMinimumRewardAmount()
	})
}

// Common test structure for permission-based functions
type permissionTest struct {
	name           string
	caller         address
	inputAmount    int64
	expectedAmount int64
	shouldAbort    bool
	expectedMsg    string
}

// Generic test function for permission-based operations
func testPermissionBasedFunction(
	t *testing.T,
	tests []permissionTest,
	testFunc func(inputAmount int64),
	getterFunc func() int64,
) {
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(adminRealm)
			initStakerTest(t)

			// Set the caller
			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// Execute the function
			if tt.shouldAbort {
				uassert.AbortsWithMessage(t, tt.expectedMsg, func() {
					testFunc(tt.inputAmount)
				})
			} else {
				testFunc(tt.inputAmount)

				// Verify the result
				actual := getterFunc()
				uassert.Equal(t, tt.expectedAmount, actual)
			}
		})
	}
}

// Test GetMinimumRewardAmountForToken

func TestGetMinimumRewardAmountForToken(t *testing.T) {
	tests := []struct {
		name           string
		tokenPath      string
		setupFunc      func(*stakerV1)
		expectedAmount int64
		expectsDefault bool
	}{
		{
			name:      "token with specific minimum",
			tokenPath: "gno.land/r/onbloc/foo",
			setupFunc: func(s *stakerV1) {
				s.store.GetTokenSpecificMinimumRewards().Set("gno.land/r/onbloc/foo", int64(5000000))
			},
			expectedAmount: 5000000,
			expectsDefault: false,
		},
		{
			name:      "token without specific minimum - returns default",
			tokenPath: "gno.land/r/onbloc/bar",
			setupFunc: func(s *stakerV1) {
				// Don't set any specific minimum
			},
			expectedAmount: 1_000_000_000, // default from mock
			expectsDefault: true,
		},
		{
			name:      "different token with specific minimum",
			tokenPath: "gno.land/r/onbloc/baz",
			setupFunc: func(s *stakerV1) {
				s.store.GetTokenSpecificMinimumRewards().Set("gno.land/r/onbloc/baz", int64(10000000))
			},
			expectedAmount: 10000000,
			expectsDefault: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(adminRealm)
			initStakerTest(t)
			instance := getMockInstance()

			if tt.setupFunc != nil {
				tt.setupFunc(instance)
			}

			result := instance.GetMinimumRewardAmountForToken(tt.tokenPath)
			uassert.Equal(t, tt.expectedAmount, result)
		})
	}
}

// Test GetSpecificTokenMinimumRewardAmount

func TestGetSpecificTokenMinimumRewardAmount(t *testing.T) {
	tests := []struct {
		name          string
		tokenPath     string
		setupFunc     func(*stakerV1)
		expectedFound bool
		expectedValue int64
	}{
		{
			name:      "token with specific amount",
			tokenPath: "gno.land/r/onbloc/foo",
			setupFunc: func(s *stakerV1) {
				s.store.GetTokenSpecificMinimumRewards().Set("gno.land/r/onbloc/foo", int64(3000000))
			},
			expectedFound: true,
			expectedValue: 3000000,
		},
		{
			name:      "token without specific amount",
			tokenPath: "gno.land/r/onbloc/bar",
			setupFunc: func(s *stakerV1) {
				// Don't set anything
			},
			expectedFound: false,
			expectedValue: 0,
		},
		{
			name:      "zero value set explicitly",
			tokenPath: "gno.land/r/onbloc/baz",
			setupFunc: func(s *stakerV1) {
				s.store.GetTokenSpecificMinimumRewards().Set("gno.land/r/onbloc/baz", int64(0))
			},
			expectedFound: true,
			expectedValue: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(adminRealm)
			initStakerTest(t)
			instance := getMockInstance()

			if tt.setupFunc != nil {
				tt.setupFunc(instance)
			}

			value, found := instance.GetSpecificTokenMinimumRewardAmount(tt.tokenPath)
			uassert.Equal(t, tt.expectedFound, found)
			if tt.expectedFound {
				uassert.Equal(t, tt.expectedValue, value)
			}
		})
	}
}

// Test internal getters and setters

func TestInternalDepositGnsAmountGetterSetter(t *testing.T) {
	testing.SetRealm(adminRealm)
	initStakerTest(t)
	instance := getMockInstance()

	// Test initial value
	initial := instance.getDepositGnsAmount()
	uassert.True(t, initial > 0)

	// Test setter and getter
	newAmount := int64(5_000_000_000)
	instance.setDepositGnsAmount(newAmount)
	result := instance.getDepositGnsAmount()
	uassert.Equal(t, newAmount, result)
}

func TestInternalMinimumRewardAmountGetterSetter(t *testing.T) {
	testing.SetRealm(adminRealm)
	initStakerTest(t)
	instance := getMockInstance()

	// Test initial value
	initial := instance.getMinimumRewardAmount()
	uassert.True(t, initial > 0)

	// Test setter and getter
	newAmount := int64(2_000_000)
	instance.setMinimumRewardAmount(newAmount)
	result := instance.getMinimumRewardAmount()
	uassert.Equal(t, newAmount, result)
}

// Edge case tests

func TestValidAmount_NegativeValue(t *testing.T) {
	uassert.PanicsContains(t, "must be positive", func() {
		assertIsValidAmount(-1)
	})
}

func TestValidAmount_ZeroValue(t *testing.T) {
	uassert.NotPanics(t, func() {
		assertIsValidAmount(0)
	})
}

func TestValidAmount_PositiveValue(t *testing.T) {
	uassert.NotPanics(t, func() {
		assertIsValidAmount(1000)
	})
}

// Helper function to get governance address
func getGovernanceAddr() address {
	addr, _ := access.GetAddress(prbac.ROLE_GOVERNANCE.String())
	return addr
}
