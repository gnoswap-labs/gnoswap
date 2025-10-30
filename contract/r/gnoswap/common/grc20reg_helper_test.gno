package common

import (
	"math"
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/demo/defi/foo20"
)

var tokenPath = "gno.land/r/demo/defi/foo20"

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
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic for %s", tt.name)
					}
				}()
			}

			token := GetToken(tt.path)

			if !tt.shouldPanic && token == nil {
				t.Error("Expected non-nil token")
			}
		})
	}
}

func TestGrc20regHelper_TokenMethod(t *testing.T) {
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

func TestGrc20regHelper_GetTokenTeller(t *testing.T) {
	tests := []struct {
		name        string
		path        string
		shouldPanic bool
	}{
		{
			name:        "get registered token teller",
			path:        tokenPath,
			shouldPanic: false,
		},
		{
			name:        "get non registered token teller",
			path:        "not_registered_teller",
			shouldPanic: true,
		},
		{
			name:        "get token teller with empty string path",
			path:        "",
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

			teller := GetTokenTeller(tt.path)

			if !tt.shouldPanic && teller == nil {
				t.Error("Expected non-nil teller")
			}
		})
	}
}

func TestGrc20regHelper_Transfer(t *testing.T) {
	tests := []struct {
		name          string
		path          string
		to            address
		amount        int64
		expectedError bool
		shouldPanic   bool
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
		{
			name:        "transfer with unregistered token path",
			path:        "not_registered_token",
			to:          address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      1000,
			shouldPanic: true,
		},
		{
			name:        "transfer with empty string path",
			path:        "",
			to:          address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      1000,
			shouldPanic: true,
		},
		{
			name:          "transfer to empty address",
			path:          tokenPath,
			to:            address(""),
			amount:        1000,
			expectedError: true,
		},
		{
			name:          "transfer max int64 amount",
			path:          tokenPath,
			to:            address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        math.MaxInt64,
			expectedError: true,
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
			err := Transfer(cross, tt.path, tt.to, tt.amount)
			if !tt.shouldPanic {
				if tt.expectedError {
					uassert.Error(t, err)
				} else {
					uassert.NoError(t, err)
				}
			}
		})
	}
}

func TestGrc20regHelper_TransferFrom(t *testing.T) {
	tests := []struct {
		name          string
		path          string
		from          address
		to            address
		amount        int64
		setupApproval bool
		approvalAmt   int64
		expectedError bool
		shouldPanic   bool
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
		{
			name:        "transfer from with unregistered token",
			path:        "not_registered_token",
			from:        address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"),
			to:          address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      100,
			shouldPanic: true,
		},
		{
			name:          "transfer from with empty from address",
			path:          tokenPath,
			from:          address(""),
			to:            address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        100,
			expectedError: true,
		},
		{
			name:          "transfer from with empty to address",
			path:          tokenPath,
			from:          address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"),
			to:            address(""),
			amount:        100,
			expectedError: true,
		},
		{
			name:          "transfer from zero amount with zero allowance",
			path:          tokenPath,
			from:          address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"),
			to:            address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:        0,
			setupApproval: false,
			expectedError: false,
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

			if tt.setupApproval {
				// Setup approval first - would need proper realm setup
				// Skip for now as it requires more complex setup
			}

			err := TransferFrom(cross, tt.path, tt.from, tt.to, tt.amount)
			if !tt.shouldPanic {
				if tt.expectedError {
					uassert.Error(t, err)
				} else {
					uassert.NoError(t, err)
				}
			}
		})
	}
}

func TestGrc20regHelper_Approve(t *testing.T) {
	tests := []struct {
		name          string
		path          string
		spender       address
		amount        int64
		expectedError bool
		shouldPanic   bool
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
			amount:        math.MaxInt64,
			expectedError: false,
		},
		{
			name:        "approve with unregistered token",
			path:        "not_registered_token",
			spender:     address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      1000,
			shouldPanic: true,
		},
		{
			name:          "approve with empty spender address",
			path:          tokenPath,
			spender:       address(""),
			amount:        1000,
			expectedError: true,
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
			err := Approve(cross, tt.path, tt.spender, tt.amount)
			if !tt.shouldPanic {
				if tt.expectedError {
					uassert.Error(t, err)
				} else {
					uassert.NoError(t, err)
				}
			}
		})
	}
}

func TestGrc20regHelper_SafeGRC20Transfer(t *testing.T) {
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
		{
			name:        "safe transfer with unregistered token",
			path:        "not_registered_token",
			to:          address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      100,
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

func TestGrc20regHelper_SafeGRC20TransferFrom(t *testing.T) {
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
		{
			name:        "safe transfer from with unregistered token",
			path:        "not_registered_token",
			from:        address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"),
			to:          address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      100,
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

func TestGrc20regHelper_SafeGRC20Approve(t *testing.T) {
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
		{
			name:        "safe approve with unregistered token",
			path:        "not_registered_token",
			spender:     address("g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"),
			amount:      1000,
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
			SafeGRC20Approve(cross, tt.path, tt.spender, tt.amount)
		})
	}
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
		t.Run(tt.name, func(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic for %s", tt.name)
					}
				}()
			}
			MustRegistered(tt.paths...)
		})
	}
}

func TestGrc20regHelper_ExtractTokenPathsFromRender(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic for %s", tt.name)
					}
				}()
			}

			supply := TotalSupply(tt.path)

			if !tt.shouldPanic {
				uassert.Equal(t, tt.expectedSupply, supply)
			}
		})
	}
}

func TestGrc20regHelper_BalanceOf(t *testing.T) {
	defaultHolder := address("g1manfred47kzduec920z88wfr64ylksmdcedlf5")

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
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic for %s", tt.name)
					}
				}()
			}

			balance := BalanceOf(tt.path, tt.addr)

			if !tt.shouldPanic {
				uassert.Equal(t, tt.expectedBalance, balance)
			}
		})
	}
}

func TestGrc20regHelper_Allowance(t *testing.T) {
	owner := address("g1manfred47kzduec920z88wfr64ylksmdcedlf5")
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
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic for %s", tt.name)
					}
				}()
			}

			allowance := Allowance(tt.path, tt.owner, tt.spender)

			if !tt.shouldPanic {
				uassert.Equal(t, tt.expectedAllowance, allowance)
			}
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
