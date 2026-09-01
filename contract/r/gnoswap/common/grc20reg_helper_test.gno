package common

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/demo/defi/foo20"
)

var tokenPath = "gno.land/r/demo/defi/foo20.FOO"

func TestGrc20regHelper_GetToken(t *testing.T) {
	tests := []struct {
		name        string
		path        string
		shouldPanic bool
	}{
		{
			name:        "get registered token",
			path:        tokenPath,
			shouldPanic: false,
		},
		{
			name:        "reject token realm path",
			path:        "gno.land/r/demo/defi/foo20",
			shouldPanic: true,
		},
		{
			name:        "get non registered token",
			path:        "not_registered_token",
			shouldPanic: true,
		},
		{
			name:        "get token with empty string path",
			path:        "",
			shouldPanic: true,
		},
		{
			name:        "get token with invalid path format",
			path:        "invalid/path/format",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			if tt.shouldPanic {
				uassert.AbortsContains(t, cur, "unknown token", func() {
					GetToken(tt.path)
				})
				return
			}

			token := GetToken(tt.path)
			if token == nil {
				t.Error("Expected non-nil token")
			}
		})
	}
}

func TestGrc20regHelper_TokenMethod(t *testing.T) {
	token := GetToken(tokenPath)

	t.Run("GetName()", func(cur realm, t *testing.T) {
		uassert.Equal(t, "Foo", token.GetName())
	})

	t.Run("GetSymbol()", func(cur realm, t *testing.T) {
		uassert.Equal(t, "FOO", token.GetSymbol())
	})

	t.Run("GetDecimals()", func(cur realm, t *testing.T) {
		uassert.Equal(t, int(4), token.GetDecimals())
	})

	t.Run("TotalSupply()", func(cur realm, t *testing.T) {
		uassert.Equal(t, int64(10000000000), token.TotalSupply())
	})

	t.Run("KnownAccounts()", func(cur realm, t *testing.T) {
		uassert.Equal(t, int(1), token.KnownAccounts())
	})

	t.Run("BalanceOf()", func(cur realm, t *testing.T) {
		uassert.Equal(t, int64(10000000000), token.BalanceOf(address("g1rp7cmetn27eqlpjpc4vuusf8kaj746tysc0qgh")))
	})

	t.Run("Allowance()", func(cur realm, t *testing.T) {
		uassert.Equal(t, int64(0), token.Allowance(address("g1rp7cmetn27eqlpjpc4vuusf8kaj746tysc0qgh"), address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum")))
	})

	t.Run("RenderHome()", func(cur realm, t *testing.T) {
		expected := ""
		expected += ufmt.Sprintf("# %s ($%s)\n\n", "Foo", "FOO")
		expected += ufmt.Sprintf("* **Decimals**: %d\n", 4)
		expected += ufmt.Sprintf("* **Total supply**: %d\n", 10000000000)
		expected += ufmt.Sprintf("* **Known accounts**: %d\n", 1)
		uassert.Equal(t, expected, token.RenderHome())
	})
}

func TestGrc20regHelper_IsRegistered(t *testing.T) {
	tests := []struct {
		name          string
		path          string
		expectedError bool
	}{
		{
			name:          "check if token is registered",
			path:          tokenPath,
			expectedError: false,
		},
		{
			name:          "check if token is not registered",
			path:          "not_registered_token",
			expectedError: true,
		},
		{
			name:          "check with empty string path",
			path:          "",
			expectedError: true,
		},
		{
			name:          "check with invalid path format",
			path:          "invalid/path",
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := IsRegistered(tt.path)
			if tt.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestGrc20regHelper_MustRegistered(t *testing.T) {
	tests := []struct {
		name        string
		paths       []string
		shouldPanic bool
	}{
		{
			name:        "must be registered single token",
			paths:       []string{tokenPath},
			shouldPanic: false,
		},
		{
			name:        "panic for non registered token",
			paths:       []string{"not_registered"},
			shouldPanic: true,
		},
		{
			name:        "must be registered with no parameters",
			paths:       []string{},
			shouldPanic: false,
		},
		{
			name:        "must be registered with multiple registered tokens",
			paths:       []string{tokenPath, tokenPath},
			shouldPanic: false,
		},
		{
			name:        "panic with first token unregistered in multiple",
			paths:       []string{"not_registered", tokenPath},
			shouldPanic: true,
		},
		{
			name:        "panic with second token unregistered in multiple",
			paths:       []string{tokenPath, "not_registered"},
			shouldPanic: true,
		},
		{
			name:        "panic with empty string in multiple tokens",
			paths:       []string{tokenPath, ""},
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, cur, "token(", func() {
					MustRegistered(tt.paths...)
				})
				return
			}
			MustRegistered(tt.paths...)
		})
	}
}

func TestGrc20regHelper_TotalSupply(t *testing.T) {
	tests := []struct {
		name           string
		path           string
		expectedSupply int64
		shouldPanic    bool
	}{
		{
			name:           "get total supply for registered token",
			path:           tokenPath,
			expectedSupply: foo20.TotalSupply(),
			shouldPanic:    false,
		},
		{
			name:        "panic with unregistered token",
			path:        "not_registered_token",
			shouldPanic: true,
		},
		{
			name:        "panic with empty string path",
			path:        "",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			if tt.shouldPanic {
				uassert.AbortsContains(t, cur, "unknown token", func() {
					TotalSupply(tt.path)
				})
				return
			}

			supply := TotalSupply(tt.path)
			uassert.Equal(t, tt.expectedSupply, supply)
		})
	}
}

func TestGrc20regHelper_BalanceOf(t *testing.T) {
	defaultHolder := address("g1rp7cmetn27eqlpjpc4vuusf8kaj746tysc0qgh")

	tests := []struct {
		name            string
		path            string
		addr            address
		expectedBalance int64
		shouldPanic     bool
	}{
		{
			name:            "get balance for registered token",
			path:            tokenPath,
			addr:            defaultHolder,
			expectedBalance: foo20.BalanceOf(defaultHolder),
			shouldPanic:     false,
		},
		{
			name:        "panic with unregistered token",
			path:        "not_registered_token",
			addr:        defaultHolder,
			shouldPanic: true,
		},
		{
			name:        "panic with empty string path",
			path:        "",
			addr:        defaultHolder,
			shouldPanic: true,
		},
		{
			name:            "get balance for empty address",
			path:            tokenPath,
			addr:            address(""),
			expectedBalance: int64(0),
			shouldPanic:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			if tt.shouldPanic {
				uassert.AbortsContains(t, cur, "unknown token", func() {
					BalanceOf(tt.path, tt.addr)
				})
				return
			}

			balance := BalanceOf(tt.path, tt.addr)
			uassert.Equal(t, tt.expectedBalance, balance)
		})
	}
}

func TestGrc20regHelper_Allowance(t *testing.T) {
	owner := address("g1rp7cmetn27eqlpjpc4vuusf8kaj746tysc0qgh")
	spender := address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum")

	tests := []struct {
		name              string
		path              string
		owner             address
		spender           address
		expectedAllowance int64
		shouldPanic       bool
	}{
		{
			name:              "get allowance for registered token",
			path:              tokenPath,
			owner:             owner,
			spender:           spender,
			expectedAllowance: foo20.Allowance(owner, spender),
			shouldPanic:       false,
		},
		{
			name:        "panic with unregistered token",
			path:        "not_registered_token",
			owner:       owner,
			spender:     spender,
			shouldPanic: true,
		},
		{
			name:        "panic with empty string path",
			path:        "",
			owner:       owner,
			spender:     spender,
			shouldPanic: true,
		},
		{
			name:              "get allowance with empty owner address",
			path:              tokenPath,
			owner:             address(""),
			spender:           spender,
			expectedAllowance: int64(0),
			shouldPanic:       false,
		},
		{
			name:              "get allowance with empty spender address",
			path:              tokenPath,
			owner:             owner,
			spender:           address(""),
			expectedAllowance: int64(0),
			shouldPanic:       false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			if tt.shouldPanic {
				uassert.AbortsContains(t, cur, "unknown token", func() {
					Allowance(tt.path, tt.owner, tt.spender)
				})
				return
			}

			allowance := Allowance(tt.path, tt.owner, tt.spender)
			uassert.Equal(t, tt.expectedAllowance, allowance)
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
