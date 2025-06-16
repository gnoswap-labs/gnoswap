package pool

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
	// pn "gno.land/r/gnoswap/v1/position"
)

func TestSetPoolCreationFee(t *testing.T) {
	tests := []struct {
		name        string
		action      func()
		verify      func() string
		expected    string
		shouldPanic bool
	}{
		{
			name: "Panic call by non-governance",
			action: func() {
				const newFee = 2_000_000_000
				testing.SetRealm(adminRealm)
				func() {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
					SetPoolCreationFee(cross, newFee)
				}()
			},
			verify: nil,
			// expected:    "caller(g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c) has no permission",
			expected:    ufmt.Sprintf("caller(%s) has no permission", adminRealm.Address().String()),
			shouldPanic: true,
		},
		{
			name: "Success call by governance",
			action: func() {
				const newFee = 2_000_000_000
				govRealm := std.NewUserRealm(govAddr)
				testing.SetRealm(govRealm)
				// testing.SetRealm(govRealm)
				func() {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
					SetPoolCreationFee(cross, newFee)
				}()
			},
			verify: func() string {
				return strconv.FormatInt(GetPoolCreationFee(), 10)
			},
			expected:    strconv.FormatInt(2_000_000_000, 10),
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
					if r.(string) != tc.expected {
						t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
					}
				}
			}()

			if !tc.shouldPanic {
				tc.action()
				if tc.verify != nil {
					got := tc.verify()
					uassert.Equal(t, got, tc.expected)
				}
			} else {
				tc.action()
			}
		})
	}
}

func TestSetPoolCreationFeeByAdmin(t *testing.T) {
	tests := []struct {
		name        string
		action      func()
		verify      func() string
		expected    string
		shouldPanic bool
	}{
		{
			name: "Panic call by non-admin (gov contract)",
			action: func() {
				const newFee = 2_000_000_000
				govRealm := std.NewUserRealm(govAddr)
				testing.SetRealm(govRealm)
				func() {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
					SetPoolCreationFeeByAdmin(cross, newFee)
				}()
			},
			verify:      nil,
			expected:    "caller(g17s8w2ve7k85fwfnrk59lmlhthkjdted8whvqxd) has no permission",
			shouldPanic: true,
		},
		{
			name: "Panic call by non-admin (user)",
			action: func() {
				const newFee = 2_000_000_000
				testing.SetRealm(std.NewUserRealm(alice))
				func() {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
					SetPoolCreationFeeByAdmin(cross, newFee)
				}()
			},
			verify:      nil,
			expected:    "caller(g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh) has no permission",
			shouldPanic: true,
		},
		{
			name: "Success call by admin",
			action: func() {
				const newFee = 2_000_000_000
				testing.SetRealm(adminRealm)
				func() {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
					SetPoolCreationFeeByAdmin(cross, newFee)
				}()
			},
			verify: func() string {
				return strconv.FormatInt(GetPoolCreationFee(), 10)
			},
			expected:    strconv.FormatInt(2_000_000_000, 10),
			shouldPanic: false,
		},
		{
			name: "Success call by admin (rollback)",
			action: func() {
				const newFee = 1_000_000_000
				testing.SetRealm(adminRealm)
				func() {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
					SetPoolCreationFeeByAdmin(cross, newFee)
				}()
			},
			verify: func() string {
				return strconv.FormatInt(GetPoolCreationFee(), 10)
			},
			expected:    strconv.FormatInt(1_000_000_000, 10),
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
					if r.(string) != tc.expected {
						t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
					}
				}
			}()

			if !tc.shouldPanic {
				tc.action()
				if tc.verify != nil {
					got := tc.verify()
					uassert.Equal(t, got, tc.expected)
				}
			} else {
				tc.action()
			}
		})
	}
}

// func TestHandleWithdrawalFee(t *testing.T) {
// 	tests := []struct {
// 		name        string
// 		action      func(t *testing.T)
// 		verify      func(t *testing.T) (string, string)
// 		expected    string
// 		shouldPanic bool
// 	}{
// 		{
// 			name: "Panic if caller is not position contract",
// 			action: func(t *testing.T) {
// 				testing.SetOriginCaller(adminAddr)
// 				CollectWithdrawalFee(0, "gno.land/r/onbloc/foo", "0", "gno.land/r/onbloc/foo", "0", "", adminAddr)
// 			},
// 			verify:      nil,
// 			expected:    "[GNOSWAP-POOL-001] caller has no permission || only position(g1q646ctzhvn60v492x8ucvyqnrj2w30cwh6efk5) can call this function, called from g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d",
// 			shouldPanic: true,
// 		},
// 		{
// 			name: "Panic if pkgPath is not registered",
// 			action: func(t *testing.T) {
// 				testing.SetRealm(std.NewUserRealm(positionAddr))
// 				CollectWithdrawalFee(0, "pkgPath", "1000", "pkgPath", "1000", "poolPath", adminAddr)
// 			},
// 			verify:      nil,
// 			expected:    "[GNOSWAP-COMMON-004] token is not registered || token(pkgPath)",
// 			shouldPanic: true,
// 		},
// 		{
// 			name: "Panic if spender has no approved balance",
// 			action: func(t *testing.T) {
// 				InitialisePoolTest(t)
// 				testing.SetRealm(std.NewUserRealm(positionAddr))
// 				poolPath := GetPoolPath(wugnotPath, gnsPath, fee3000)
// 				if !pools.Has(poolPath) {
// 					panic("pool not found")
// 				}
// 				TokenApprove(t, wugnotPath, alice, protocolFeeAddr, 0)
// 				TokenApprove(t, gnsPath, alice, protocolFeeAddr, 0)
// 				CollectWithdrawalFee(1, wugnotPath, "1000", gnsPath, "1000", poolPath, alice)
// 			},
// 			verify:      nil,
// 			expected:    "[GNOSWAP-POOL-021] token transfer failed || insufficient allowance",
// 			shouldPanic: true,
// 		},
// 		{
// 			name: "Success call by position contract",
// 			action: func(t *testing.T) {
// 				InitialisePoolTest(t)
// 				testing.SetRealm(std.NewUserRealm(alice))
// 				TokenApprove(t, wugnotPath, alice, poolAddr, 1000)
// 				TokenApprove(t, gnsPath, alice, poolAddr, 1000)
// 				cross(pn.Mint)(
// 					wugnotPath,
// 					gnsPath,
// 					fee3000,
// 					int32(1020),
// 					int32(5040),
// 					"1000",
// 					"1000",
// 					"0",
// 					"0",
// 					max_timeout,
// 					alice,
// 					alice,
// 					"",
// 				)
// 			},
// 			verify: func(t *testing.T) (string, string) {
// 				testing.SetRealm(std.NewUserRealm(alice))
// 				TokenApprove(t, wugnotPath, alice, poolAddr, 10000000000)
// 				TokenApprove(t, gnsPath, alice, poolAddr, 1000000000)
// 				testing.SetRealm(std.NewUserRealm(positionAddr))
// 				poolPath := GetPoolPath(wugnotPath, gnsPath, fee3000)
// 				return CollectWithdrawalFee(2, wugnotPath, "1000", gnsPath, "1000", poolPath, alice)
// 			},
// 			expected:    "990,990",
// 			shouldPanic: false,
// 		},
// 	}

// 	for _, tc := range tests {
// 		t.Run(tc.name, func(t *testing.T) {
// 			defer func() {
// 				r := recover()
// 				if r == nil {
// 					if tc.shouldPanic {
// 						t.Errorf(">>> %s: expected panic but got none", tc.name)
// 						return
// 					}
// 				} else {
// 					switch r.(type) {
// 					case string:
// 						if r.(string) != tc.expected {
// 							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
// 						}
// 					case error:
// 						if r.(error).Error() != tc.expected {
// 							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r.(error).Error(), tc.expected)
// 						}
// 					default:
// 						t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
// 					}
// 				}
// 			}()

// 			if !tc.shouldPanic {
// 				tc.action(t)
// 				if tc.verify != nil {
// 					gotAfterAmount0, gotAfterAmount1 := tc.verify(t)
// 					expected := strings.Split(tc.expected, ",")
// 					uassert.Equal(t, gotAfterAmount0, expected[0])
// 					uassert.Equal(t, gotAfterAmount1, expected[1])
// 				}
// 			} else {
// 				tc.action(t)
// 			}
// 		})
// 	}
// }

func TestSetWithdrawalFee(t *testing.T) {
	tests := []struct {
		name        string
		action      func(t *testing.T)
		verify      func(t *testing.T) string
		expected    string
		shouldPanic bool
	}{
		{
			name: "Panic call to set withdrawal fee setFee by non-admin (user)",
			action: func(t *testing.T) {
				const newFee = uint64(200)
				userRealm := std.NewUserRealm(alice)
				testing.SetRealm(userRealm)
				func() {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
					SetWithdrawalFee(cross, newFee)
				}()
			},
			verify:      nil,
			expected:    "caller(g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh) has no permission",
			shouldPanic: true,
		},
		{
			name: "Panic call to set withdrawal fee by admin",
			action: func(t *testing.T) {
				const newFee = uint64(200)
				adminRealm := std.NewUserRealm(adminAddr)
				testing.SetRealm(adminRealm)
				func() {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
					SetWithdrawalFee(cross, newFee)
				}()
			},
			verify:      nil,
			expected:    "caller(g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d) has no permission",
			shouldPanic: true,
		},
		{
			name: "Success call to set withdrawal fee by governance",
			action: func(t *testing.T) {
				const newFee = uint64(200)
				govRealm := std.NewUserRealm(govAddr)
				testing.SetRealm(govRealm)
				func() {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
					SetWithdrawalFee(cross, newFee)
				}()
			},
			verify: func(t *testing.T) string {
				return strconv.FormatUint(GetWithdrawalFee(), 10)
			},
			expected:    strconv.FormatUint(200, 10),
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
				tc.action(t)
				if tc.verify != nil {
					gotWithdrawalFee := tc.verify(t)
					uassert.Equal(t, gotWithdrawalFee, tc.expected)
				}
			} else {
				tc.action(t)
			}
		})
	}
}

func TestSetWithdrawalFeeByAdmin(t *testing.T) {
	tests := []struct {
		name        string
		action      func(t *testing.T)
		verify      func(t *testing.T) string
		expected    string
		shouldPanic bool
	}{
		{
			name: "Panic call to set withdrawal fee by non-admin (user)",
			action: func(t *testing.T) {
				const newFee = uint64(100)
				userRealm := std.NewUserRealm(alice)
				testing.SetRealm(userRealm)
				func() {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
					SetWithdrawalFeeByAdmin(cross, newFee)
				}()
			},
			verify:      nil,
			expected:    "caller(g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh) has no permission",
			shouldPanic: true,
		},
		{
			name: "Panic call to set withdrawal fee by non-admin (gov contract)",
			action: func(t *testing.T) {
				const newFee = uint64(100)
				govRealm := std.NewUserRealm(govAddr)
				testing.SetRealm(govRealm)
				func() {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
					SetWithdrawalFeeByAdmin(cross, newFee)
				}()
			},
			verify:      nil,
			expected:    "caller(g17s8w2ve7k85fwfnrk59lmlhthkjdted8whvqxd) has no permission",
			shouldPanic: true,
		},
		{
			name: "Success call to set withdrawal fee by admin",
			action: func(t *testing.T) {
				const newFee = uint64(100)
				adminRealm := std.NewUserRealm(adminAddr)
				testing.SetRealm(adminRealm)
				func() {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
					SetWithdrawalFeeByAdmin(cross, newFee)
				}()
			},
			verify: func(t *testing.T) string {
				return strconv.FormatUint(GetWithdrawalFee(), 10)
			},
			expected:    strconv.FormatUint(100, 10),
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
				tc.action(t)
				if tc.verify != nil {
					gotWithdrawalFee := tc.verify(t)
					uassert.Equal(t, gotWithdrawalFee, tc.expected)
				}
			} else {
				tc.action(t)
			}
		})
	}
}

func TestCalculateAmountWithFee(t *testing.T) {
	tests := []struct {
		name         string
		amount       *u256.Uint
		fee          *u256.Uint
		expectedFee  *u256.Uint
		expectedRest *u256.Uint
	}{
		{
			name:         "normal case",
			amount:       u256.NewUint(1000),
			fee:          u256.NewUint(100), // 1%
			expectedFee:  u256.NewUint(10),
			expectedRest: u256.NewUint(990),
		},
		{
			name:         "zero amount",
			amount:       u256.NewUint(0),
			fee:          u256.NewUint(100),
			expectedFee:  u256.NewUint(0),
			expectedRest: u256.NewUint(0),
		},
		{
			name:         "zero fee",
			amount:       u256.NewUint(1000),
			fee:          u256.NewUint(0),
			expectedFee:  u256.NewUint(0),
			expectedRest: u256.NewUint(1000),
		},
		{
			name:         "max fee",
			amount:       u256.NewUint(1000),
			fee:          u256.NewUint(10000), // 100%
			expectedFee:  u256.NewUint(1000),
			expectedRest: u256.NewUint(0),
		},
		{
			name:         "large amount",
			amount:       u256.MustFromDecimal("1000000000000000000"),
			fee:          u256.NewUint(100),
			expectedFee:  u256.MustFromDecimal("10000000000000000"),
			expectedRest: u256.MustFromDecimal("990000000000000000"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			feeAmount, restAmount := calculateAmountWithFee(tt.amount, tt.fee)
			uassert.Equal(t, feeAmount.ToString(), tt.expectedFee.ToString())
			uassert.Equal(t, restAmount.ToString(), tt.expectedRest.ToString())
		})
	}
}
