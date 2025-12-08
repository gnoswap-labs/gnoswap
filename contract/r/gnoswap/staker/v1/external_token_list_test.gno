package v1

import (
	"errors"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/access"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestAddToken(t *testing.T) {
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
				GNOT_DENOM,
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
				GNOT_DENOM,
			},
			expectedHasAbort: true,
			expectedAbortMsg: "unauthorized: caller g1dehkuttpv3kkjmjlta047h6lta047h6lj8fjdj is not admin or governance",
			expectedHasPanic: false,
			expectedPanicMsg: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)

			// given
			getMockInstance().store.SetAllowedTokens(defaultAllowed)

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// when
			if tt.expectedHasPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMsg, func() {
					mockInstanceAddToken(tt.inputTokenPath)
				})
			} else if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					mockInstanceAddToken(tt.inputTokenPath)
				})
			} else {
				mockInstanceAddToken(tt.inputTokenPath)
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

func TestRemoveToken(t *testing.T) {
	customTokenPath := "gno.land/r/gnoswap/v1/custom"

	currentDefaultTokens := make([]string, 0)
	currentDefaultTokens = append(currentDefaultTokens, defaultAllowed...)
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
			expectedAllowedTokens: []string{GNS_PATH, GNOT_DENOM},
			expectedHasAbort:      false,
			expectedAbortMsg:      "",
			expectedHasPanic:      false,
			expectedPanicMsg:      "",
		},
		{
			name:                  "remove token failed by non admin",
			caller:                testutils.TestAddress("non-admin"),
			inputTokenPath:        customTokenPath,
			expectedAllowedTokens: []string{GNS_PATH, GNOT_DENOM, customTokenPath},
			expectedHasAbort:      true,
			expectedAbortMsg:      "unauthorized: caller g1dehkuttpv3kkjmjlta047h6lta047h6lj8fjdj is not admin or governance",
		},
		{
			name:                  "remove token failed by default token",
			caller:                getAdminAddress(t),
			inputTokenPath:        GNS_PATH,
			expectedAllowedTokens: []string{GNS_PATH, GNOT_DENOM, customTokenPath},
			expectedHasAbort:      true,
			expectedAbortMsg:      "[GNOSWAP-STAKER-018] can not delete default external token: can not remove default token(gno.land/r/gnoswap/gns)",
			expectedHasPanic:      false,
			expectedPanicMsg:      "",
		},
		{
			// NOTE: When removing a non-existent token, it is necessary to confirm that the operation was successful.
			name:                  "remove token failed by not existing token",
			caller:                getAdminAddress(t),
			inputTokenPath:        "not-existing-token",
			expectedAllowedTokens: []string{GNS_PATH, GNOT_DENOM, customTokenPath},
			expectedHasAbort:      false,
			expectedAbortMsg:      "",
			expectedHasPanic:      false,
			expectedPanicMsg:      "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)

			// given
			getMockInstance().store.SetAllowedTokens(currentDefaultTokens)

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// when
			if tt.expectedHasPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMsg, func() {
					mockInstanceRemoveToken(tt.inputTokenPath)
				})
			} else if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					mockInstanceRemoveToken(tt.inputTokenPath)
				})
			} else {
				mockInstanceRemoveToken(tt.inputTokenPath)
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

func TestModifyTokenList(t *testing.T) {
	tests := []struct {
		name                  string
		caller                address
		inputTokenPath        string
		inputValidator        TokenValidator
		inputExecutor         TokenExecutor
		expectedAllowedTokens []string
		expectedHasError      bool
		expectedErrorMsg      string
	}{
		{
			name:                  "modify token list success with valid token addition",
			caller:                getAdminAddress(t),
			inputTokenPath:        "gno.land/r/gnoswap/v1/token1",
			inputValidator:        nil,
			inputExecutor:         addTokenExecutor,
			expectedAllowedTokens: []string{GNS_PATH, GNOT_DENOM, "gno.land/r/gnoswap/v1/token1"},
			expectedHasError:      false,
			expectedErrorMsg:      "",
		},
		{
			name:           "modify token list success with validation failure",
			caller:         getAdminAddress(t),
			inputTokenPath: GNS_PATH,
			inputValidator: func(tokenPath string) error {
				return errors.New("validation failure")
			},
			inputExecutor:         addTokenExecutor,
			expectedAllowedTokens: []string{GNS_PATH, GNOT_DENOM},
			expectedHasError:      true,
			expectedErrorMsg:      "validation failure",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)

			// given
			getMockInstance().store.SetAllowedTokens(defaultAllowed)

			testing.SetOriginCaller(tt.caller)

			// when
			modifyTokenListFn := func() error {
				testing.SetRealm(adminRealm)

				return func(cur realm) error {
					testing.SetRealm(stakerRealm)
					return modifyTokenList(getMockInstance(), tt.inputTokenPath, tt.inputValidator, tt.inputExecutor)
				}(cross)
			}

			err := modifyTokenListFn()
			if tt.expectedHasError {
				uassert.Error(t, err)
				uassert.Equal(t, tt.expectedErrorMsg, err.Error())
			} else {
				uassert.NoError(t, err)
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

// Test addTokenExecutor edge cases
func TestAddTokenExecutor(t *testing.T) {
	tests := []struct {
		name           string
		tokenPath      string
		initialTokens  []string
		expectedTokens []string
		expectedLength int
	}{
		{
			name:           "add new token to empty list",
			tokenPath:      "gno.land/r/onbloc/foo",
			initialTokens:  []string{},
			expectedTokens: []string{"gno.land/r/onbloc/foo"},
			expectedLength: 1,
		},
		{
			name:           "add new token to existing list",
			tokenPath:      "gno.land/r/onbloc/baz",
			initialTokens:  []string{"gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar"},
			expectedTokens: []string{"gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar", "gno.land/r/onbloc/baz"},
			expectedLength: 3,
		},
		{
			name:           "add existing token - no duplicate",
			tokenPath:      "gno.land/r/onbloc/foo",
			initialTokens:  []string{"gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar"},
			expectedTokens: []string{"gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar"},
			expectedLength: 2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := addTokenExecutor(tt.tokenPath, tt.initialTokens)
			uassert.Equal(t, tt.expectedLength, len(result))

			for i, expected := range tt.expectedTokens {
				uassert.Equal(t, expected, result[i])
			}
		})
	}
}

// Test removeTokenExecutor edge cases
func TestRemoveTokenExecutor(t *testing.T) {
	tests := []struct {
		name           string
		tokenPath      string
		initialTokens  []string
		expectedTokens []string
		expectedLength int
	}{
		{
			name:           "remove existing token from middle",
			tokenPath:      "gno.land/r/onbloc/bar",
			initialTokens:  []string{"gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar", "gno.land/r/onbloc/baz"},
			expectedTokens: []string{"gno.land/r/onbloc/foo", "gno.land/r/onbloc/baz"},
			expectedLength: 2,
		},
		{
			name:           "remove first token",
			tokenPath:      "gno.land/r/onbloc/foo",
			initialTokens:  []string{"gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar"},
			expectedTokens: []string{"gno.land/r/onbloc/bar"},
			expectedLength: 1,
		},
		{
			name:           "remove last token",
			tokenPath:      "gno.land/r/onbloc/bar",
			initialTokens:  []string{"gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar"},
			expectedTokens: []string{"gno.land/r/onbloc/foo"},
			expectedLength: 1,
		},
		{
			name:           "remove non-existent token - no change",
			tokenPath:      "gno.land/r/onbloc/nonexistent",
			initialTokens:  []string{"gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar"},
			expectedTokens: []string{"gno.land/r/onbloc/foo", "gno.land/r/onbloc/bar"},
			expectedLength: 2,
		},
		{
			name:           "remove from empty list",
			tokenPath:      "gno.land/r/onbloc/foo",
			initialTokens:  []string{},
			expectedTokens: []string{},
			expectedLength: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := removeTokenExecutor(tt.tokenPath, tt.initialTokens)
			uassert.Equal(t, tt.expectedLength, len(result))

			for i, expected := range tt.expectedTokens {
				uassert.Equal(t, expected, result[i])
			}
		})
	}
}

// Test addTokenValidator
func TestAddTokenValidator(t *testing.T) {
	tests := []struct {
		name          string
		tokenPath     string
		expectError   bool
		expectedError string
	}{
		{
			name:          "valid new token",
			tokenPath:     "gno.land/r/onbloc/foo",
			expectError:   false,
			expectedError: "",
		},
		{
			name:          "invalid - GNOT is default",
			tokenPath:     GNOT_DENOM,
			expectError:   true,
			expectedError: "can not add existing token",
		},
		{
			name:          "invalid - GNS_PATH is default",
			tokenPath:     GNS_PATH,
			expectError:   true,
			expectedError: "can not add existing token",
		},
		{
			name:          "valid - custom token path",
			tokenPath:     "gno.land/r/onbloc/custom",
			expectError:   false,
			expectedError: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := addTokenValidator(tt.tokenPath)

			if tt.expectError {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// Test removeTokenValidator
func TestRemoveTokenValidator(t *testing.T) {
	tests := []struct {
		name          string
		tokenPath     string
		expectError   bool
		expectedError string
	}{
		{
			name:          "valid removal - custom token",
			tokenPath:     "gno.land/r/onbloc/foo",
			expectError:   false,
			expectedError: "",
		},
		{
			name:          "invalid - cannot remove GNOT",
			tokenPath:     GNOT_DENOM,
			expectError:   true,
			expectedError: "can not remove default token",
		},
		{
			name:          "invalid - cannot remove GNS_PATH",
			tokenPath:     GNS_PATH,
			expectError:   true,
			expectedError: "can not remove default token",
		},
		{
			name:          "valid - non-default token",
			tokenPath:     "gno.land/r/onbloc/custom",
			expectError:   false,
			expectedError: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := removeTokenValidator(tt.tokenPath)

			if tt.expectError {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// Test contains helper function
func TestContainsHelperFunction(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			result := contains(tt.slice, tt.item)
			uassert.Equal(t, tt.expected, result)
		})
	}
}
