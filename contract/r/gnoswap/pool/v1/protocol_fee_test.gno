package v1

import (
	"chain"
	"strconv"
	"strings"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
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
				testing.SetRealm(testing.NewUserRealm(alice))
				mockInstanceSetPoolCreationFee(newFee)
			},
			verify:      nil,
			expected:    "unauthorized: caller g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh is not admin or governance",
			shouldPanic: true,
		},
		{
			name: "Success call by governance",
			action: func() {
				const newFee = 2_000_000_000
				govRealm := testing.NewUserRealm(govAddr)
				testing.SetRealm(govRealm)
				mockInstanceSetPoolCreationFee(newFee)
			},
			verify: func() string {
				return strconv.FormatInt(getMockInstance().GetPoolCreationFee(), 10)
			},
			expected:    strconv.FormatInt(2_000_000_000, 10),
			shouldPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if !tc.shouldPanic {
				tc.action()
				if tc.verify != nil {
					got := tc.verify()
					uassert.Equal(t, got, tc.expected)
				}
			} else {
				uassert.AbortsWithMessage(t, tc.expected, func() {
					tc.action()
				})
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
			name: "Panic call by non-admin (user)",
			action: func() {
				const newFee = 2_000_000_000
				testing.SetRealm(testing.NewUserRealm(alice))
				mockInstanceSetPoolCreationFee(newFee)
			},
			verify:      nil,
			expected:    "unauthorized: caller g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh is not admin or governance",
			shouldPanic: true,
		},
		{
			name: "Success call by admin",
			action: func() {
				const newFee = 2_000_000_000
				testing.SetRealm(adminRealm)
				mockInstanceSetPoolCreationFee(newFee)
			},
			verify: func() string {
				return strconv.FormatInt(getMockInstance().GetPoolCreationFee(), 10)
			},
			expected:    strconv.FormatInt(2_000_000_000, 10),
			shouldPanic: false,
		},
		{
			name: "Success call by admin (rollback)",
			action: func() {
				const newFee = 1_000_000_000
				testing.SetRealm(adminRealm)
				mockInstanceSetPoolCreationFee(newFee)
			},
			verify: func() string {
				return strconv.FormatInt(getMockInstance().GetPoolCreationFee(), 10)
			},
			expected:    strconv.FormatInt(1_000_000_000, 10),
			shouldPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initPoolTest(t)

			if !tc.shouldPanic {
				tc.action()
				if tc.verify != nil {
					got := tc.verify()
					uassert.Equal(t, got, tc.expected)
				}
			} else {
				uassert.AbortsWithMessage(t, tc.expected, func() {
					tc.action()
				})
			}
		})
	}
}

func TestHandleWithdrawalFee(t *testing.T) {
	tests := []struct {
		name        string
		action      func(t *testing.T)
		verify      func(t *testing.T) (string, string)
		expected    string
		shouldPanic bool
	}{
		{
			name: "Panic if caller is not position contract",
			action: func(t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("unauthorized")))
				mockInstanceHandleWithdrawalFee(0, "gno.land/r/onbloc/foo", "0", "gno.land/r/onbloc/foo", "0", "", adminAddr)
			},
			verify:      nil,
			expected:    "unauthorized: caller g1w4hxzat5dphhy6t6v4j97h6lta047h6l0wjddg is not position",
			shouldPanic: true,
		},
		{
			name: "Panic if pkgPath is not registered",
			action: func(t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				mockInstanceHandleWithdrawalFee(0, "pkgPath", "1000", "pkgPath", "1000", "poolPath", adminAddr)
			},
			verify:      nil,
			expected:    "unauthorized: caller g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 is not position",
			shouldPanic: true,
		},
		{
			name: "Success call by position contract",
			action: func(t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				TokenApprove(t, wugnotPath, adminAddr, poolAddr, 1000)
				TokenApprove(t, gnsPath, adminAddr, poolAddr, 1000)

				testing.SetRealm(testing.NewUserRealm(adminAddr))
				gns.Approve(cross, poolAddr, 100000000000)
				wugnot.Approve(cross, poolAddr, 100000000000)

				mockInstanceCreatePool(wugnotPath, gnsPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString())

				testing.SetRealm(testing.NewUserRealm(adminAddr))
				testing.SetOriginSend(chain.Coins{{"ugnot", 100000000000}})
				wugnot.Deposit(cross)
				wugnot.Transfer(cross, poolAddr, 1000000000)
				gns.Transfer(cross, poolAddr, 1000000000)

				testing.SetRealm(posRealm)
				mockInstanceMint(
					wugnotPath,
					gnsPath,
					fee3000,
					int32(1020),
					int32(5040),
					"1000",
					adminAddr,
				)
			},
			verify: func(t *testing.T) (string, string) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				TokenApprove(t, wugnotPath, adminAddr, poolAddr, 10000000000)
				TokenApprove(t, gnsPath, adminAddr, poolAddr, 1000000000)
				poolPath := GetPoolPath(wugnotPath, gnsPath, fee3000)

				testing.SetRealm(posRealm)
				return mockInstanceHandleWithdrawalFee(2, wugnotPath, "1000", gnsPath, "1000", poolPath, adminAddr)
			},
			expected:    "900,900",
			shouldPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initPoolTest(t)

			if tc.shouldPanic {
				uassert.AbortsWithMessage(t, tc.expected, func() {
					tc.action(t)
				})
			} else {
				tc.action(t)
				if tc.verify != nil {
					gotAfterAmount0, gotAfterAmount1 := tc.verify(t)
					expected := strings.Split(tc.expected, ",")
					uassert.Equal(t, gotAfterAmount0, expected[0])
					uassert.Equal(t, gotAfterAmount1, expected[1])
				}
			}
		})
	}
}

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
				userRealm := testing.NewUserRealm(alice)
				testing.SetRealm(userRealm)
				mockInstanceSetWithdrawalFee(newFee)
			},
			verify:      nil,
			expected:    "unauthorized: caller g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh is not admin or governance",
			shouldPanic: true,
		},
		{
			name: "Success call to set withdrawal fee by admin",
			action: func(t *testing.T) {
				const newFee = uint64(200)
				adminRealm := testing.NewUserRealm(adminAddr)
				testing.SetRealm(adminRealm)
				mockInstanceSetWithdrawalFee(newFee)
			},
			expected:    strconv.FormatUint(200, 10),
			shouldPanic: false,
		},
		{
			name: "Success call to set withdrawal fee by governance",
			action: func(t *testing.T) {
				const newFee = uint64(200)
				govRealm := testing.NewUserRealm(govAddr)
				testing.SetRealm(govRealm)
				mockInstanceSetWithdrawalFee(newFee)
			},
			verify: func(t *testing.T) string {
				return strconv.FormatUint(getMockInstance().GetWithdrawalFee(), 10)
			},
			expected:    strconv.FormatUint(200, 10),
			shouldPanic: false,
		},
		{
			name: "exceed max fee, should panic",
			action: func(t *testing.T) {
				const newFee = uint64(MaxBpsValue + 1)
				govRealm := testing.NewUserRealm(govAddr)
				testing.SetRealm(govRealm)
				mockInstanceSetWithdrawalFee(newFee)
			},
			verify:      nil,
			expected:    "must be in range 0 ~ 1000",
			shouldPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if !tc.shouldPanic {
				tc.action(t)
				if tc.verify != nil {
					gotWithdrawalFee := tc.verify(t)
					uassert.Equal(t, gotWithdrawalFee, tc.expected)
				}
			} else {
				uassert.AbortsContains(t, tc.expected, func() {
					tc.action(t)
				})
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
			expectedFee:  u256.NewUint(100),
			expectedRest: u256.NewUint(900),
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
			expectedFee:  u256.NewUint(1000),
			expectedRest: u256.NewUint(0),
		},
		{
			name:         "large amount",
			amount:       u256.MustFromDecimal("1000000000000000000"),
			fee:          u256.NewUint(100),
			expectedFee:  u256.MustFromDecimal("100000000000000000"),
			expectedRest: u256.MustFromDecimal("900000000000000000"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPoolTest(t)

			feeAmount, restAmount := calculateAmountWithFee(tt.amount, tt.fee)
			uassert.Equal(t, feeAmount.ToString(), tt.expectedFee.ToString())
			uassert.Equal(t, restAmount.ToString(), tt.expectedRest.ToString())
		})
	}
}

func TestProtocolFee(t *testing.T) {
	tests := []struct {
		name        string
		action      func(t *testing.T)
		verify      func(t *testing.T) interface{}
		expected    interface{}
		shouldPanic bool
	}{
		{
			name: "initial fee is 0",
			action: func(t *testing.T) {
				// No action needed, just verify initial state
			},
			verify: func(t *testing.T) interface{} {
				return getMockInstance().store.GetSlot0FeeProtocol()
			},
			expected:    uint8(0),
			shouldPanic: false,
		},
		{
			name: "create first pool with zero creation fee",
			action: func(t *testing.T) {
				testing.SetRealm(adminRealm)
				mockInstanceSetPoolCreationFee(0)
				mockInstanceCreatePool(barPath, fooPath, 3000, common.TickMathGetSqrtRatioAtTick(0).ToString())
			},
			verify: func(t *testing.T) interface{} {
				return getMockInstance().store.GetSlot0FeeProtocol()
			},
			expected:    uint8(0),
			shouldPanic: false,
		},
		{
			name: "get protocol fee from created pool",
			action: func(t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				mockInstanceSetPoolCreationFee(0)
				mockInstanceCreatePool(barPath, fooPath, 3000, common.TickMathGetSqrtRatioAtTick(0).ToString())
			},
			verify: func(t *testing.T) interface{} {
				pool := getMockInstance().mustGetPoolBy(barPath, fooPath, 3000)
				return pool.Slot0FeeProtocol()
			},
			expected:    uint8(0),
			shouldPanic: false,
		},
		{
			name: "panic when setting fee protocol with invalid values (3, 3)",
			action: func(t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(3, 3)
				if err != nil {
					panic(err)
				}
			},
			verify:      nil,
			expected:    "[GNOSWAP-POOL-016] invalid protocol fee percentage",
			shouldPanic: true,
		},
		{
			name: "panic when setting fee protocol with invalid values (6, 3)",
			action: func(t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(6, 3)
				if err != nil {
					panic(err)
				}
			},
			verify:      nil,
			expected:    "[GNOSWAP-POOL-016] invalid protocol fee percentage",
			shouldPanic: true,
		},
		{
			name: "panic when setting fee protocol with invalid values (3, 6)",
			action: func(t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(3, 6)
				if err != nil {
					panic(err)
				}
			},
			verify:      nil,
			expected:    "[GNOSWAP-POOL-016] invalid protocol fee percentage",
			shouldPanic: true,
		},
		{
			name: "panic when setting fee protocol with invalid values (11, 11)",
			action: func(t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(11, 11)
				if err != nil {
					panic(err)
				}
			},
			verify:      nil,
			expected:    "[GNOSWAP-POOL-016] invalid protocol fee percentage",
			shouldPanic: true,
		},
		{
			name: "panic when setting fee protocol with invalid values (6, 11)",
			action: func(t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(6, 11)
				if err != nil {
					panic(err)
				}
			},
			verify:      nil,
			expected:    "[GNOSWAP-POOL-016] invalid protocol fee percentage",
			shouldPanic: true,
		},
		{
			name: "panic when setting fee protocol with invalid values (11, 6)",
			action: func(t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(11, 6)
				if err != nil {
					panic(err)
				}
			},
			verify:      nil,
			expected:    "[GNOSWAP-POOL-016] invalid protocol fee percentage",
			shouldPanic: true,
		},
		{
			name: "set fee protocol to valid values (10, 10)",
			action: func(t *testing.T) {
				_, err := getMockInstance().setFeeProtocol(10, 10)
				if err != nil {
					panic(err)
				}
			},
			verify: func(t *testing.T) interface{} {
				return getMockInstance().store.GetSlot0FeeProtocol()
			},
			expected:    uint8(170), // 10 + (10 << 4) = 170
			shouldPanic: false,
		},
		{
			name: "check if previous pool's protocol fee is updated",
			action: func(t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				mockInstanceSetPoolCreationFee(0)
				getMockInstance().store.SetSlot0FeeProtocol(170)
				mockInstanceCreatePool(barPath, fooPath, 3000, common.TickMathGetSqrtRatioAtTick(0).ToString())
				// Fee already set in previous test
			},
			verify: func(t *testing.T) interface{} {
				pool := getMockInstance().mustGetPoolBy(barPath, fooPath, 3000)
				return pool.Slot0FeeProtocol()
			},
			expected:    uint8(170),
			shouldPanic: false,
		},
		{
			name: "create second pool with updated protocol fee",
			action: func(t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				mockInstanceSetPoolCreationFee(0)
				getMockInstance().store.SetSlot0FeeProtocol(170)
				mockInstanceCreatePool(barPath, fooPath, 500, common.TickMathGetSqrtRatioAtTick(0).ToString())
			},
			verify: func(t *testing.T) interface{} {
				pool := getMockInstance().mustGetPoolBy(barPath, fooPath, 500)
				return pool.Slot0FeeProtocol()
			},
			expected:    uint8(170),
			shouldPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initPoolTest(t)

			if !tc.shouldPanic {
				tc.action(t)
				if tc.verify != nil {
					got := tc.verify(t)
					uassert.Equal(t, got, tc.expected)
				}
			} else {
				uassert.PanicsWithMessage(t, tc.expected.(string), func() {
					tc.action(t)
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
func TestProtocolFeesDisabledWhenNotConfigured(t *testing.T) {
	initPoolTest(t)

	// Create pool with initial price at tick -10000
	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, getMockInstance().GetPoolCreationFee())
	mockInstanceSetPoolCreationFee(0)
	mockInstanceCreatePool(barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(-10000).ToString())

	// Approve tokens for minting liquidity
	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	// Mint liquidity position across full tick range
	testing.SetRealm(posRealm)
	mockInstanceMint(
		barPath,
		fooPath,
		fee500,
		-887160,
		887160,
		"100000000",
		adminAddr,
	)

	swapCallback := func(cur realm, amount0Delta int64, amount1Delta int64) error {
		testing.SetRealm(adminRealm)

		if amount0Delta > 0 {
			common.SafeGRC20Transfer(cross, barPath, poolAddr, amount0Delta)
		}
		if amount1Delta > 0 {
			common.SafeGRC20Transfer(cross, fooPath, poolAddr, amount1Delta)
		}

		return nil
	}

	// Perform swap from token0 to token1 (bar -> foo)
	testing.SetRealm(rouRealm)
	mockInstanceSwap(
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
	uassert.Equal(t, thisPool.ProtocolFeesToken0().ToString(), "0")
	uassert.Equal(t, thisPool.ProtocolFeesToken1().ToString(), "0")

	resetObject(t)
}
