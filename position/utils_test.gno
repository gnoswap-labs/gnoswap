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
