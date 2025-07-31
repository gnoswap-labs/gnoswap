package common

import (
	"testing"

	"gno.land/p/demo/uassert"
)

var tokenPath = "gno.land/r/demo/foo20"

func TestGrc20regHelper_GetToken(t *testing.T) {
	tests := []struct {
		name                 string
		tokenPath            string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success call with non registered token should panic",
			tokenPath:        "not_registered_token",
			expectedHasPanic: true,
		},
		{
			name:             "Success call with foo20 token should panic in test env",
			tokenPath:        tokenPath,
			expectedHasPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						// Expected panic occurred
						if tc.expectedPanicMessage != "" {
							uassert.Equal(t, tc.expectedPanicMessage, r.(string))
						}
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				} else if tc.expectedHasPanic {
					t.Errorf("[%s] expected panic but none occurred", tc.name)
				}
			}()

			// given
			// Test environment has no registered tokens

			// when
			GetToken(tc.tokenPath)

			// then
			// Handled by defer function above
		})
	}
}

func TestGrc20regHelper_GetTokenTeller(t *testing.T) {
	tests := []struct {
		name                 string
		tokenPath            string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success call with non registered token teller should panic",
			tokenPath:        "not_registered_teller",
			expectedHasPanic: true,
		},
		{
			name:             "Success call with foo20 token teller should panic in test env",
			tokenPath:        tokenPath,
			expectedHasPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						// Expected panic occurred
						if tc.expectedPanicMessage != "" {
							uassert.Equal(t, tc.expectedPanicMessage, r.(string))
						}
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				} else if tc.expectedHasPanic {
					t.Errorf("[%s] expected panic but none occurred", tc.name)
				}
			}()

			// given
			// Test environment has no registered token tellers

			// when
			GetTokenTeller(tc.tokenPath)

			// then
			// Handled by defer function above
		})
	}
}

func TestGrc20regHelper_IsRegistered(t *testing.T) {
	tests := []struct {
		name             string
		tokenPath        string
		expectedHasError bool
	}{
		{
			name:             "Success call with non registered token should return error",
			tokenPath:        "not_registered_token",
			expectedHasError: true,
		},
		{
			name:             "Success call with foo20 token should return error in test env",
			tokenPath:        tokenPath,
			expectedHasError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Test environment has no registered tokens

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

func TestGrc20regHelper_MustRegistered(t *testing.T) {
	tests := []struct {
		name                 string
		tokenPath            string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success call with non registered token should panic",
			tokenPath:        "not_registered",
			expectedHasPanic: true,
		},
		{
			name:             "Success call with foo20 token should panic in test env",
			tokenPath:        tokenPath,
			expectedHasPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						// Expected panic occurred
						if tc.expectedPanicMessage != "" {
							uassert.Equal(t, tc.expectedPanicMessage, r.(string))
						}
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				} else if tc.expectedHasPanic {
					t.Errorf("[%s] expected panic but none occurred", tc.name)
				}
			}()

			// given
			// Test environment has no registered tokens

			// when
			MustRegistered(tc.tokenPath)

			// then
			// Handled by defer function above
		})
	}
}

func TestGrc20regHelper_ExtractTokenPathsFromRender(t *testing.T) {
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
		name         string
		render       string
		expectedList []string
	}{
		{
			name:         "Success call with no registered token",
			render:       renderList[0],
			expectedList: []string{},
		},
		{
			name:         "Success call with 1 registered token",
			render:       renderList[1],
			expectedList: []string{wugnotPath},
		},
		{
			name:         "Success call with 2 registered tokens",
			render:       renderList[2],
			expectedList: []string{wugnotPath, gnsPath},
		},
		{
			name:         "Success call with 4 registered tokens",
			render:       renderList[3],
			expectedList: []string{wugnotPath, gnsPath, fooPath, quxPath},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			// Render string is provided in test case

			// when
			extractedList := extractTokenPathsFromRender(tc.render)

			// then
			uassert.True(t, areSlicesEqual(t, tc.expectedList, extractedList))
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
