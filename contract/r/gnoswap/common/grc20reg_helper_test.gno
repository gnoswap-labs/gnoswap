package common

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/foo20"
)

var tokenPath = "gno.land/r/demo/foo20"

func TestGetToken(t *testing.T) {
	tests := []struct {
		name             string
		tokenPath        string
		expectedHasPanic bool
	}{
		{
			name:             "Success - get registered token",
			tokenPath:        tokenPath,
			expectedHasPanic: false,
		},
		{
			name:             "Panic - get non registered token",
			tokenPath:        "not_registered_token",
			expectedHasPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when & then
			if tc.expectedHasPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic for non-registered token")
					}
				}()
				GetToken(tc.tokenPath)
			} else {
				token := GetToken(tc.tokenPath)
				uassert.True(t, token != nil)
			}
		})
	}
}

func TestTokenMethod(t *testing.T) {
	tests := []struct {
		name           string
		methodName     string
		expectedResult interface{}
	}{
		{
			name:           "GetName()",
			methodName:     "GetName",
			expectedResult: "Foo",
		},
		{
			name:           "GetSymbol()",
			methodName:     "GetSymbol",
			expectedResult: "FOO",
		},
		{
			name:           "GetDecimals()",
			methodName:     "GetDecimals",
			expectedResult: int(4),
		},
		{
			name:           "TotalSupply()",
			methodName:     "TotalSupply",
			expectedResult: int64(10000000000),
		},
		{
			name:           "KnownAccounts()",
			methodName:     "KnownAccounts",
			expectedResult: int(1),
		},
		{
			name:           "BalanceOf()",
			methodName:     "BalanceOf",
			expectedResult: int64(10000000000),
		},
		{
			name:           "Allowance()",
			methodName:     "Allowance",
			expectedResult: int64(0),
		},
		{
			name:           "RenderHome()",
			methodName:     "RenderHome",
			expectedResult: generateExpectedRenderHome(),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			token := GetToken(tokenPath)

			// when
			var result interface{}
			switch tc.methodName {
			case "GetName":
				result = token.GetName()
			case "GetSymbol":
				result = token.GetSymbol()
			case "GetDecimals":
				result = token.GetDecimals()
			case "TotalSupply":
				result = token.TotalSupply()
			case "KnownAccounts":
				result = token.KnownAccounts()
			case "BalanceOf":
				result = token.BalanceOf(std.Address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"))
			case "Allowance":
				result = token.Allowance(std.Address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"), std.Address("g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6"))
			case "RenderHome":
				result = token.RenderHome()
			}

			// then
			uassert.Equal(t, tc.expectedResult, result)
		})
	}
}

func TestGetTokenTeller(t *testing.T) {
	tests := []struct {
		name             string
		tokenPath        string
		expectedHasPanic bool
	}{
		{
			name:             "Success - get registered token teller",
			tokenPath:        tokenPath,
			expectedHasPanic: false,
		},
		{
			name:             "Panic - get non registered token teller",
			tokenPath:        "not_registered_teller",
			expectedHasPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when & then
			if tc.expectedHasPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic for non-registered token teller")
					}
				}()
				GetTokenTeller(tc.tokenPath)
			} else {
				teller := GetTokenTeller(tc.tokenPath)
				uassert.True(t, teller != nil)
			}
		})
	}
}

func TestIsRegistered(t *testing.T) {
	tests := []struct {
		name             string
		tokenPath        string
		expectedHasError bool
	}{
		{
			name:             "Success - check if token is registered",
			tokenPath:        tokenPath,
			expectedHasError: false,
		},
		{
			name:             "Error - check if token is not registered",
			tokenPath:        "not_registered_token",
			expectedHasError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when
			err := IsRegistered(tc.tokenPath)

			// then
			if tc.expectedHasError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestMustRegistered(t *testing.T) {
	tests := []struct {
		name             string
		tokenPath        string
		expectedHasPanic bool
	}{
		{
			name:             "Success - must be registered",
			tokenPath:        tokenPath,
			expectedHasPanic: false,
		},
		{
			name:             "Panic - panic for non registered token",
			tokenPath:        "not_registered",
			expectedHasPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when & then
			if tc.expectedHasPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic for non-registered token")
					}
				}()
				MustRegistered(tc.tokenPath)
			} else {
				// Should not panic
				MustRegistered(tc.tokenPath)
			}
		})
	}
}

func TestExtractTokenPathsFromRender(t *testing.T) {
	var (
		wugnotPath = "gno.land/r/demo/wugnot"
		gnsPath    = "gno.land/r/gnoswap/v1/gns"
		fooPath    = "gno.land/r/onbloc/foo"
		quxPath    = "gno.land/r/onbloc/qux"
	)

	// NOTE: following strings are return from grc20reg.Render()
	renderList := []string{
		// no registered token
		`No registered token.`,

		// 1 token
		`- **wrapped GNOT** - [gno.land/r/demo/wugnot](/r/demo/wugnot) - [info](/r/demo/grc20reg:gno.land/r/demo/wugnot)`,

		// 2 tokens
		`- **wrapped GNOT** - [gno.land/r/demo/wugnot](/r/demo/wugnot) - [info](/r/demo/grc20reg:gno.land/r/demo/wugnot)
- **Gnoswap** - [gno.land/r/gnoswap/v1/gns](/r/gnoswap/v1/gns) - [info](/r/demo/grc20reg:gno.land/r/gnoswap/v1/gns)
`,

		// 4 tokens
		`- **wrapped GNOT** - [gno.land/r/demo/wugnot](/r/demo/wugnot) - [info](/r/demo/grc20reg:gno.land/r/demo/wugnot)
- **Gnoswap** - [gno.land/r/gnoswap/v1/gns](/r/gnoswap/v1/gns) - [info](/r/demo/grc20reg:gno.land/r/gnoswap/v1/gns)
- **Baz** - [gno.land/r/onbloc/foo](/r/onbloc/foo) - [info](/r/demo/grc20reg:gno.land/r/onbloc/foo)
- **Qux** - [gno.land/r/onbloc/qux](/r/onbloc/qux) - [info](/r/demo/grc20reg:gno.land/r/onbloc/qux)
`,
	}

	tests := []struct {
		name     string
		render   string
		expected []string
	}{
		{
			name:     "no registered token",
			render:   renderList[0],
			expected: []string{},
		},
		{
			name:     "1 registered token",
			render:   renderList[1],
			expected: []string{wugnotPath},
		},
		{
			name:     "2 registered tokens",
			render:   renderList[2],
			expected: []string{wugnotPath, gnsPath},
		},
		{
			name:     "4 registered tokens",
			render:   renderList[3],
			expected: []string{wugnotPath, gnsPath, fooPath, quxPath},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when
			extracted := extractTokenPathsFromRender(tc.render)

			// then
			uassert.True(t, areSlicesEqual(t, tc.expected, extracted))
		})
	}
}

func TestTotalSupply(t *testing.T) {
	tests := []struct {
		name           string
		tokenPath      string
		expectedResult int64
	}{
		{
			name:           "Valid total supply",
			tokenPath:      tokenPath,
			expectedResult: foo20.TotalSupply(),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when
			result := TotalSupply(tc.tokenPath)

			// then
			uassert.Equal(t, tc.expectedResult, result)
		})
	}
}

func TestBalanceOf(t *testing.T) {
	tests := []struct {
		name           string
		tokenPath      string
		address        std.Address
		expectedResult int64
	}{
		{
			name:           "Valid balance query",
			tokenPath:      tokenPath,
			address:        std.Address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"),
			expectedResult: foo20.BalanceOf(std.Address("g1manfred47kzduec920z88wfr64ylksmdcedlf5")),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when
			result := BalanceOf(tc.tokenPath, tc.address)

			// then
			uassert.Equal(t, tc.expectedResult, result)
		})
	}
}

func TestAllowance(t *testing.T) {
	tests := []struct {
		name           string
		tokenPath      string
		owner          std.Address
		spender        std.Address
		expectedResult int64
	}{
		{
			name:           "Valid allowance query",
			tokenPath:      tokenPath,
			owner:          std.Address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"),
			spender:        std.Address("g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6"),
			expectedResult: foo20.Allowance(std.Address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"), std.Address("g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6")),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when
			result := Allowance(tc.tokenPath, tc.owner, tc.spender)

			// then
			uassert.Equal(t, tc.expectedResult, result)
		})
	}
}

// generateExpectedRenderHome generates the expected output for RenderHome method
func generateExpectedRenderHome() string {
	expected := ""
	expected += ufmt.Sprintf("# %s ($%s)\n\n", "Foo", "FOO")
	expected += ufmt.Sprintf("* **Decimals**: %d\n", 4)
	expected += ufmt.Sprintf("* **Total supply**: %d\n", 10000000000)
	expected += ufmt.Sprintf("* **Known accounts**: %d\n", 1)
	return expected
}

// areSlicesEqual compares two slices of strings
func areSlicesEqual(t *testing.T, a, b []string) bool {
	t.Helper()

	// Check if lengths are different
	if len(a) != len(b) {
		return false
	}

	// Compare each element
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}

	return true
}
