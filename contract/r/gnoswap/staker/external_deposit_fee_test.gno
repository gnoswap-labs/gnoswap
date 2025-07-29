package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/access"
)

// Helper functions
func getAdminAddress(t *testing.T) std.Address {
	t.Helper()
	return adminAddr
}

func getGovernanceAddress(t *testing.T) std.Address {
	t.Helper()
	addr, _ := access.GetAddress(prbac.ROLE_GOVERNANCE.String())
	return addr
}

func setupPermission(t *testing.T, caller std.Address) {
	t.Helper()
	testing.SetOriginCaller(caller)
	testing.SetRealm(std.NewUserRealm(caller))
}

// Common test error messages
const (
	unauthorizedAdminMsg      = "unauthorized: caller %s is not admin"
	unauthorizedGovernanceMsg = "unauthorized: caller %s is not governance"
)

func TestGetDepositGnsAmount(t *testing.T) {
	expected := int64(1_000_000_000)
	actual := GetDepositGnsAmount()
	uassert.Equal(t, expected, actual)
}

func TestSetDepositGnsAmountByAdmin(t *testing.T) {
	testPermissionBasedFunction(t, []permissionTest{
		{
			name:           "admin success",
			caller:         getAdminAddress(t),
			inputAmount:    2_000_000_000,
			expectedAmount: 2_000_000_000,
			shouldAbort:    false,
		},
		{
			name:           "non-admin failure",
			caller:         testutils.TestAddress("user1"),
			inputAmount:    2_000_000_000,
			expectedAmount: 0,
			shouldAbort:    true,
			expectedMsg:    ufmt.Sprintf(unauthorizedAdminMsg, testutils.TestAddress("user1")),
		},
	}, func(amount int64) {
		SetDepositGnsAmountByAdmin(cross, amount)
	}, GetDepositGnsAmount, &depositGnsAmount)
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
			name:           "non-governance failure",
			caller:         testutils.TestAddress("non-governance"),
			inputAmount:    3_000_000_000,
			expectedAmount: 0,
			shouldAbort:    true,
			expectedMsg:    ufmt.Sprintf(unauthorizedGovernanceMsg, testutils.TestAddress("non-governance")),
		},
		{
			name:           "unauthorized failure",
			caller:         testutils.TestAddress("unauthorized"),
			inputAmount:    3_000_000_000,
			expectedAmount: 0,
			shouldAbort:    true,
			expectedMsg:    ufmt.Sprintf(unauthorizedGovernanceMsg, testutils.TestAddress("unauthorized")),
		},
	}, func(amount int64) {
		SetDepositGnsAmount(cross, amount)
	}, GetDepositGnsAmount, &depositGnsAmount)
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
			expectedMsg:    ufmt.Sprintf(unauthorizedGovernanceMsg, testutils.TestAddress("non-governance")),
		},
		{
			name:           "unauthorized failure",
			caller:         testutils.TestAddress("unauthorized"),
			inputAmount:    1_000_000_000,
			expectedAmount: 0,
			shouldAbort:    true,
			expectedMsg:    ufmt.Sprintf(unauthorizedGovernanceMsg, testutils.TestAddress("unauthorized")),
		},
	}, func(amount int64) {
		SetMinimumRewardAmount(cross, amount)
	}, GetMinimumRewardAmount, &minimumRewardAmount)
}

// Common test structure for permission-based functions
type permissionTest struct {
	name           string
	caller         std.Address
	inputAmount    int64
	expectedAmount int64
	shouldAbort    bool
	expectedMsg    string
}

// Generic test function for permission-based operations
func testPermissionBasedFunction(
	t *testing.T,
	tests []permissionTest,
	testFunc func(int64),
	getterFunc func() int64,
	variablePtr *int64,
) {
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset the variable
			*variablePtr = 0

			// Set the caller
			testing.SetOriginCaller(tt.caller)

			// Execute the function
			if tt.shouldAbort {
				uassert.AbortsWithMessage(t, tt.expectedMsg, func() {
					testFunc(tt.inputAmount)
				})
			} else {
				testFunc(tt.inputAmount)
			}

			// Verify the result
			actual := getterFunc()
			uassert.Equal(t, tt.expectedAmount, actual)
		})
	}
}
