package position

import (
	"std"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/uassert"
	pusers "gno.land/p/demo/users"
	"gno.land/r/demo/users"
)

func TestGetNextId(t *testing.T) {
	tests := []struct {
		name     string
		newMint  bool
		expected uint64
	}{
		{
			name:     "Success - initial nextId",
			newMint:  false,
			expected: 1,
		},
		{
			name:     "Success - after mint",
			newMint:  true,
			expected: 2,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.newMint {
				MakeMintPositionWithoutFee(t)
			}
			got := getNextId()
			uassert.Equal(t, tc.expected, got)
		})
	}
}

func TestTokenIdFrom(t *testing.T) {

	tests := []struct {
		name        string
		input       interface{}
		expected    string
		shouldPanic bool
	}{
		{
			name:        "Panic - nil",
			input:       nil,
			expected:    "[GNOSWAP-POSITION-005] invalid input data || tokenId is nil",
			shouldPanic: true,
		},
		{
			name:        "Panic - unsupported type",
			input:       float64(1),
			expected:    "[GNOSWAP-POSITION-005] invalid input data || unsupported tokenId type",
			shouldPanic: true,
		},
		{
			name:        "Success - string",
			input:       "1",
			expected:    "1",
			shouldPanic: false,
		},
		{
			name:        "Success - int",
			input:       int(1),
			expected:    "1",
			shouldPanic: false,
		},
		{
			name:        "Success - uint64",
			input:       uint64(1),
			expected:    "1",
			shouldPanic: false,
		},
		{
			name:        "Success - grc721.TokenID",
			input:       grc721.TokenID("1"),
			expected:    "1",
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
				got := tokenIdFrom(tc.input)
				uassert.Equal(t, tc.expected, string(got))
			} else {
				tokenIdFrom(tc.input)
			}
		})
	}
}

func TestExists(t *testing.T) {
	tests := []struct {
		name     string
		tokenId  uint64
		expected bool
	}{
		{
			name:     "Fail - not exists",
			tokenId:  2,
			expected: false,
		},
		{
			name:     "Success - exists",
			tokenId:  1,
			expected: true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := exists(tc.tokenId)
			uassert.Equal(t, tc.expected, got)
		})
	}
}

func TestIsOwner(t *testing.T) {
	tests := []struct {
		name     string
		tokenId  uint64
		addr     std.Address
		expected bool
	}{
		{
			name:     "Fail - is not owner",
			tokenId:  1,
			addr:     users.Resolve(alice),
			expected: false,
		},
		{
			name:     "Success - is owner",
			tokenId:  1,
			addr:     users.Resolve(admin),
			expected: true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			MakeMintPositionWithoutFee(t)
			got := isOwner(tc.tokenId, tc.addr)
			uassert.Equal(t, tc.expected, got)
		})
	}
}

func TestIsOperator(t *testing.T) {
	MakeMintPositionWithoutFee(t)
	tests := []struct {
		name     string
		tokenId  uint64
		addr     pusers.AddressOrName
		expected bool
	}{
		{
			name:     "Fail - is not operator",
			tokenId:  1,
			addr:     alice,
			expected: false,
		},
		{
			name:     "Success - is operator",
			tokenId:  1,
			addr:     bob,
			expected: true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expected {
				LPTokenApprove(t, admin, tc.addr, tc.tokenId)
			}
			got := isOperator(tc.tokenId, users.Resolve(tc.addr))
			uassert.Equal(t, tc.expected, got)
		})
	}
}

func TestIsStaked(t *testing.T) {
	MakeMintPositionWithoutFee(t)
	tests := []struct {
		name     string
		owner    pusers.AddressOrName
		operator pusers.AddressOrName
		tokenId  uint64
		expected bool
	}{
		{
			name:     "Fail - is not staked",
			owner:    bob,
			operator: alice,
			tokenId:  1,
			expected: false,
		},
		{
			name:     "Fail - is not exist tokenId",
			owner:    admin,
			operator: bob,
			tokenId:  100,
			expected: false,
		},
		{
			name:     "Success - is staked",
			owner:    admin,
			operator: admin,
			tokenId:  1,
			expected: true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expected && tc.owner == tc.operator {
				LPTokenStake(t, tc.owner, tc.tokenId)
			}
			got := isStaked(tokenIdFrom(tc.tokenId))
			uassert.Equal(t, tc.expected, got)
			if tc.expected && tc.owner == tc.operator {
				LPTokenUnStake(t, tc.owner, tc.tokenId, false)
			}
		})
	}
}

func TestIsOwnerOrOperator(t *testing.T) {
	MakeMintPositionWithoutFee(t)
	tests := []struct {
		name     string
		owner    pusers.AddressOrName
		operator pusers.AddressOrName
		tokenId  uint64
		expected bool
	}{
		{
			name:     "Fail - is not owner or operator",
			owner:    admin,
			operator: alice,
			tokenId:  1,
			expected: false,
		},
		{
			name:     "Success - is operator",
			owner:    admin,
			operator: bob,
			tokenId:  1,
			expected: true,
		},
		{
			name:     "Success - is owner",
			owner:    admin,
			operator: admin,
			tokenId:  1,
			expected: true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expected && tc.owner != tc.operator {
				LPTokenApprove(t, tc.owner, tc.operator, tc.tokenId)
			}
			var got bool
			if tc.owner == tc.operator {
				got = isOwnerOrOperator(users.Resolve(tc.owner), tc.tokenId)
			} else {
				got = isOwnerOrOperator(users.Resolve(tc.operator), tc.tokenId)
			}
			uassert.Equal(t, tc.expected, got)
		})
	}
}

func TestIsOwnerOrOperatorWithStake(t *testing.T) {
	MakeMintPositionWithoutFee(t)
	tests := []struct {
		name     string
		owner    pusers.AddressOrName
		operator pusers.AddressOrName
		tokenId  uint64
		isStake  bool
		expected bool
	}{
		{
			name:     "Fail - is not token staked",
			owner:    admin,
			operator: alice,
			tokenId:  1,
			isStake:  false,
			expected: false,
		},
		{
			name:     "Success - is token staked (position operator)",
			owner:    admin,
			operator: admin,
			tokenId:  1,
			isStake:  true,
			expected: true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.isStake {
				LPTokenStake(t, tc.owner, tc.tokenId)
			}
			got := isOwnerOrOperator(users.Resolve(tc.operator), tc.tokenId)
			uassert.Equal(t, tc.expected, got)
		})
	}
}

func TestPoolKeyDivide(t *testing.T) {
	tests := []struct {
		name          string
		poolKey       string
		expectedPath0 string
		expectedPath1 string
		expectedFee   uint32
		expectedError string
		shouldPanic   bool
	}{
		{
			name:          "Fail - invalid poolKey",
			poolKey:       "gno.land/r/onbloc",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid poolKey(gno.land/r/onbloc)",
			shouldPanic:   true,
		},
		{
			name:          "Success - split poolKey",
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:500",
			expectedPath0: gnsPath,
			expectedPath1: wugnotPath,
			expectedFee:   fee500,
			shouldPanic:   false,
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
						if r.(string) != tc.expectedError {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expectedError)
						}
					case error:
						if r.(error).Error() != tc.expectedError {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r.(error).Error(), tc.expectedError)
						}
					default:
						t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expectedError)
					}
				}
			}()

			if !tc.shouldPanic {
				gotToken0, gotToken1, gotFee := splitOf(tc.poolKey)
				uassert.Equal(t, tc.expectedPath0, gotToken0)
				uassert.Equal(t, tc.expectedPath1, gotToken1)
				uassert.Equal(t, tc.expectedFee, gotFee)
			} else {
				splitOf(tc.poolKey)
			}
		})
	}
}
