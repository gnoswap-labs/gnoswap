package position

import (
	"std"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
)

func assertPanic(t *testing.T, expectedMsg string, fn func()) {
	t.Helper()
	defer func() {
		r := recover()
		if r == nil {
			t.Errorf("expected panic but got none")
		} else if r != expectedMsg {
			t.Errorf("expected panic %v, got %v", expectedMsg, r)
		}
	}()
	fn()
}

func TestGetOrigPkgAddr(t *testing.T) {
	tests := []struct {
		name     string
		expected std.Address
	}{
		{
			name:     "Success - getOrigPkgAddr",
			expected: positionAddr,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := GetOrigPkgAddr()
			uassert.Equal(t, got, tc.expected)
		})
	}
}

func TestAssertTokenExists(t *testing.T) {
	// Mock setup
	// mockTokenId := uint64(1)
	mockInvalidTokenId := uint64(9999)

	// t.Run("Token Exists - No Panic", func(t *testing.T) {
	// 	defer func() {
	// 		if r := recover(); r != nil {
	// 			t.Errorf("unexpected panic for existing positionId(%d): %v", mockTokenId, r)
	// 		}
	// 	}()
	// 	assertTokenExists(mockTokenId) // Should not panic
	// })

	t.Run("Token Does Not Exist - Panic Expected", func(t *testing.T) {
		expectedErr := ufmt.Sprintf("[GNOSWAP-POSITION-006] requested data not found || positionId(%d) doesn't exist", mockInvalidTokenId)
		uassert.PanicsWithMessage(t, expectedErr, func() {
			assertTokenExists(mockInvalidTokenId) // Should panic
		})
	})

	t.Run("Boundary Case - PositionId Zero", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("expected panic for positionId(0) but did not occur")
			}
		}()
		assertTokenExists(0) // Assume positionId 0 does not exist
	})
}

func TestAssertOnlyUserOrStaker(t *testing.T) {
	tests := []struct {
		name         string
		originCaller std.Address
		expected     bool
	}{
		{
			name:         "Failure - Not User or Staker",
			originCaller: routerAddr,
			expected:     false,
		},
		{
			name:         "Success - User Call",
			originCaller: adminAddr,
			expected:     true,
		},
		{
			name:         "Success - Staker Call",
			originCaller: stakerAddr,
			expected:     true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			testing.SetOriginCaller(tc.originCaller)
			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/staker"))
				assertOnlyUserOrStaker(std.PreviousRealm())
			}()
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
			addr:     adminAddr,
			expected: true,
		},
		{
			name:     "Failure - invalid address",
			addr:     "g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8", // invalid length
			expected: false,
			errorMsg: "[GNOSWAP-POSITION-012] invalid address || (g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8)",
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
			addr:     adminAddr,
			other:    std.Address("g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d"),
			expected: true,
		},
		{
			name:     "Failure - two address is different",
			addr:     "g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8",
			other:    "g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d",
			expected: false,
			errorMsg: "[GNOSWAP-POSITION-012] invalid address || (g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8)",
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

func TestAssertValidNumberString(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		expectPanic bool
	}{
		// Valid Cases
		{
			name:        "Valid Positive Number",
			input:       "12345",
			expectPanic: false,
		},
		{
			name:        "Valid Negative Number",
			input:       "-98765",
			expectPanic: false,
		},
		{
			name:        "Zero",
			input:       "0",
			expectPanic: false,
		},
		{
			name:        "Negative Zero",
			input:       "-0",
			expectPanic: false,
		},

		// Invalid Cases
		{
			name:        "Empty String",
			input:       "",
			expectPanic: true,
		},
		{
			name:        "Alphabet in String",
			input:       "12a45",
			expectPanic: true,
		},
		{
			name:        "Special Characters",
			input:       "123@45",
			expectPanic: true,
		},
		{
			name:        "Leading Plus Sign",
			input:       "+12345",
			expectPanic: true,
		},
		{
			name:        "Multiple Negative Signs",
			input:       "--12345",
			expectPanic: true,
		},
		{
			name:        "Space in String",
			input:       "123 45",
			expectPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if !tt.expectPanic {
						t.Errorf("unexpected panic for input: %s, got: %v", tt.input, r)
					}
				} else {
					if tt.expectPanic {
						t.Errorf("expected panic but did not occur for input: %s", tt.input)
					}
				}
			}()

			assertValidNumberString(tt.input)
		})
	}
}

func TestDerivePkgAddr(t *testing.T) {
	pkgPath := "gno.land/r/gnoswap/v1/position"
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

func TestGetPrevRealm(t *testing.T) {
	tests := []struct {
		name         string
		originCaller std.Address
		expected     []string
	}{
		{
			name:         "Success - prevRealm is User",
			originCaller: adminAddr,
			expected:     []string{"g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", ""},
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			testing.SetOriginCaller(std.Address(tc.originCaller))
			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/position"))
				got := getPrevRealm()
				uassert.Equal(t, got.Address().String(), tc.expected[0])
				uassert.Equal(t, got.PkgPath(), tc.expected[1])
			}()
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
			originCaller: adminAddr,
			expected:     "g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d",
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			testing.SetOriginCaller(std.Address(tc.originCaller))
			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/position"))
				got := getPrevAddr()
				uassert.Equal(t, got.String(), tc.expected.String())
			}()
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
			originCaller: adminAddr,
			expected:     []string{"g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", ""},
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			testing.SetOriginCaller(std.Address(tc.originCaller))
			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/position"))
				got1, got2 := getPrevAsString()
				uassert.Equal(t, got1, tc.expected[0])
				uassert.Equal(t, got2, tc.expected[1])
			}()
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
		{
			name:     "Success - deadline equals now",
			deadline: 1234567890,
			now:      1234567890,
			expected: "",
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

func TestPositionIdFrom(t *testing.T) {
	tests := []struct {
		name        string
		input       any
		expected    string
		shouldPanic bool
	}{
		{
			name:        "Panic - nil",
			input:       nil,
			expected:    "[GNOSWAP-POSITION-005] invalid input data || positionId is nil",
			shouldPanic: true,
		},
		{
			name:        "Panic - unsupported type",
			input:       float64(1),
			expected:    "[GNOSWAP-POSITION-005] invalid input data || unsupported positionId type",
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
				got := positionIdFrom(tc.input)
				uassert.Equal(t, tc.expected, string(got))
			} else {
				positionIdFrom(tc.input)
			}
		})
	}
}

func TestIsOwner(t *testing.T) {
	tests := []struct {
		name       string
		positionId uint64
		addr       std.Address
		expected   bool
	}{
		{
			name:       "Fail - is not owner",
			positionId: 1,
			addr:       alice,
			expected:   false,
		},
		{
			name:       "Success - is owner",
			positionId: 1,
			addr:       adminAddr,
			expected:   true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// MakeMintPositionWithoutFee(t)
			got := isOwner(tc.positionId, tc.addr)
			uassert.Equal(t, tc.expected, got)
		})
	}
}

func TestIsOperator(t *testing.T) {
	tests := []struct {
		name       string
		positionId uint64
		addr       std.Address
		expected   bool
	}{
		{
			name:       "Fail - is not operator",
			positionId: 1,
			addr:       alice,
			expected:   false,
		},
		{
			name:       "Success - is operator",
			positionId: 1,
			addr:       bob,
			expected:   true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			testing.SetOriginCaller(adminAddr)

			if tc.expected {
				LPTokenApprove(t, adminAddr, tc.addr, tc.positionId)
			}

			got := isOperator(tc.positionId, tc.addr)
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
		{
			name:          "Fail -empty poolKey",
			poolKey:       "",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid poolKey()",
			shouldPanic:   true,
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

func TestSplitOf(t *testing.T) {
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
			name:          "Fail - empty poolKey",
			poolKey:       "",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid poolKey()",
			shouldPanic:   true,
		},
		{
			name:          "Fail - invalid delimiter",
			poolKey:       "gno.land/r/gnoswap:v1/gns:gno.land/r/demo/wugnot-500",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid fee(gno.land/r/demo/wugnot-500)",
			shouldPanic:   true,
		},
		{
			name:          "Fail - non-numeric fee",
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:fee",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid fee(fee)",
			shouldPanic:   true,
		},
		{
			name:          "Fail - missing fee part",
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid fee()",
			shouldPanic:   true,
		},
		{
			name:          "Fail - insufficient parts",
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid poolKey(gno.land/r/gnoswap/v1/gns:gno.land/r/demo)",
			shouldPanic:   true,
		},
		{
			name:          "Success - valid poolKey",
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:500",
			expectedPath0: "gno.land/r/gnoswap/v1/gns",
			expectedPath1: "gno.land/r/demo/wugnot",
			expectedFee:   500,
			shouldPanic:   false,
		},
		{
			name:          "Success - poolKey with large fee",
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:10000",
			expectedPath0: "gno.land/r/gnoswap/v1/gns",
			expectedPath1: "gno.land/r/demo/wugnot",
			expectedFee:   10000,
			shouldPanic:   false,
		},
		{
			name:          "Success - poolKey with minimal fee",
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:1",
			expectedPath0: "gno.land/r/gnoswap/v1/gns",
			expectedPath1: "gno.land/r/demo/wugnot",
			expectedFee:   1,
			shouldPanic:   false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.shouldPanic {
				assertPanic(t, tc.expectedError, func() {
					splitOf(tc.poolKey)
				})
			} else {
				gotToken0, gotToken1, gotFee := splitOf(tc.poolKey)
				uassert.Equal(t, tc.expectedPath0, gotToken0, "Token0 mismatch")
				uassert.Equal(t, tc.expectedPath1, gotToken1, "Token1 mismatch")
				uassert.Equal(t, tc.expectedFee, gotFee, "Fee mismatch")
			}
		})
	}
}
