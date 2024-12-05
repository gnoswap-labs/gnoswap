package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/demo/users"
)

func TestA2U(t *testing.T) {
	validAddr := testutils.TestAddress("validAddr")
	invalidAddr := std.Address("invalidAddr")

	tests := []struct {
		name        string
		expected    string
		address     std.Address
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:     "valid address",
			expected: validAddr.String(),
			address:  validAddr,
		},
		{
			name:        "invalid address",
			expected:    invalidAddr.String(),
			address:     invalidAddr,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-023] invalid address || invalidAddr",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() { a2u(tt.address) })
			} else {
				uassert.Equal(t, tt.expected, users.Resolve(a2u(tt.address)).String())
			}
		})
	}
}

func TestU256Min(t *testing.T) {
	tests := []struct {
		name     string
		num1     string
		num2     string
		expected string
	}{
		{
			name:     "num1 is less than num2",
			num1:     "1",
			num2:     "2",
			expected: "1",
		},
		{
			name:     "num1 is greater than num2",
			num1:     "2",
			num2:     "1",
			expected: "1",
		},
		{
			name:     "num1 is equal to num2",
			num1:     "1",
			num2:     "1",
			expected: "1",
		},
		{
			name:     "compare max u256 with zero",
			num1:     "115792089237316195423570985008687907853269984665640564039457584007913129639935",
			num2:     "0",
			expected: "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			num1 := u256.MustFromDecimal(tt.num1)
			num2 := u256.MustFromDecimal(tt.num2)
			expected := u256.MustFromDecimal(tt.expected)

			uassert.Equal(t, expected.ToString(), u256Min(num1, num2).ToString())
		})
	}
}

func TestIsUserCall(t *testing.T) {
	tests := []struct {
		name     string
		action   func() bool
		expected bool
	}{
		{
			name: "called from user",
			action: func() bool {
				userRealm := std.NewUserRealm(std.Address("user"))
				std.TestSetRealm(userRealm)
				return isUserCall()
			},
			expected: true,
		},
		{
			name: "called from realm",
			action: func() bool {
				fromRealm := std.NewCodeRealm("gno.land/r/realm")
				std.TestSetRealm(fromRealm)
				return isUserCall()
			},
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.expected, tt.action())
		})
	}
}

func TestGetPrev(t *testing.T) {
	tests := []struct {
		name            string
		action          func() (string, string)
		expectedAddr    string
		expectedPkgPath string
	}{
		{
			name: "user call",
			action: func() (string, string) {
				userRealm := std.NewUserRealm(std.Address("user"))
				std.TestSetRealm(userRealm)
				return getPrev()
			},
			expectedAddr:    "user",
			expectedPkgPath: "",
		},
		{
			name: "code call",
			action: func() (string, string) {
				codeRealm := std.NewCodeRealm("gno.land/r/demo/realm")
				std.TestSetRealm(codeRealm)
				return getPrev()
			},
			expectedAddr:    std.DerivePkgAddr("gno.land/r/demo/realm").String(),
			expectedPkgPath: "gno.land/r/demo/realm",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			addr, pkgPath := tt.action()
			uassert.Equal(t, tt.expectedAddr, addr)
			uassert.Equal(t, tt.expectedPkgPath, pkgPath)
		})
	}
}
