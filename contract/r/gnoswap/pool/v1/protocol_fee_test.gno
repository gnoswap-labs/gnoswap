package v1

import (
	"strconv"
	"strings"
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/gnoswap/gnsmath"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
)

func TestSetPoolCreationFee(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		action      func(cur realm)
		verify      func() string
		expected    string
		shouldPanic bool
	}{
		{
			name: "Panic call by non-governance",
			action: func(cur realm) {
				const newFee = 2_000_000_000
				testing.SetRealm(testing.NewUserRealm(alice))
				mockInstanceSetPoolCreationFee(cur, newFee)
			},
			verify:      nil,
			expected:    "unauthorized: caller g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh is not admin or governance",
			shouldPanic: true,
		},
		{
			name: "Success call by governance",
			action: func(cur realm) {
				const newFee = 2_000_000_000
				govRealm := testing.NewUserRealm(govAddr)
				testing.SetRealm(govRealm)
				mockInstanceSetPoolCreationFee(cur, newFee)
			},
			verify: func() string {
				return strconv.FormatInt(getMockInstance().GetPoolCreationFee(), 10)
			},
			expected:    strconv.FormatInt(2_000_000_000, 10),
			shouldPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			if !tc.shouldPanic {
				tc.action(cur)
				if tc.verify != nil {
					got := tc.verify()
					uassert.Equal(t, got, tc.expected)
				}
			} else {
				uassert.AbortsWithMessage(t, cur, tc.expected, func() {
					tc.action(cur)
				})
			}
		})
	}
}

func TestSetPoolCreationFeeByAdmin(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		action      func(cur realm)
		verify      func() string
		expected    string
		shouldPanic bool
	}{
		{
			name: "Panic call by non-admin (user)",
			action: func(cur realm) {
				const newFee = 2_000_000_000
				testing.SetRealm(testing.NewUserRealm(alice))
				mockInstanceSetPoolCreationFee(cur, newFee)
			},
			verify:      nil,
			expected:    "unauthorized: caller g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh is not admin or governance",
			shouldPanic: true,
		},
		{
			name: "Success call by admin",
			action: func(cur realm) {
				const newFee = 2_000_000_000
				testing.SetRealm(adminRealm)
				mockInstanceSetPoolCreationFee(cur, newFee)
			},
			verify: func() string {
				return strconv.FormatInt(getMockInstance().GetPoolCreationFee(), 10)
			},
			expected:    strconv.FormatInt(2_000_000_000, 10),
			shouldPanic: false,
		},
		{
			name: "Success call by admin (rollback)",
			action: func(cur realm) {
				const newFee = 1_000_000_000
				testing.SetRealm(adminRealm)
				mockInstanceSetPoolCreationFee(cur, newFee)
			},
			verify: func() string {
				return strconv.FormatInt(getMockInstance().GetPoolCreationFee(), 10)
			},
			expected:    strconv.FormatInt(1_000_000_000, 10),
			shouldPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			initPoolTest(t)

			if !tc.shouldPanic {
				tc.action(cur)
				if tc.verify != nil {
					got := tc.verify()
					uassert.Equal(t, got, tc.expected)
				}
			} else {
				uassert.AbortsWithMessage(t, cur, tc.expected, func() {
					tc.action(cur)
				})
			}
		})
	}
}

func TestHandleWithdrawalFee(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		action      func(cur realm, t *testing.T)
		verify      func(cur realm, t *testing.T) (string, string, string, string)
		expected    string
		shouldPanic bool
	}{
		{
			name: "Panic if caller is not position contract",
			action: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("unauthorized")))
				mockInstanceHandleWithdrawalFee(cur, "gno.land/r/onbloc/foo", "0", "gno.land/r/onbloc/foo", "0", adminAddr)
			},
			verify:      nil,
			expected:    "unauthorized: caller g1w4hxzat5dphhy6t6v4j97h6lta047h6l0wjddg is not position",
			shouldPanic: true,
		},
		{
			name: "Panic if pkgPath is not registered",
			action: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				mockInstanceHandleWithdrawalFee(cur, "pkgPath", "1000", "pkgPath", "1000", adminAddr)
			},
			verify:      nil,
			expected:    "unauthorized: caller g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 is not position",
			shouldPanic: true,
		},
		{
			name: "Success call by position contract",
			action: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				TokenApprove(cur, t, barPath, adminAddr, poolAddr, 1000)
				TokenApprove(cur, t, bazPath, adminAddr, poolAddr, 1000)

				testing.SetRealm(testing.NewUserRealm(adminAddr))
				baz.Approve(cross(cur), poolAddr, 100000000000)
				bar.Approve(cross(cur), poolAddr, 100000000000)
				gns.Approve(cross(cur), poolAddr, 100000000000)

				mockInstanceCreatePool(cur, barPath, bazPath, fee3000, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())

				testing.SetRealm(testing.NewUserRealm(adminAddr))
				bar.Transfer(cross(cur), poolAddr, 1000000000)
				baz.Transfer(cross(cur), poolAddr, 1000000000)

				testing.SetRealm(posRealm)
				mockInstanceMint(
					cur,
					barPath,
					bazPath,
					fee3000,
					int32(1020),
					int32(5040),
					"1000",
					adminAddr,
				)
			},
			verify: func(cur realm, t *testing.T) (string, string, string, string) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				TokenApprove(cur, t, barPath, adminAddr, poolAddr, 10000000000)
				TokenApprove(cur, t, bazPath, adminAddr, poolAddr, 1000000000)
				testing.SetRealm(posRealm)
				return mockInstanceHandleWithdrawalFee(cur, barPath, "1000", bazPath, "1000", adminAddr)
			},
			expected:    "10,10,990,990",
			shouldPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			initPoolTest(t)

			if tc.shouldPanic {
				uassert.AbortsWithMessage(t, cur, tc.expected, func() {
					tc.action(cur, t)
				})
			} else {
				tc.action(cur, t)
				if tc.verify != nil {
					gotFee0, gotFee1, gotAfterAmount0, gotAfterAmount1 := tc.verify(cur, t)
					expected := strings.Split(tc.expected, ",")
					uassert.Equal(t, gotFee0, expected[0])
					uassert.Equal(t, gotFee1, expected[1])
					uassert.Equal(t, gotAfterAmount0, expected[2])
					uassert.Equal(t, gotAfterAmount1, expected[3])
				}
			}
		})
	}
}

func TestHandleWithdrawalFee_ZeroFeeTransfersAll(cur realm, t *testing.T) {
	initPoolTest(t)

	testing.SetRealm(adminRealm)
	mockInstanceSetWithdrawalFee(cur, 0)
	bar.Transfer(cross(cur), poolAddr, 1000)
	baz.Transfer(cross(cur), poolAddr, 1000)

	testing.SetRealm(testing.NewCodeRealm(poolPath))
	bar.Approve(cross(cur), positionAddr, 1000)
	baz.Approve(cross(cur), positionAddr, 1000)

	barBalanceBefore := TokenBalance(t, barPath, adminAddr)
	bazBalanceBefore := TokenBalance(t, bazPath, adminAddr)

	testing.SetRealm(posRealm)
	fee0, fee1, afterAmount0, afterAmount1 := mockInstanceHandleWithdrawalFee(cur, barPath, "1000", bazPath, "1000", adminAddr)

	uassert.Equal(t, fee0, "0")
	uassert.Equal(t, fee1, "0")
	uassert.Equal(t, afterAmount0, "1000")
	uassert.Equal(t, afterAmount1, "1000")
	uassert.Equal(t, TokenBalance(t, barPath, adminAddr), barBalanceBefore+1000)
	uassert.Equal(t, TokenBalance(t, bazPath, adminAddr), bazBalanceBefore+1000)
}

func TestAddPendingProtocolFee(cur realm, t *testing.T) {
	initPoolTest(t)
	instance := getMockInstance()

	instance.addPendingProtocolFee(0, cur, barPath, 100)
	instance.addPendingProtocolFee(0, cur, barPath, 50)
	instance.addPendingProtocolFee(0, cur, gnsPath, 25)
	instance.addPendingProtocolFee(0, cur, fooPath, 0)

	pendingProtocolFees := instance.store.GetPendingProtocolFees()
	uassert.Equal(t, pendingProtocolFees[barPath], int64(150))
	uassert.Equal(t, pendingProtocolFees[gnsPath], int64(25))
	uassert.Equal(t, len(pendingProtocolFees), 2)
}

func TestAddToProtocolFeeClearsNonPositiveAmounts(cur realm, t *testing.T) {
	initPoolTest(t)
	instance := getMockInstance()
	originalPendingProtocolFees := map[string]int64{
		barPath: 0,
		gnsPath: -10,
	}
	instance.store.SetPendingProtocolFees(0, cur, originalPendingProtocolFees)

	instance.addToProtocolFee(0, cur)

	pendingProtocolFees := instance.store.GetPendingProtocolFees()
	uassert.Equal(t, len(pendingProtocolFees), 0)
	uassert.Equal(t, len(originalPendingProtocolFees), 2)
}

func TestSetWithdrawalFee(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		action      func(cur realm, t *testing.T)
		verify      func(cur realm, t *testing.T) string
		expected    string
		shouldPanic bool
	}{
		{
			name: "Panic call to set withdrawal fee setFee by non-admin (user)",
			action: func(cur realm, t *testing.T) {
				const newFee = uint64(200)
				userRealm := testing.NewUserRealm(alice)
				testing.SetRealm(userRealm)
				mockInstanceSetWithdrawalFee(cur, newFee)
			},
			verify:      nil,
			expected:    "unauthorized: caller g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh is not admin or governance",
			shouldPanic: true,
		},
		{
			name: "Success call to set withdrawal fee by admin",
			action: func(cur realm, t *testing.T) {
				const newFee = uint64(200)
				adminRealm := testing.NewUserRealm(adminAddr)
				testing.SetRealm(adminRealm)
				mockInstanceSetWithdrawalFee(cur, newFee)
			},
			expected:    strconv.FormatUint(200, 10),
			shouldPanic: false,
		},
		{
			name: "Success call to set withdrawal fee by governance",
			action: func(cur realm, t *testing.T) {
				const newFee = uint64(200)
				govRealm := testing.NewUserRealm(govAddr)
				testing.SetRealm(govRealm)
				mockInstanceSetWithdrawalFee(cur, newFee)
			},
			verify: func(cur realm, t *testing.T) string {
				return strconv.FormatUint(getMockInstance().GetWithdrawalFee(), 10)
			},
			expected:    strconv.FormatUint(200, 10),
			shouldPanic: false,
		},
		{
			name: "exceed max fee, should panic",
			action: func(cur realm, t *testing.T) {
				const newFee = uint64(MaxBpsValue + 1)
				govRealm := testing.NewUserRealm(govAddr)
				testing.SetRealm(govRealm)
				mockInstanceSetWithdrawalFee(cur, newFee)
			},
			verify:      nil,
			expected:    "must be in range 0 ~ 1000",
			shouldPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			if !tc.shouldPanic {
				tc.action(cur, t)
				if tc.verify != nil {
					gotWithdrawalFee := tc.verify(cur, t)
					uassert.Equal(t, gotWithdrawalFee, tc.expected)
				}
			} else {
				uassert.AbortsContains(t, cur, tc.expected, func() {
					tc.action(cur, t)
				})
			}
		})
	}
}

func TestCalculateAmountWithFee(cur realm, t *testing.T) {
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
			fee:          u256.NewUint(MaxBpsValue),
			expectedFee:  u256.NewUint(100),
			expectedRest: u256.NewUint(900),
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			initPoolTest(t)

			feeAmount, restAmount := calculateAmountWithFee(tt.amount, tt.fee)
			uassert.Equal(t, feeAmount.ToString(), tt.expectedFee.ToString())
			uassert.Equal(t, restAmount.ToString(), tt.expectedRest.ToString())
		})
	}
}

func TestProtocolFee(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		action      func(cur realm, t *testing.T)
		verify      func(cur realm, t *testing.T) interface{}
		expected    interface{}
		shouldPanic bool
	}{
		{
			name: "initial fee is 0",
			action: func(cur realm, t *testing.T) {
				// No action needed, just verify initial state
			},
			verify: func(cur realm, t *testing.T) interface{} {
				return getMockInstance().store.GetSlot0FeeProtocol()
			},
			expected:    uint8(0),
			shouldPanic: false,
		},
		{
			name: "create first pool with zero creation fee",
			action: func(cur realm, t *testing.T) {
				testing.SetRealm(adminRealm)
				mockInstanceSetPoolCreationFee(cur, 0)
				mockInstanceCreatePool(cur, barPath, fooPath, 3000, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
			},
			verify: func(cur realm, t *testing.T) interface{} {
				return getMockInstance().store.GetSlot0FeeProtocol()
			},
			expected:    uint8(0),
			shouldPanic: false,
		},
		{
			name: "get protocol fee from created pool",
			action: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				mockInstanceSetPoolCreationFee(cur, 0)
				mockInstanceCreatePool(cur, barPath, fooPath, 3000, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
			},
			verify: func(cur realm, t *testing.T) interface{} {
				pool := getMockInstance().mustGetPoolBy(barPath, fooPath, 3000)
				return pool.Slot0FeeProtocol()
			},
			expected:    uint8(0),
			shouldPanic: false,
		},
		{
			name: "panic when setting fee protocol with invalid values (3, 3)",
			action: func(cur realm, t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(0, cur, 3, 3)
				if err != nil {
					panic(err)
				}
			},
			verify:      nil,
			expected:    "[GNOSWAP-POOL-012] invalid protocol fee percentage",
			shouldPanic: true,
		},
		{
			name: "panic when setting fee protocol with invalid values (6, 3)",
			action: func(cur realm, t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(0, cur, 6, 3)
				if err != nil {
					panic(err)
				}
			},
			verify:      nil,
			expected:    "[GNOSWAP-POOL-012] invalid protocol fee percentage",
			shouldPanic: true,
		},
		{
			name: "panic when setting fee protocol with invalid values (3, 6)",
			action: func(cur realm, t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(0, cur, 3, 6)
				if err != nil {
					panic(err)
				}
			},
			verify:      nil,
			expected:    "[GNOSWAP-POOL-012] invalid protocol fee percentage",
			shouldPanic: true,
		},
		{
			name: "panic when setting fee protocol with invalid values (11, 11)",
			action: func(cur realm, t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(0, cur, 11, 11)
				if err != nil {
					panic(err)
				}
			},
			verify:      nil,
			expected:    "[GNOSWAP-POOL-012] invalid protocol fee percentage",
			shouldPanic: true,
		},
		{
			name: "panic when setting fee protocol with invalid values (6, 11)",
			action: func(cur realm, t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(0, cur, 6, 11)
				if err != nil {
					panic(err)
				}
			},
			verify:      nil,
			expected:    "[GNOSWAP-POOL-012] invalid protocol fee percentage",
			shouldPanic: true,
		},
		{
			name: "panic when setting fee protocol with invalid values (11, 6)",
			action: func(cur realm, t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(0, cur, 11, 6)
				if err != nil {
					panic(err)
				}
			},
			verify:      nil,
			expected:    "[GNOSWAP-POOL-012] invalid protocol fee percentage",
			shouldPanic: true,
		},
		{
			name: "set fee protocol to valid values (10, 10)",
			action: func(cur realm, t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(0, cur, 10, 10)
				if err != nil {
					panic(err)
				}
			},
			verify: func(cur realm, t *testing.T) interface{} {
				return getMockInstance().store.GetSlot0FeeProtocol()
			},
			expected:    uint8(170), // 10 + (10 << 4) = 170
			shouldPanic: false,
		},
		{
			name: "check if previous pool's protocol fee is updated",
			action: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				mockInstanceSetPoolCreationFee(cur, 0)
				getMockInstance().store.SetSlot0FeeProtocol(0, cur, 170)
				mockInstanceCreatePool(cur, barPath, fooPath, 3000, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
				// Fee already set in previous test
			},
			verify: func(cur realm, t *testing.T) interface{} {
				pool := getMockInstance().mustGetPoolBy(barPath, fooPath, 3000)
				return pool.Slot0FeeProtocol()
			},
			expected:    uint8(170),
			shouldPanic: false,
		},
		{
			name: "create second pool with updated protocol fee",
			action: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				mockInstanceSetPoolCreationFee(cur, 0)
				getMockInstance().store.SetSlot0FeeProtocol(0, cur, 170)
				mockInstanceCreatePool(cur, barPath, fooPath, 500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
			},
			verify: func(cur realm, t *testing.T) interface{} {
				pool := getMockInstance().mustGetPoolBy(barPath, fooPath, 500)
				return pool.Slot0FeeProtocol()
			},
			expected:    uint8(170),
			shouldPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			initPoolTest(t)

			if !tc.shouldPanic {
				tc.action(cur, t)
				if tc.verify != nil {
					got := tc.verify(cur, t)
					uassert.Equal(t, got, tc.expected)
				}
			} else {
				uassert.PanicsWithMessage(t, cur, tc.expected.(string), func() {
					tc.action(cur, t)
				})
			}
		})
	}
}

// TestProtocolFeesDisabledWhenNotConfigured verifies that protocol fees are not collected
// when protocol fee configuration is not enabled. This test ensures that:
//  1. A pool can be created and liquidity can be minted without protocol fees
//  2. Swaps can be performed in both directions (token0->token1 and token1->token0)
//  3. No protocol fees are accumulated when protocol fees are not configured
//  4. Position liquidity remains protected from unexpected fee deductions
func TestProtocolFeesDisabledWhenNotConfigured(cur realm, t *testing.T) {
	initPoolTest(t)

	// Create pool with initial price at tick -10000
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, getMockInstance().GetPoolCreationFee())
	mockInstanceSetPoolCreationFee(cur, 0)
	mockInstanceCreatePool(cur, barPath, fooPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(-10000).ToString())

	// Approve tokens for minting liquidity
	foo.Approve(cross(cur), poolAddr, maxApprove)
	bar.Approve(cross(cur), poolAddr, maxApprove)

	// Mint liquidity position across full tick range
	testing.SetRealm(posRealm)
	mockInstanceMint(
		cur,
		barPath,
		fooPath,
		fee500,
		-887160,
		887160,
		"100000000",
		adminAddr,
	)

	swapCallback := func(cur realm, amount0Delta int64, amount1Delta int64, _ *pl.CallbackMarker) error {
		testing.SetRealm(adminRealm)

		if amount0Delta > 0 {
			common.SafeGRC20Transfer(cross(cur), barPath, poolAddr, amount0Delta)
		}
		if amount1Delta > 0 {
			common.SafeGRC20Transfer(cross(cur), fooPath, poolAddr, amount1Delta)
		}

		return nil
	}

	// Perform swap from token0 to token1 (bar -> foo)
	testing.SetRealm(rouRealm)
	mockInstanceSwap(
		cur,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"10000",
		MIN_PRICE,
		adminAddr,
		swapCallback,
	)

	// Perform swap from token1 to token0 (foo -> bar)
	mockInstanceSwap(
		cur,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		false,
		"10000",
		MAX_PRICE,
		adminAddr,
		swapCallback,
	)

	// Verify that no protocol fees were collected since protocol fees are not enabled
	thisPool := getMockInstance().mustGetPoolBy(barPath, fooPath, fee500)
	uassert.Equal(t, thisPool.ProtocolFeesToken0(), int64(0))
	uassert.Equal(t, thisPool.ProtocolFeesToken1(), int64(0))

	resetObject(cur, t)
}
