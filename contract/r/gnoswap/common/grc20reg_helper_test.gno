package common

import (
	"testing"

	"gno.land/p/demo/uassert"
)

var tokenPath = "gno.land/r/demo/foo20"

func TestGetToken(t *testing.T) {
	tests := []struct {
		name             string
		tokenPath        string
		expectedHasPanic bool
	}{
		{
			name:             "Panic - get non registered token",
			tokenPath:        "not_registered_token",
			expectedHasPanic: true,
		},
		{
			name:             "Panic - get foo20 token (not registered in test env)",
			tokenPath:        tokenPath,
			expectedHasPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when & then
			defer func() {
				if r := recover(); r != nil {
					if !tc.expectedHasPanic {
						t.Errorf("Unexpected panic for token: %s, panic: %v", tc.tokenPath, r)
					}
					// Expected panic occurred
				} else if tc.expectedHasPanic {
					t.Errorf("Expected panic for non-registered token: %s", tc.tokenPath)
				}
			}()

			GetToken(tc.tokenPath)
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
			name:             "Panic - get non registered token teller",
			tokenPath:        "not_registered_teller",
			expectedHasPanic: true,
		},
		{
			name:             "Panic - get foo20 token teller (not registered in test env)",
			tokenPath:        tokenPath,
			expectedHasPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when & then
			defer func() {
				if r := recover(); r != nil {
					if !tc.expectedHasPanic {
						t.Errorf("Unexpected panic for token teller: %s, panic: %v", tc.tokenPath, r)
					}
					// Expected panic occurred
				} else if tc.expectedHasPanic {
					t.Errorf("Expected panic for non-registered token teller: %s", tc.tokenPath)
				}
			}()

			GetTokenTeller(tc.tokenPath)
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
			name:             "Error - check if token is not registered",
			tokenPath:        "not_registered_token",
			expectedHasError: true,
		},
		{
			name:             "Error - check if foo20 token is not registered in test env",
			tokenPath:        tokenPath,
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
			name:             "Panic - panic for non registered token",
			tokenPath:        "not_registered",
			expectedHasPanic: true,
		},
		{
			name:             "Panic - panic for foo20 token (not registered in test env)",
			tokenPath:        tokenPath,
			expectedHasPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Setup is already done in test case

			// when & then
			defer func() {
				if r := recover(); r != nil {
					if !tc.expectedHasPanic {
						t.Errorf("Unexpected panic for token: %s, panic: %v", tc.tokenPath, r)
					}
					// Expected panic occurred
				} else if tc.expectedHasPanic {
					t.Errorf("Expected panic for non-registered token: %s", tc.tokenPath)
				}
			}()

			MustRegistered(tc.tokenPath)
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
