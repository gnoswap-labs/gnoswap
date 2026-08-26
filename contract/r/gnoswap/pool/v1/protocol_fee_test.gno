package pool

import (
	"strconv"
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/gnoswap/gnsmath"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	pl "gno.land/r/gnoswap/pool"
	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	"gno.land/r/onbloc/bar"
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
				mockInstanceSetPoolCreationFee(0, cur, newFee)
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
				mockInstanceSetPoolCreationFee(0, cur, newFee)
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
				mockInstanceSetPoolCreationFee(0, cur, newFee)
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
				mockInstanceSetPoolCreationFee(0, cur, newFee)
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
				mockInstanceSetPoolCreationFee(0, cur, newFee)
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
			initPoolTest(cur, t)

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

func TestCollectAccessControl(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		action   func(cur realm, t *testing.T)
		expected string
	}{
		{
			name: "Panic if caller is not position contract",
			action: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("unauthorized")))
				mockInstanceCollectSwapFee(0, cur, barPath, bazPath, fee3000, adminAddr, int32(1020), int32(5040), "0", "0")
			},
			expected: "unauthorized: caller g1w4hxzat5dphhy6t6v4j97h6lta047h6l0wjddg is not position",
		},
		{
			name: "Panic if caller is admin rather than position contract",
			action: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				mockInstanceCollectSwapFee(0, cur, barPath, bazPath, fee3000, adminAddr, int32(1020), int32(5040), "1000", "1000")
			},
			expected: "unauthorized: caller g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 is not position",
		},
		{
			name: "Panic if caller is not position contract on the principal path",
			action: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("unauthorized")))
				mockInstanceCollect(0, cur, barPath, bazPath, fee3000, adminAddr, int32(1020), int32(5040), "0", "0")
			},
			expected: "unauthorized: caller g1w4hxzat5dphhy6t6v4j97h6lta047h6l0wjddg is not position",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			initPoolTest(cur, t)

			uassert.AbortsWithMessage(t, cur, tc.expected, func() {
				tc.action(cur, t)
			})
		})
	}
}

// TestDeductWithdrawalFee pins the fee arithmetic that CollectSwapFee applies.
// Rounding must favour the collector, and the two parts must sum back to the
// original amount so the pool never pays out more than it debited.
func TestDeductWithdrawalFee(t *testing.T) {
	tests := []struct {
		name        string
		amount      int64
		bps         uint64
		expectedFee int64
		expectedNet int64
	}{
		{name: "one percent of 1000", amount: 1000, bps: 100, expectedFee: 10, expectedNet: 990},
		{name: "zero bps keeps everything", amount: 1000, bps: ZeroBps, expectedFee: 0, expectedNet: 1000},
		{name: "zero amount", amount: 0, bps: 100, expectedFee: 0, expectedNet: 0},
		{name: "fee truncates down", amount: 99, bps: 100, expectedFee: 0, expectedNet: 99},
		{name: "max bps", amount: 1000, bps: MaxBpsValue, expectedFee: 100, expectedNet: 900},
		{name: "rounding leaves remainder with collector", amount: 12345, bps: 333, expectedFee: 411, expectedNet: 11934},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			fee, net := deductWithdrawalFee(tc.amount, tc.bps)

			uassert.Equal(t, tc.expectedFee, fee)
			uassert.Equal(t, tc.expectedNet, net)
			uassert.Equal(t, tc.amount, fee+net, "fee and net must sum back to amount")
		})
	}
}

func TestAddPendingProtocolFee(cur realm, t *testing.T) {
	initPoolTest(cur, t)
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
	initPoolTest(cur, t)
	instance := getMockInstance()
	originalPendingProtocolFees := map[string]int64{
		barPath: 0,
		gnsPath: -10,
	}
	instance.store.SetPendingProtocolFees(0, cur, originalPendingProtocolFees)

	instance.settleProtocolFee(0, cur, barPath, 0)
	instance.settleProtocolFee(0, cur, gnsPath, 0)

	pendingProtocolFees := instance.store.GetPendingProtocolFees()
	uassert.Equal(t, len(pendingProtocolFees), 0)
	uassert.Equal(t, len(originalPendingProtocolFees), 2)
}

func TestSettleProtocolFee_HaltedFeeIsSettledByLaterActivity(cur realm, t *testing.T) {
	initPoolTest(cur, t)
	instance := getMockInstance()

	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), poolAddr, 300)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)

	// Impersonate the pool realm: forwarding a fee crosses into protocol_fee, which
	// only accepts pool, position, router and staker as callers.
	testing.SetRealm(testing.NewCodeRealm(poolPath))

	// While collection is halted the fee is only recorded, not forwarded.
	protocolFeeBalanceBefore := TokenBalance(t, barPath, protocolFeeAddr)
	instance.settleProtocolFee(0, cur, barPath, 100)

	uassert.Equal(t, instance.store.GetPendingProtocolFees()[barPath], int64(100))
	uassert.Equal(t, TokenBalance(t, barPath, protocolFeeAddr), protocolFeeBalanceBefore)

	// A second fee while still halted accumulates on the same entry.
	instance.settleProtocolFee(0, cur, barPath, 50)
	uassert.Equal(t, instance.store.GetPendingProtocolFees()[barPath], int64(150))

	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
	testing.SetRealm(testing.NewCodeRealm(poolPath))

	// The next activity on that token settles the backlog together with its own fee,
	// even though every fee path also calls this with a zero amount.
	instance.settleProtocolFee(0, cur, barPath, 0)

	uassert.Equal(t, len(instance.store.GetPendingProtocolFees()), 0)
	uassert.Equal(t, TokenBalance(t, barPath, protocolFeeAddr), protocolFeeBalanceBefore+150)
}

func TestSettleProtocolFee_NoBacklogWritesNothing(cur realm, t *testing.T) {
	initPoolTest(cur, t)
	instance := getMockInstance()

	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), poolAddr, 100)
	testing.SetRealm(testing.NewCodeRealm(poolPath))

	protocolFeeBalanceBefore := TokenBalance(t, barPath, protocolFeeAddr)
	instance.settleProtocolFee(0, cur, barPath, 100)

	// The fee is forwarded without ever being staged as a pending entry.
	uassert.Equal(t, len(instance.store.GetPendingProtocolFees()), 0)
	uassert.Equal(t, TokenBalance(t, barPath, protocolFeeAddr), protocolFeeBalanceBefore+100)
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
				mockInstanceSetWithdrawalFee(0, cur, newFee)
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
				mockInstanceSetWithdrawalFee(0, cur, newFee)
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
				mockInstanceSetWithdrawalFee(0, cur, newFee)
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
				mockInstanceSetWithdrawalFee(0, cur, newFee)
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
			initPoolTest(cur, t)

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
				mockInstanceSetPoolCreationFee(0, cur, 0)
				mockInstanceCreatePool(0, cur, barPath, fooPath, 3000, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
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
				mockInstanceSetPoolCreationFee(0, cur, 0)
				mockInstanceCreatePool(0, cur, barPath, fooPath, 3000, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
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
				mockInstanceSetPoolCreationFee(0, cur, 0)
				getMockInstance().store.SetSlot0FeeProtocol(0, cur, 170)
				mockInstanceCreatePool(0, cur, barPath, fooPath, 3000, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
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
				mockInstanceSetPoolCreationFee(0, cur, 0)
				getMockInstance().store.SetSlot0FeeProtocol(0, cur, 170)
				mockInstanceCreatePool(0, cur, barPath, fooPath, 500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
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
			initPoolTest(cur, t)

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
	initPoolTest(cur, t)

	// Create pool with initial price at tick -10000
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, getMockInstance().GetPoolCreationFee())
	mockInstanceSetPoolCreationFee(0, cur, 0)
	mockInstanceCreatePool(0, cur, barPath, fooPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(-10000).ToString())

	// Approve tokens for minting liquidity
	foo.Approve(cross(cur), poolAddr, maxApprove)
	bar.Approve(cross(cur), poolAddr, maxApprove)

	// Mint liquidity position across full tick range
	testing.SetRealm(posRealm)
	mockInstanceMint(
		0, cur,
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
		0, cur,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"10000",
		MIN_PRICE,
		swapCallback,
	)

	// Perform swap from token1 to token0 (foo -> bar)
	mockInstanceSwap(
		0, cur,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		false,
		"10000",
		MAX_PRICE,
		swapCallback,
	)

	// Verify that no protocol fees were collected since protocol fees are not enabled
	thisPool := getMockInstance().mustGetPoolBy(barPath, fooPath, fee500)
	uassert.Equal(t, thisPool.ProtocolFeesToken0(), int64(0))
	uassert.Equal(t, thisPool.ProtocolFeesToken1(), int64(0))

	resetObject(cur, t)
}
