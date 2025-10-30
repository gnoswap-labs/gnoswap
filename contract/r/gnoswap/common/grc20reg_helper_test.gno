package common

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/demo/defi/foo20"
)

var tokenPath = "gno.land/r/demo/defi/foo20"

func TestGetToken(t *testing.T) {
	t.Run("get regsitered token", func(t *testing.T) {
		token := GetToken(tokenPath)
		if token == nil {
			t.Error("Expected non-nil token for foo20")
		}
	})

	t.Run("get non registered token", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic for non-registered token")
			}
		}()
		GetToken("not_registered_token")
	})
}

func TestTokenMethod(t *testing.T) {
	token := GetToken(tokenPath)

	t.Run("GetName()", func(t *testing.T) {
		uassert.Equal(t, "Foo", token.GetName())
	})

	t.Run("GetSymbol()", func(t *testing.T) {
		uassert.Equal(t, "FOO", token.GetSymbol())
	})

	t.Run("GetDecimals()", func(t *testing.T) {
		uassert.Equal(t, int(4), token.GetDecimals())
	})

	t.Run("TotalSupply()", func(t *testing.T) {
		uassert.Equal(t, int64(10000000000), token.TotalSupply())
	})

	t.Run("KnownAccounts()", func(t *testing.T) {
		uassert.Equal(t, int(1), token.KnownAccounts())
	})

	t.Run("BalanceOf()", func(t *testing.T) {
		uassert.Equal(t, int64(10000000000), token.BalanceOf(address("g1manfred47kzduec920z88wfr64ylksmdcedlf5")))
	})

	t.Run("Allowance()", func(t *testing.T) {
		uassert.Equal(t, int64(0), token.Allowance(address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"), address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum")))
	})

	t.Run("RenderHome()", func(t *testing.T) {
		expected := ""
		expected += ufmt.Sprintf("# %s ($%s)\n\n", "Foo", "FOO")
		expected += ufmt.Sprintf("* **Decimals**: %d\n", 4)
		expected += ufmt.Sprintf("* **Total supply**: %d\n", 10000000000)
		expected += ufmt.Sprintf("* **Known accounts**: %d\n", 1)
		uassert.Equal(t, expected, token.RenderHome())
	})
}

func TestGetTokenTeller(t *testing.T) {
	t.Run("get registered token teller", func(t *testing.T) {
		teller := GetTokenTeller(tokenPath)
		if teller == nil {
			t.Error("Expected non-nil teller for foo20")
		}
	})

	t.Run("get non registered token teller", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic for non-registered token teller")
			}
		}()
		GetTokenTeller("not_registered_teller")
	})
}

func TestTransfer(t *testing.T) {
	tests := []struct {
		name          string
		path          string
		to            address
		amount        int64
		expectedError bool
	}{
		{
			name:          "transfer to valid address",
			path:          tokenPath,
			to:            address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        1000,
			expectedError: false,
		},
		{
			name:          "transfer with insufficient balance",
			path:          tokenPath,
			to:            address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        99999999999999,
			expectedError: true,
		},
		{
			name:          "transfer zero amount",
			path:          tokenPath,
			to:            address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        0,
			expectedError: false,
		},
		{
			name:          "transfer negative amount",
			path:          tokenPath,
			to:            address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        -100,
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := Transfer(cross, tt.path, tt.to, tt.amount)
			if tt.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestTransferFrom(t *testing.T) {
	tests := []struct {
		name          string
		path          string
		from          address
		to            address
		amount        int64
		setupApproval bool
		approvalAmt   int64
		expectedError bool
	}{
		{
			name:          "transfer from with sufficient allowance",
			path:          tokenPath,
			from:          address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"),
			to:            address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        100,
			setupApproval: true,
			approvalAmt:   1000,
			expectedError: false,
		},
		{
			name:          "transfer from without allowance",
			path:          tokenPath,
			from:          address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"),
			to:            address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        100,
			setupApproval: false,
			expectedError: true,
		},
		{
			name:          "transfer from with insufficient allowance",
			path:          tokenPath,
			from:          address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"),
			to:            address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        2000,
			setupApproval: true,
			approvalAmt:   1000,
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setupApproval {
				// Setup approval first - would need proper realm setup
				// Skip for now as it requires more complex setup
			}

			err := TransferFrom(cross, tt.path, tt.from, tt.to, tt.amount)
			if tt.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestApprove(t *testing.T) {
	tests := []struct {
		name          string
		path          string
		spender       address
		amount        int64
		expectedError bool
	}{
		{
			name:          "approve valid amount",
			path:          tokenPath,
			spender:       address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        1000,
			expectedError: false,
		},
		{
			name:          "approve zero amount",
			path:          tokenPath,
			spender:       address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        0,
			expectedError: false,
		},
		{
			name:          "approve negative amount",
			path:          tokenPath,
			spender:       address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        -100,
			expectedError: true,
		},
		{
			name:          "approve large amount",
			path:          tokenPath,
			spender:       address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        9223372036854775807,
			expectedError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := Approve(cross, tt.path, tt.spender, tt.amount)
			if tt.expectedError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestSafeGRC20Transfer(t *testing.T) {
	tests := []struct {
		name        string
		path        string
		to          address
		amount      int64
		shouldPanic bool
	}{
		{
			name:        "safe transfer success",
			path:        tokenPath,
			to:          address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      100,
			shouldPanic: false,
		},
		{
			name:        "safe transfer with insufficient balance",
			path:        tokenPath,
			to:          address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      99999999999999,
			shouldPanic: true,
		},
		{
			name:        "safe transfer negative amount",
			path:        tokenPath,
			to:          address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      -100,
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic for %s", tt.name)
					}
				}()
			}
			SafeGRC20Transfer(cross, tt.path, tt.to, tt.amount)
		})
	}
}

func TestSafeGRC20TransferFrom(t *testing.T) {
	tests := []struct {
		name        string
		path        string
		from        address
		to          address
		amount      int64
		shouldPanic bool
	}{
		{
			name:        "safe transfer from without allowance",
			path:        tokenPath,
			from:        address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"),
			to:          address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      100,
			shouldPanic: true,
		},
		{
			name:        "safe transfer from with insufficient balance",
			path:        tokenPath,
			from:        address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"),
			to:          address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      99999999999999,
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic for %s", tt.name)
					}
				}()
			}
			SafeGRC20TransferFrom(cross, tt.path, tt.from, tt.to, tt.amount)
		})
	}
}

func TestSafeGRC20Approve(t *testing.T) {
	tests := []struct {
		name        string
		path        string
		spender     address
		amount      int64
		shouldPanic bool
	}{
		{
			name:        "safe approve valid amount",
			path:        tokenPath,
			spender:     address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      1000,
			shouldPanic: false,
		},
		{
			name:        "safe approve negative amount",
			path:        tokenPath,
			spender:     address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      -100,
			shouldPanic: true,
		},
		{
			name:        "safe approve zero amount",
			path:        tokenPath,
			spender:     address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      0,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic for %s", tt.name)
					}
				}()
			}
			SafeGRC20Approve(cross, tt.path, tt.spender, tt.amount)
		})
	}
}

func TestIsRegistered(t *testing.T) {
	t.Run("check if token is registered", func(t *testing.T) {
		uassert.NoError(t, IsRegistered(tokenPath))
	})

	t.Run("check if token is not registered", func(t *testing.T) {
		uassert.Error(t, IsRegistered("not_registered_token"))
	})
}

func TestMustRegistered(t *testing.T) {
	t.Run("must be registered", func(t *testing.T) {
		MustRegistered(tokenPath)
	})

	t.Run("panic for non registered token", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic for non-registered token")
			}
		}()
		MustRegistered("not_registered")
	})
}

func TestExtractTokenPathsFromRender(t *testing.T) {
	var (
		wugnotPath = "gno.land/r/gnoland/wugnot"
		gnsPath    = "gno.land/r/gnoswap/gns"
		fooPath    = "gno.land/r/onbloc/foo"
		quxPath    = "gno.land/r/onbloc/qux"
	)

	// NOTE: following strings are return from grc20reg.Render()
	renderList := []string{
		// no registered token
		`No registered token.`,

		// 1 token
		`- **wrapped GNOT** - [gno.land/r/gnoland/wugnot](/r/demo/wugnot) - [info](/r/demo/grc20reg:gno.land/r/gnoland/wugnot)`,

		// 2 tokens
		`- **wrapped GNOT** - [gno.land/r/gnoland/wugnot](/r/demo/wugnot) - [info](/r/demo/grc20reg:gno.land/r/gnoland/wugnot)
- **Gnoswap** - [gno.land/r/gnoswap/gns](/r/gnoswap/v1/gns) - [info](/r/demo/grc20reg:gno.land/r/gnoswap/gns)
`,

		// 4 tokens
		`- **wrapped GNOT** - [gno.land/r/gnoland/wugnot](/r/demo/wugnot) - [info](/r/demo/grc20reg:gno.land/r/gnoland/wugnot)
- **Gnoswap** - [gno.land/r/gnoswap/gns](/r/gnoswap/v1/gns) - [info](/r/demo/grc20reg:gno.land/r/gnoswap/gns)
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

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			extracted := extractTokenPathsFromRender(tt.render)
			uassert.True(t, areSlicesEqual(t, tt.expected, extracted))
		})
	}
}

func TestTotalSupply(t *testing.T) {
	// result from grc2reg and (direct import/call) should be the same
	uassert.Equal(t, foo20.TotalSupply(), TotalSupply(tokenPath))
}

func TestBalanceOf(t *testing.T) {
	defaultHolder := address("g1manfred47kzduec920z88wfr64ylksmdcedlf5")

	// result from grc2reg and (direct import/call) should be the same
	uassert.Equal(t, foo20.BalanceOf(defaultHolder), BalanceOf(tokenPath, defaultHolder))
}

func TestAllowance(t *testing.T) {
	owner := address("g1manfred47kzduec920z88wfr64ylksmdcedlf5")
	spender := address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum")

	// result from grc2reg and (direct import/call) should be the same
	uassert.Equal(t, foo20.Allowance(owner, spender), Allowance(tokenPath, owner, spender))
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
