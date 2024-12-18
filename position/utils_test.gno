package position

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	pusers "gno.land/p/demo/users"
	"gno.land/r/demo/users"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

func TestA2u(t *testing.T) {
	var (
		addr = std.Address("g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c")
	)

	tests := []struct {
		name     string
		input    std.Address
		expected pusers.AddressOrName
	}{
		{
			name:     "Success - a2u",
			input:    addr,
			expected: pusers.AddressOrName(addr),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := a2u(tc.input)
			uassert.Equal(t, users.Resolve(got).String(), users.Resolve(tc.expected).String())
		})
	}
}

func TestDerivePkgAddr(t *testing.T) {
	var (
		pkgPath = "gno.land/r/gnoswap/v1/position"
	)
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "Success - derivePkgAddr",
			input:    pkgPath,
			expected: "g1q646ctzhvn60v492x8ucvyqnrj2w30cwh6efk5",
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := derivePkgAddr(tc.input)
			uassert.Equal(t, got.String(), tc.expected)
		})
	}
}

func TestGetOrigPkgAddr(t *testing.T) {
	tests := []struct {
		name     string
		expected std.Address
	}{
		{
			name:     "Success - getOrigPkgAddr",
			expected: consts.POSITION_ADDR,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := getOrigPkgAddr()
			uassert.Equal(t, got, tc.expected)
		})
	}
}

func TestGetPrevRealm(t *testing.T) {
	tests := []struct {
		name         string
		originCaller std.Address
		expected     []string
	}{
		{
			name:         "Success - prevRealm is User",
			originCaller: consts.ADMIN,
			expected:     []string{"g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", ""},
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			std.TestSetOrigCaller(std.Address(tc.originCaller))
			got := getPrevRealm()
			uassert.Equal(t, got.Addr().String(), tc.expected[0])
			uassert.Equal(t, got.PkgPath(), tc.expected[1])
		})
	}
}

func TestGetPrevAddr(t *testing.T) {
	tests := []struct {
		name         string
		originCaller std.Address
		expected     std.Address
	}{
		{
			name:         "Success - prev Address is User",
			originCaller: consts.ADMIN,
			expected:     "g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d",
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			std.TestSetOrigCaller(std.Address(tc.originCaller))
			got := getPrevAddr()
			uassert.Equal(t, got.String(), tc.expected.String())
		})
	}
}

func TestGetPrevAsString(t *testing.T) {
	tests := []struct {
		name         string
		originCaller std.Address
		expected     []string
	}{
		{
			name:         "Success - prev Realm of user info as string",
			originCaller: consts.ADMIN,
			expected:     []string{"g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", ""},
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			std.TestSetOrigCaller(std.Address(tc.originCaller))
			got1, got2 := getPrevAsString()
			uassert.Equal(t, got1, tc.expected[0])
			uassert.Equal(t, got2, tc.expected[1])
		})
	}
}

func TestIsUserCall(t *testing.T) {
	tests := []struct {
		name          string
		originCaller  std.Address
		originPkgPath string
		expected      bool
	}{
		{
			name:         "Success - User Call",
			originCaller: consts.ADMIN,
			expected:     true,
		},
		{
			name:          "Failure - Not User Call",
			originCaller:  consts.ROUTER_ADDR,
			originPkgPath: consts.ROUTER_PATH,
			expected:      false,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			std.TestSetOrigCaller(tc.originCaller)
			if !tc.expected {
				std.TestSetRealm(std.NewCodeRealm(tc.originPkgPath))
			}
			got := isUserCall()
			uassert.Equal(t, got, tc.expected)
		})
	}
}

func TestCheckDeadline(t *testing.T) {
	tests := []struct {
		name     string
		deadline int64
		now      int64
		expected string
	}{
		{
			name:     "Success - checkDeadline",
			deadline: 1234567890 + 100,
			now:      1234567890,
			expected: "",
		},
		{
			name:     "Failure - checkDeadline",
			deadline: 1234567890 - 100,
			now:      1234567890,
			expected: "[GNOSWAP-POSITION-007] transaction expired || transaction too old, now(1234567890) > deadline(1234567790)",
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expected != "" {
				uassert.PanicsWithMessage(t, tc.expected, func() {
					checkDeadline(tc.deadline)
				})
			} else {
				uassert.NotPanics(t, func() {
					checkDeadline(tc.deadline)
				})
			}
		})
	}
}

func TestAssertOnlyUserOrStaker(t *testing.T) {
	tests := []struct {
		name         string
		originCaller std.Address
		expected     bool
	}{
		{
			name:         "Failure - Not User or Staker",
			originCaller: consts.ROUTER_ADDR,
			expected:     false,
		},
		{
			name:         "Success - User Call",
			originCaller: consts.ADMIN,
			expected:     true,
		},
		{
			name:         "Success - Staker Call",
			originCaller: consts.STAKER_ADDR,
			expected:     true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			std.TestSetOrigCaller(tc.originCaller)
			assertOnlyUserOrStaker(std.PrevRealm())
		})
	}
}

func TestAssertOnlyNotHalted(t *testing.T) {
	tests := []struct {
		name     string
		expected bool
		panicMsg string
	}{
		{
			name:     "Failure - Halted",
			expected: false,
			panicMsg: "[GNOSWAP-COMMON-002] halted || gnoswap halted",
		},
		{
			name:     "Success - Not Halted",
			expected: true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expected {
				uassert.NotPanics(t, func() {
					assertOnlyNotHalted()
				})
			} else {
				std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
				common.SetHaltByAdmin(true)
				uassert.PanicsWithMessage(t, tc.panicMsg, func() {
					assertOnlyNotHalted()
				})
				common.SetHaltByAdmin(false)
			}
		})
	}
}

func TestAssertOnlyValidAddress(t *testing.T) {
	tests := []struct {
		name     string
		addr     std.Address
		expected bool
		errorMsg string
	}{
		{
			name:     "Success - valid address",
			addr:     consts.ADMIN,
			expected: true,
		},
		{
			name:     "Failure - invalid address",
			addr:     "g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8", // invalid length
			expected: false,
			errorMsg: "[GNOSWAP-POSITION-011] invalid address || (g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8)",
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expected {
				uassert.NotPanics(t, func() {
					assertOnlyValidAddress(tc.addr)
				})
			} else {
				uassert.PanicsWithMessage(t, tc.errorMsg, func() {
					assertOnlyValidAddress(tc.addr)
				})
			}
		})
	}
}

func TestAssertOnlyValidAddressWith(t *testing.T) {
	tests := []struct {
		name     string
		addr     std.Address
		other    std.Address
		expected bool
		errorMsg string
	}{
		{
			name:     "Success - validation address check to compare with other address",
			addr:     consts.ADMIN,
			other:    std.Address("g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d"),
			expected: true,
		},
		{
			name:     "Failure - two address is different",
			addr:     "g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8",
			other:    "g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d",
			expected: false,
			errorMsg: "[GNOSWAP-POSITION-011] invalid address || (g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8)",
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expected {
				uassert.NotPanics(t, func() {
					assertOnlyValidAddressWith(tc.addr, tc.other)
				})
			} else {
				uassert.PanicsWithMessage(t, tc.errorMsg, func() {
					assertOnlyValidAddressWith(tc.addr, tc.other)
				})
			}
		})
	}
}

// region: gno_helper

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
