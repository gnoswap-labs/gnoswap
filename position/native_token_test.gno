package position

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/uassert"
	pusers "gno.land/p/demo/users"
	"gno.land/r/demo/users"
	"gno.land/r/gnoswap/v1/consts"
)

func TestTransferUGNOT(t *testing.T) {
	tests := []struct {
		name        string
		action      func(t *testing.T, from, to std.Address)
		verify      func(t *testing.T, to std.Address) uint64
		from        std.Address
		to          std.Address
		expected    string
		shouldPanic bool
	}{
		{
			name: "Success - Zero amount",
			action: func(t *testing.T, from, to std.Address) {
				transferUGNOT(from, to, 0)
			},
			verify: func(t *testing.T, to std.Address) uint64 {
				return ugnotBalanceOf(t, to)
			},
			from:        users.Resolve(alice),
			to:          users.Resolve(bob),
			expected:    "0",
			shouldPanic: false,
		},
		{
			name: "Success - Valid transfer",
			action: func(t *testing.T, from, to std.Address) {
				ugnotFaucet(t, from, 100)
				std.TestSetRealm(std.NewUserRealm(from))
				transferUGNOT(from, to, 100)
			},
			verify: func(t *testing.T, to std.Address) uint64 {
				return ugnotBalanceOf(t, to)
			},
			from:        consts.POSITION_ADDR,
			to:          users.Resolve(bob),
			expected:    "100",
			shouldPanic: false,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if r == nil {
					if tc.shouldPanic {
						t.Errorf(">>> %s: expected panic but got none", tc.name)
						return
					}
				} else {
					switch r.(type) {
					case string:
						if r.(string) != tc.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
						}
					case error:
						if r.(error).Error() != tc.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r.(error).Error(), tc.expected)
						}
					default:
						t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
					}
				}
			}()

			if !tc.shouldPanic {
				tc.action(t, tc.from, tc.to)
				if tc.verify != nil {
					balance := tc.verify(t, tc.to)
					uassert.Equal(t, tc.expected, strconv.FormatUint(balance, 10))
				}
			} else {
				tc.action(t, tc.from, tc.to)
			}
		})
	}
}

func TestWrap(t *testing.T) {
	tests := []struct {
		name        string
		action      func(t *testing.T, from, to std.Address) error
		verify      func(t *testing.T, to std.Address) uint64
		from        std.Address
		to          std.Address
		expected    string
		shouldPanic bool
	}{
		{
			name: "Failure - Amount less than minimum",
			action: func(t *testing.T, from, to std.Address) error {
				return wrap(999, to)
			},
			verify:      nil,
			from:        users.Resolve(alice),
			to:          users.Resolve(bob),
			expected:    "amount(999) < minimum(1000)",
			shouldPanic: true,
		},
		{
			name: "Failure - Zero amount",
			action: func(t *testing.T, from, to std.Address) error {
				return wrap(0, to)
			},
			verify:      nil,
			from:        users.Resolve(alice),
			to:          users.Resolve(bob),
			expected:    "amount(0) < minimum(1000)",
			shouldPanic: true,
		},
		{
			name: "Success - Valid amount",
			action: func(t *testing.T, from, to std.Address) error {
				ugnotFaucet(t, from, 1000)
				std.TestSetRealm(std.NewUserRealm(from))
				return wrap(1000, to)
			},
			verify: func(t *testing.T, to std.Address) uint64 {
				return TokenBalance(t, wugnotPath, pusers.AddressOrName(to))
			},
			from:        consts.POSITION_ADDR,
			to:          users.Resolve(bob),
			expected:    "1000",
			shouldPanic: false,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if r != nil {
					switch r.(type) {
					case string:
						if r.(string) != tc.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
						}
					case error:
						if r.(error).Error() != tc.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r.(error).Error(), tc.expected)
						}
					default:
						t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
					}
				}
			}()

			if !tc.shouldPanic {
				err := tc.action(t, tc.from, tc.to)
				if err == nil && tc.verify != nil {
					balance := tc.verify(t, tc.to)
					uassert.Equal(t, tc.expected, strconv.FormatUint(balance, 10))
				}
			} else {
				err := tc.action(t, tc.from, tc.to)
				if err != nil {
					uassert.Equal(t, tc.expected, err.Error())
				} else {
					t.Errorf(">>> %s: expected panic but got none", tc.name)
				}
			}
		})
	}
}

func TestUnWrap(t *testing.T) {
	tests := []struct {
		name        string
		action      func(t *testing.T, from, to std.Address) error
		verify      func(t *testing.T, to std.Address) uint64
		from        std.Address
		to          std.Address
		expected    string
		shouldPanic bool
	}{
		{
			name: "Failure - Zero amount",
			action: func(t *testing.T, from, to std.Address) error {
				return unwrap(0, to)
			},
			verify:      nil,
			from:        users.Resolve(alice),
			to:          users.Resolve(bob),
			expected:    "amount(0) is zero",
			shouldPanic: true,
		},
		{
			name: "Success - Valid amount",
			action: func(t *testing.T, from, to std.Address) error {
				ugnotFaucet(t, from, 1000)
				std.TestSetRealm(std.NewUserRealm(from))
				wrap(1000, to)
				std.TestSetRealm(std.NewUserRealm(to))
				TokenApprove(t, wugnotPath, pusers.AddressOrName(to), pusers.AddressOrName(from), 1000)
				return unwrap(1000, to)
			},
			verify: func(t *testing.T, to std.Address) uint64 {
				return TokenBalance(t, wugnotPath, pusers.AddressOrName(to))
			},
			from:        consts.POSITION_ADDR,
			to:          users.Resolve(bob),
			expected:    "1000",
			shouldPanic: false,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if r != nil {
					switch r.(type) {
					case string:
						if r.(string) != tc.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
						}
					case error:
						if r.(error).Error() != tc.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r.(error).Error(), tc.expected)
						}
					default:
						t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
					}
				}
			}()

			if !tc.shouldPanic {
				err := tc.action(t, tc.from, tc.to)
				if err == nil && tc.verify != nil {
					balance := tc.verify(t, tc.to)
					uassert.Equal(t, tc.expected, strconv.FormatUint(balance, 10))
				}
			} else {
				err := tc.action(t, tc.from, tc.to)
				if err != nil {
					uassert.Equal(t, tc.expected, err.Error())
				} else {
					t.Errorf(">>> %s: expected panic but got none", tc.name)
				}
			}
		})
	}
}
