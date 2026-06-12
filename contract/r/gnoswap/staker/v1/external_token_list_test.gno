package v1

import (
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/access"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestAddToken(cur realm, t *testing.T) {
	tests := []struct {
		name                  string
		caller                address
		inputTokenPath        string
		expectedAllowedTokens []string
		expectedHasAbort      bool
		expectedAbortMsg      string
		expectedHasPanic      bool
		expectedPanicMsg      string
	}{
		{
			name:           "add token success by admin",
			caller:         getAdminAddress(t),
			inputTokenPath: "gno.land/r/gnoswap/v1/token1",
			expectedAllowedTokens: []string{
				GNS_PATH,
				WUGNOT_PATH,
				"gno.land/r/gnoswap/v1/token1",
			},
			expectedHasAbort: false,
			expectedAbortMsg: "",
			expectedHasPanic: false,
			expectedPanicMsg: "",
		},
		{
			name:           "add token failed by non admin",
			caller:         testutils.TestAddress("non-admin"),
			inputTokenPath: GNS_PATH,
			expectedAllowedTokens: []string{
				GNS_PATH,
				WUGNOT_PATH,
			},
			expectedHasAbort: true,
			expectedAbortMsg: "unauthorized: caller g1dehkuttpv3kkjmjlta047h6lta047h6lj8fjdj is not admin or governance",
			expectedHasPanic: false,
			expectedPanicMsg: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			initStakerTest(cur, t)

			// given
			getMockInstance().store.SetAllowedTokens(0, cur, _defaultAllowedTokens)

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// when
			if tt.expectedHasPanic {
				uassert.PanicsWithMessage(t, cur, tt.expectedPanicMsg, func() {
					mockInstanceAddToken(cross(cur), tt.inputTokenPath)
				})
			} else if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, cur, tt.expectedAbortMsg, func() {
					mockInstanceAddToken(cross(cur), tt.inputTokenPath)
				})
			} else {
				mockInstanceAddToken(cross(cur), tt.inputTokenPath)
			}

			// then
			uassert.Equal(t, len(tt.expectedAllowedTokens), len(getMockInstance().store.GetAllowedTokens()))

			allowedTokenMap := make(map[string]bool)
			for _, token := range tt.expectedAllowedTokens {
				allowedTokenMap[token] = true
			}

			for _, token := range getMockInstance().store.GetAllowedTokens() {
				uassert.True(t, allowedTokenMap[token])
			}
		})
	}
}

func TestRemoveToken(cur realm, t *testing.T) {
	customTokenPath := "gno.land/r/gnoswap/v1/custom"

	currentDefaultTokens := make([]string, 0)
	currentDefaultTokens = append(currentDefaultTokens, _defaultAllowedTokens...)
	currentDefaultTokens = append(currentDefaultTokens, customTokenPath)

	tests := []struct {
		name                  string
		caller                address
		inputTokenPath        string
		expectedAllowedTokens []string
		expectedHasAbort      bool
		expectedAbortMsg      string
		expectedHasPanic      bool
		expectedPanicMsg      string
	}{
		{
			name:                  "remove token success with custom token by admin",
			caller:                getAdminAddress(t),
			inputTokenPath:        customTokenPath,
			expectedAllowedTokens: []string{GNS_PATH, WUGNOT_PATH},
			expectedHasAbort:      false,
			expectedAbortMsg:      "",
			expectedHasPanic:      false,
			expectedPanicMsg:      "",
		},
		{
			name:                  "remove token failed by non admin",
			caller:                testutils.TestAddress("non-admin"),
			inputTokenPath:        customTokenPath,
			expectedAllowedTokens: []string{GNS_PATH, WUGNOT_PATH, customTokenPath},
			expectedHasAbort:      true,
			expectedAbortMsg:      "unauthorized: caller g1dehkuttpv3kkjmjlta047h6lta047h6lj8fjdj is not admin or governance",
		},
		{
			name:                  "remove token failed by default token",
			caller:                getAdminAddress(t),
			inputTokenPath:        GNS_PATH,
			expectedAllowedTokens: []string{GNS_PATH, WUGNOT_PATH, customTokenPath},
			expectedHasAbort:      true,
			expectedAbortMsg:      "[GNOSWAP-STAKER-010] cannot delete default external token: cannot remove default token(gno.land/r/gnoswap/gns)",
			expectedHasPanic:      false,
			expectedPanicMsg:      "",
		},
		{
			// NOTE: When removing a non-existent token, it is necessary to confirm that the operation was successful.
			name:                  "remove token failed by not existing token",
			caller:                getAdminAddress(t),
			inputTokenPath:        "not-existing-token",
			expectedAllowedTokens: []string{GNS_PATH, WUGNOT_PATH, customTokenPath},
			expectedHasAbort:      false,
			expectedAbortMsg:      "",
			expectedHasPanic:      false,
			expectedPanicMsg:      "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			initStakerTest(cur, t)

			// given
			getMockInstance().store.SetAllowedTokens(0, cur, currentDefaultTokens)

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// when
			if tt.expectedHasPanic {
				uassert.PanicsWithMessage(t, cur, tt.expectedPanicMsg, func() {
					mockInstanceRemoveToken(cross(cur), tt.inputTokenPath)
				})
			} else if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, cur, tt.expectedAbortMsg, func() {
					mockInstanceRemoveToken(cross(cur), tt.inputTokenPath)
				})
			} else {
				mockInstanceRemoveToken(cross(cur), tt.inputTokenPath)
			}

			// then
			uassert.Equal(t, len(tt.expectedAllowedTokens), len(getMockInstance().store.GetAllowedTokens()))

			allowedTokenMap := make(map[string]bool)
			for _, token := range tt.expectedAllowedTokens {
				allowedTokenMap[token] = true
			}

			for _, token := range getMockInstance().store.GetAllowedTokens() {
				uassert.True(t, allowedTokenMap[token])
			}
		})
	}
}

func setupExternalTokenListAdminPermission(t *testing.T) {
	t.Helper()

	setupExternalDepositFeePermission(t, adminAddr, "admin")
}

func setupExternalTokenListGovernancePermission(t *testing.T) {
	t.Helper()

	// Use the actual governance address from access package
	addr, _ := access.GetAddress(prbac.ROLE_GOVERNANCE.String())
	setupExternalDepositFeePermission(t, addr, "governance")
}

func setupExternalTokenListPermission(t *testing.T, caller address, permissionName string) {
	t.Helper()

	testing.SetOriginCaller(caller)
	testing.SetRealm(testing.NewUserRealm(caller))
}

func setupExternalDepositFeePermission(t *testing.T, caller address, permissionName string) {
	t.Helper()

	testing.SetOriginCaller(caller)
	testing.SetRealm(testing.NewUserRealm(caller))
}

// Test contains helper function
func TestContainsHelperFunction(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		slice    []string
		item     string
		expected bool
	}{
		{
			name:     "item exists in slice",
			slice:    []string{"foo", "bar", "baz"},
			item:     "bar",
			expected: true,
		},
		{
			name:     "item does not exist in slice",
			slice:    []string{"foo", "bar", "baz"},
			item:     "qux",
			expected: false,
		},
		{
			name:     "empty slice",
			slice:    []string{},
			item:     "foo",
			expected: false,
		},
		{
			name:     "single item - match",
			slice:    []string{"foo"},
			item:     "foo",
			expected: true,
		},
		{
			name:     "single item - no match",
			slice:    []string{"foo"},
			item:     "bar",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			result := contains(tt.slice, tt.item)
			uassert.Equal(t, tt.expected, result)
		})
	}
}
