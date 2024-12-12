package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/r/demo/users"

	pusers "gno.land/p/demo/users"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/consts"
)

func TestSaveProtocolFees(t *testing.T) {
	tests := []struct {
		name     string
		pool     *Pool
		amount0  *u256.Uint
		amount1  *u256.Uint
		want0    *u256.Uint
		want1    *u256.Uint
		wantFee0 *u256.Uint
		wantFee1 *u256.Uint
	}{
		{
			name: "normal fee deduction",
			pool: &Pool{
				protocolFees: ProtocolFees{
					token0: u256.NewUint(1000),
					token1: u256.NewUint(2000),
				},
			},
			amount0:  u256.NewUint(500),
			amount1:  u256.NewUint(1000),
			want0:    u256.NewUint(500),
			want1:    u256.NewUint(1000),
			wantFee0: u256.NewUint(500),
			wantFee1: u256.NewUint(1000),
		},
		{
			name: "exact fee deduction (1 deduction)",
			pool: &Pool{
				protocolFees: ProtocolFees{
					token0: u256.NewUint(1000),
					token1: u256.NewUint(2000),
				},
			},
			amount0:  u256.NewUint(1000),
			amount1:  u256.NewUint(2000),
			want0:    u256.NewUint(999),
			want1:    u256.NewUint(1999),
			wantFee0: u256.NewUint(1),
			wantFee1: u256.NewUint(1),
		},
		{
			name: "0 fee deduction",
			pool: &Pool{
				protocolFees: ProtocolFees{
					token0: u256.NewUint(1000),
					token1: u256.NewUint(2000),
				},
			},
			amount0:  u256.NewUint(0),
			amount1:  u256.NewUint(0),
			want0:    u256.NewUint(0),
			want1:    u256.NewUint(0),
			wantFee0: u256.NewUint(1000),
			wantFee1: u256.NewUint(2000),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got0, got1 := tt.pool.saveProtocolFees(tt.amount0, tt.amount1)

			uassert.Equal(t, got0.ToString(), tt.want0.ToString())
			uassert.Equal(t, got1.ToString(), tt.want1.ToString())
			uassert.Equal(t, tt.pool.protocolFees.token0.ToString(), tt.wantFee0.ToString())
			uassert.Equal(t, tt.pool.protocolFees.token1.ToString(), tt.wantFee1.ToString())
		})
	}
}

func TestTransferAndVerify(t *testing.T) {
	// Setup common test data
	pool := &Pool{
		balances: Balances{
			token0: u256.NewUint(1000),
			token1: u256.NewUint(1000),
		},
	}

	t.Run("validatePoolBalance", func(t *testing.T) {
		tests := []struct {
			name          string
			amount        *u256.Uint
			isToken0      bool
			expectedError bool
		}{
			{
				name:          "must success for negative amount",
				amount:        u256.NewUint(500),
				isToken0:      true,
				expectedError: false,
			},
			{
				name:          "must panic for insufficient token0 balance",
				amount:        u256.NewUint(1500),
				isToken0:      true,
				expectedError: true,
			},
			{
				name:          "must success for negative amount",
				amount:        u256.NewUint(500),
				isToken0:      false,
				expectedError: false,
			},
			{
				name:          "must panic for insufficient token1 balance",
				amount:        u256.NewUint(1500),
				isToken0:      false,
				expectedError: true,
			},
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				token0 := pool.balances.token0
				token1 := pool.balances.token1

				err := validatePoolBalance(token0, token1, tt.amount, tt.isToken0)
				if err != nil {
					if !tt.expectedError {
						t.Errorf("unexpected error: %v", err)
					}
				}
			})
		}
	})
}

func TestUpdatePoolBalance(t *testing.T) {
	tests := []struct {
		name          string
		initialToken0 *u256.Uint
		initialToken1 *u256.Uint
		amount        *u256.Uint
		isToken0      bool
		expectedBal   *u256.Uint
		expectErr     bool
	}{
		{
			name:          "normal token0 decrease",
			initialToken0: u256.NewUint(1000),
			initialToken1: u256.NewUint(2000),
			amount:        u256.NewUint(300),
			isToken0:      true,
			expectedBal:   u256.NewUint(700),
			expectErr:     false,
		},
		{
			name:          "normal token1 decrease",
			initialToken0: u256.NewUint(1000),
			initialToken1: u256.NewUint(2000),
			amount:        u256.NewUint(500),
			isToken0:      false,
			expectedBal:   u256.NewUint(1500),
			expectErr:     false,
		},
		{
			name:          "insufficient token0 balance",
			initialToken0: u256.NewUint(100),
			initialToken1: u256.NewUint(2000),
			amount:        u256.NewUint(200),
			isToken0:      true,
			expectedBal:   nil,
			expectErr:     true,
		},
		{
			name:          "insufficient token1 balance",
			initialToken0: u256.NewUint(1000),
			initialToken1: u256.NewUint(100),
			amount:        u256.NewUint(200),
			isToken0:      false,
			expectedBal:   nil,
			expectErr:     true,
		},
		{
			name:          "zero value handling",
			initialToken0: u256.NewUint(1000),
			initialToken1: u256.NewUint(2000),
			amount:        u256.NewUint(0),
			isToken0:      true,
			expectedBal:   u256.NewUint(1000),
			expectErr:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := &Pool{
				balances: Balances{
					token0: tt.initialToken0,
					token1: tt.initialToken1,
				},
			}

			newBal, err := updatePoolBalance(tt.initialToken0, tt.initialToken1, tt.amount, tt.isToken0)

			if tt.expectErr {
				if err == nil {
					t.Errorf("%s: expected error but no error", tt.name)
				}
				return
			}
			if err != nil {
				t.Errorf("%s: unexpected error: %v", tt.name, err)
				return
			}

			if !newBal.Eq(tt.expectedBal) {
				t.Errorf("%s: balance mismatch, expected: %s, actual: %s",
					tt.name,
					tt.expectedBal.ToString(),
					newBal.ToString(),
				)
			}
		})
	}
}

func TestShouldContinueSwap(t *testing.T) {
	tests := []struct {
		name              string
		state             SwapState
		sqrtPriceLimitX96 *u256.Uint
		expected          bool
	}{
		{
			name: "Should continue - amount remaining and price not at limit",
			state: SwapState{
				amountSpecifiedRemaining: i256.MustFromDecimal("1000"),
				sqrtPriceX96:             u256.MustFromDecimal("1000000"),
			},
			sqrtPriceLimitX96: u256.MustFromDecimal("900000"),
			expected:          true,
		},
		{
			name: "Should stop - no amount remaining",
			state: SwapState{
				amountSpecifiedRemaining: i256.Zero(),
				sqrtPriceX96:             u256.MustFromDecimal("1000000"),
			},
			sqrtPriceLimitX96: u256.MustFromDecimal("900000"),
			expected:          false,
		},
		{
			name: "Should stop - price at limit",
			state: SwapState{
				amountSpecifiedRemaining: i256.MustFromDecimal("1000"),
				sqrtPriceX96:             u256.MustFromDecimal("900000"),
			},
			sqrtPriceLimitX96: u256.MustFromDecimal("900000"),
			expected:          false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := shouldContinueSwap(tt.state, tt.sqrtPriceLimitX96)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestUpdateAmounts(t *testing.T) {
	tests := []struct {
		name          string
		step          StepComputations
		state         SwapState
		exactInput    bool
		expectedState SwapState
	}{
		{
			name: "Exact input update",
			step: StepComputations{
				amountIn:  u256.MustFromDecimal("100"),
				amountOut: u256.MustFromDecimal("97"),
				feeAmount: u256.MustFromDecimal("3"),
			},
			state: SwapState{
				amountSpecifiedRemaining: i256.MustFromDecimal("1000"),
				amountCalculated:         i256.Zero(),
			},
			exactInput: true,
			expectedState: SwapState{
				amountSpecifiedRemaining: i256.MustFromDecimal("897"), // 1000 - (100 + 3)
				amountCalculated:         i256.MustFromDecimal("-97"),
			},
		},
		{
			name: "Exact output update",
			step: StepComputations{
				amountIn:  u256.MustFromDecimal("100"),
				amountOut: u256.MustFromDecimal("97"),
				feeAmount: u256.MustFromDecimal("3"),
			},
			state: SwapState{
				amountSpecifiedRemaining: i256.MustFromDecimal("-1000"),
				amountCalculated:         i256.Zero(),
			},
			exactInput: false,
			expectedState: SwapState{
				amountSpecifiedRemaining: i256.MustFromDecimal("-903"), // -1000 + 97
				amountCalculated:         i256.MustFromDecimal("103"),  // 100 + 3
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := updateAmounts(tt.step, tt.state, tt.exactInput)

			uassert.True(t, tt.expectedState.amountSpecifiedRemaining.Eq(result.amountSpecifiedRemaining))
			uassert.True(t, tt.expectedState.amountCalculated.Eq(result.amountCalculated))
		})
	}
}

func TestComputeSwap(t *testing.T) {
	mockPool := &Pool{
		token0Path:  "token0",
		token1Path:  "token1",
		fee:         3000, // 0.3%
		tickSpacing: 60,
		slot0: Slot0{
			sqrtPriceX96: u256.MustFromDecimal("1000000000000000000"), // 1.0
			tick:         0,
			feeProtocol:  0,
			unlocked:     true,
		},
		liquidity: u256.MustFromDecimal("1000000000000000000"), // 1.0
		protocolFees: ProtocolFees{
			token0: u256.Zero(),
			token1: u256.Zero(),
		},
		feeGrowthGlobal0X128: u256.Zero(),
		feeGrowthGlobal1X128: u256.Zero(),
		tickBitmaps:          make(TickBitmaps),
		ticks:                make(Ticks),
		positions:            make(Positions),
	}

	wordPos, _ := tickBitmapPosition(0)
	// TODO: use avl
	mockPool.tickBitmaps[wordPos] = u256.NewUint(1)

	t.Run("basic swap", func(t *testing.T) {
		comp := SwapComputation{
			AmountSpecified:   i256.MustFromDecimal("1000000"),             // 1.0 token
			SqrtPriceLimitX96: u256.MustFromDecimal("1100000000000000000"), // 1.1
			ZeroForOne:        true,
			ExactInput:        true,
			InitialState: SwapState{
				amountSpecifiedRemaining: i256.MustFromDecimal("1000000"),
				amountCalculated:         i256.Zero(),
				sqrtPriceX96:             mockPool.slot0.sqrtPriceX96,
				tick:                     mockPool.slot0.tick,
				feeGrowthGlobalX128:      mockPool.feeGrowthGlobal0X128,
				protocolFee:              u256.Zero(),
				liquidity:                mockPool.liquidity,
			},
			Cache: SwapCache{
				feeProtocol:    0,
				liquidityStart: mockPool.liquidity,
			},
		}

		result, err := computeSwap(mockPool, comp)
		if err != nil {
			t.Fatalf("expected no error, got %v", err)
		}

		if result.Amount0.IsZero() {
			t.Error("expected non-zero amount0")
		}
		if result.Amount1.IsZero() {
			t.Error("expected non-zero amount1")
		}
	})

	t.Run("swap with zero liquidity", func(t *testing.T) {
		mockPoolZeroLiq := *mockPool
		mockPoolZeroLiq.liquidity = u256.Zero()

		comp := SwapComputation{
			AmountSpecified:   i256.MustFromDecimal("1000000"),
			SqrtPriceLimitX96: u256.MustFromDecimal("1100000000000000000"),
			ZeroForOne:        true,
			ExactInput:        true,
			InitialState: SwapState{
				amountSpecifiedRemaining: i256.MustFromDecimal("1000000"),
				amountCalculated:         i256.Zero(),
				sqrtPriceX96:             mockPoolZeroLiq.slot0.sqrtPriceX96,
				tick:                     mockPoolZeroLiq.slot0.tick,
				feeGrowthGlobalX128:      mockPoolZeroLiq.feeGrowthGlobal0X128,
				protocolFee:              u256.Zero(),
				liquidity:                mockPoolZeroLiq.liquidity,
			},
			Cache: SwapCache{
				feeProtocol:    0,
				liquidityStart: mockPoolZeroLiq.liquidity,
			},
		}

		result, err := computeSwap(&mockPoolZeroLiq, comp)
		if err != nil {
			t.Fatalf("expected no error, got %v", err)
		}

		if !result.Amount0.IsZero() || !result.Amount1.IsZero() {
			t.Error("expected zero amounts for zero liquidity")
		}
	})
}

func TestTransferFromAndVerify(t *testing.T) {
	tests := []struct {
		name         string
		pool         *Pool
		from         std.Address
		to           std.Address
		tokenPath    string
		amount       *i256.Int
		isToken0     bool
		expectedBal0 *u256.Uint
		expectedBal1 *u256.Uint
	}{
		{
			name: "normal token0 transfer",
			pool: &Pool{
				balances: Balances{
					token0: u256.NewUint(1000),
					token1: u256.NewUint(2000),
				},
			},
			from:         testutils.TestAddress("from_addr"),
			to:           testutils.TestAddress("to_addr"),
			tokenPath:    fooPath,
			amount:       i256.NewInt(500),
			isToken0:     true,
			expectedBal0: u256.NewUint(1500), // 1000 + 500
			expectedBal1: u256.NewUint(2000), // unchanged
		},
		{
			name: "normal token1 transfer",
			pool: &Pool{
				balances: Balances{
					token0: u256.NewUint(1000),
					token1: u256.NewUint(2000),
				},
			},
			from:         testutils.TestAddress("from_addr"),
			to:           testutils.TestAddress("to_addr"),
			tokenPath:    fooPath,
			amount:       i256.NewInt(800),
			isToken0:     false,
			expectedBal0: u256.NewUint(1000), // unchanged
			expectedBal1: u256.NewUint(2800), // 2000 + 800
		},
		{
			name: "zero value transfer",
			pool: &Pool{
				balances: Balances{
					token0: u256.NewUint(1000),
					token1: u256.NewUint(2000),
				},
			},
			from:         testutils.TestAddress("from_addr"),
			to:           testutils.TestAddress("to_addr"),
			tokenPath:    fooPath,
			amount:       i256.NewInt(0),
			isToken0:     true,
			expectedBal0: u256.NewUint(1000), // unchanged
			expectedBal1: u256.NewUint(2000), // unchanged
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			TokenFaucet(t, fooPath, pusers.AddressOrName(tt.from))
			TokenApprove(t, fooPath, pusers.AddressOrName(tt.from), pool, u256.MustFromDecimal(tt.amount.ToString()).Uint64())

			tt.pool.transferFromAndVerify(tt.from, tt.to, tt.tokenPath, u256.MustFromDecimal(tt.amount.ToString()), tt.isToken0)

			if !tt.pool.balances.token0.Eq(tt.expectedBal0) {
				t.Errorf("token0 balance mismatch: expected %s, got %s",
					tt.expectedBal0.ToString(),
					tt.pool.balances.token0.ToString())
			}

			if !tt.pool.balances.token1.Eq(tt.expectedBal1) {
				t.Errorf("token1 balance mismatch: expected %s, got %s",
					tt.expectedBal1.ToString(),
					tt.pool.balances.token1.ToString())
			}
		})
	}

	t.Run("negative value handling", func(t *testing.T) {
		pool := &Pool{
			balances: Balances{
				token0: u256.NewUint(1000),
				token1: u256.NewUint(2000),
			},
		}

		negativeAmount := i256.NewInt(-500)

		TokenFaucet(t, fooPath, pusers.AddressOrName(testutils.TestAddress("from_addr")))
		TokenApprove(t, fooPath, pusers.AddressOrName(testutils.TestAddress("from_addr")), pusers.AddressOrName(consts.POOL_ADDR), u256.MustFromDecimal(negativeAmount.Abs().ToString()).Uint64())
		pool.transferFromAndVerify(
			testutils.TestAddress("from_addr"),
			testutils.TestAddress("to_addr"),
			fooPath,
			u256.MustFromDecimal(negativeAmount.Abs().ToString()),
			true,
		)

		expectedBal := u256.NewUint(1500) // 1000 + 500 (absolute value)
		if !pool.balances.token0.Eq(expectedBal) {
			t.Errorf("negative amount handling failed: expected %s, got %s",
				expectedBal.ToString(),
				pool.balances.token0.ToString())
		}
	})

	t.Run("uint64 overflow value", func(t *testing.T) {
		pool := &Pool{
			balances: Balances{
				token0: u256.NewUint(1000),
				token1: u256.NewUint(2000),
			},
		}

		hugeAmount := i256.FromUint256(u256.MustFromDecimal("18446744073709551616")) // 2^64

		defer func() {
			if r := recover(); r == nil {
				t.Error("expected panic for amount exceeding uint64 range")
			}
		}()

		pool.transferFromAndVerify(
			testutils.TestAddress("from_addr"),
			testutils.TestAddress("to_addr"),
			fooPath,
			u256.MustFromDecimal(hugeAmount.ToString()),
			true,
		)
	})
}

func TestSwap_Failures(t *testing.T) {
	t.Skip()
	const addr = pusers.AddressOrName(consts.ROUTER_ADDR)

	tests := []struct {
		name              string
		setupFn           func(t *testing.T)
		token0Path        string
		token1Path        string
		fee               uint32
		recipient         std.Address
		zeroForOne        bool
		amountSpecified   string
		sqrtPriceLimitX96 string
		payer             std.Address
		expectedAmount0   string
		expectedAmount1   string
		expectError       bool
	}{
		{
			name: "locked pool",
			setupFn: func(t *testing.T) {
				InitialisePoolTest(t)
				pool := GetPool(wugnotPath, gnsPath, fee3000)
				pool.slot0.unlocked = false
			},
			token0Path:        wugnotPath,
			token1Path:        gnsPath,
			fee:               fee3000,
			recipient:         users.Resolve(addr),
			zeroForOne:        true,
			amountSpecified:   "100",
			sqrtPriceLimitX96: "79228162514264337593543950336",
			payer:             users.Resolve(addr),
			expectError:       true,
		},
		{
			name: "zero amount",
			setupFn: func(t *testing.T) {
				InitialisePoolTest(t)
			},
			token0Path:        wugnotPath,
			token1Path:        gnsPath,
			fee:               fee3000,
			recipient:         users.Resolve(alice),
			zeroForOne:        true,
			amountSpecified:   "0",
			sqrtPriceLimitX96: "79228162514264337593543950336",
			payer:             users.Resolve(alice),
			expectError:       true,
		},
		{
			name: "zero liquidity",
			setupFn: func(t *testing.T) {
				InitialisePoolTest(t)
				pool := GetPool(wugnotPath, gnsPath, fee3000)
				pool.liquidity = u256.Zero()
			},
			token0Path:        wugnotPath,
			token1Path:        gnsPath,
			fee:               fee3000,
			recipient:         users.Resolve(alice),
			zeroForOne:        true,
			amountSpecified:   "100",
			sqrtPriceLimitX96: "79228162514264337593543950336",
			payer:             users.Resolve(alice),
			expectedAmount0:   "0",
			expectedAmount1:   "0",
			expectError:       true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetObject(t)
			burnTokens(t)

			if tt.setupFn != nil {
				tt.setupFn(t)
			}

			std.TestSetOrigCaller(tt.payer)

			if tt.expectError {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("error should be occurred but not occurred")
					}
				}()
			}

			amount0, amount1 := Swap(
				tt.token0Path,
				tt.token1Path,
				tt.fee,
				tt.recipient,
				tt.zeroForOne,
				tt.amountSpecified,
				tt.sqrtPriceLimitX96,
				tt.payer,
			)

			if !tt.expectError {
				uassert.Equal(t, amount0, tt.expectedAmount0)
				uassert.Equal(t, amount1, tt.expectedAmount1)
			}
		})
	}
}

func TestDrySwap_Failures(t *testing.T) {
	mockPool := &Pool{
		token0Path:  "token0",
		token1Path:  "token1",
		fee:         3000,
		tickSpacing: 60,
		slot0: Slot0{
			sqrtPriceX96: u256.MustFromDecimal("1000000000000000000"), // 1.0
			tick:         0,
			feeProtocol:  0,
			unlocked:     true,
		},
		liquidity: u256.MustFromDecimal("1000000000000000000"), // 1.0
		balances: Balances{
			token0: u256.MustFromDecimal("1000000000"),
			token1: u256.MustFromDecimal("1000000000"),
		},
		protocolFees: ProtocolFees{
			token0: u256.Zero(),
			token1: u256.Zero(),
		},
		feeGrowthGlobal0X128: u256.Zero(),
		feeGrowthGlobal1X128: u256.Zero(),
		tickBitmaps:          make(TickBitmaps),
		ticks:                make(Ticks),
		positions:            make(Positions),
	}

	originalGetPool := GetPool
	defer func() {
		GetPool = originalGetPool
	}()
	GetPool = func(token0Path, token1Path string, fee uint32) *Pool {
		return mockPool
	}

	tests := []struct {
		name              string
		token0Path        string
		token1Path        string
		fee               uint32
		zeroForOne        bool
		amountSpecified   string
		sqrtPriceLimitX96 string
		expectAmount0     string
		expectAmount1     string
		expectSuccess     bool
	}{
		{
			name:              "zero amount token0 to token1",
			token0Path:        "token0",
			token1Path:        "token1",
			fee:               3000,
			zeroForOne:        true,
			amountSpecified:   "0",
			sqrtPriceLimitX96: "900000000000000000",
			expectAmount0:     "0",
			expectAmount1:     "0",
			expectSuccess:     false,
		},
		{
			name:              "insufficient balance",
			token0Path:        "token0",
			token1Path:        "token1",
			fee:               3000,
			zeroForOne:        false,
			amountSpecified:   "2000000000",
			sqrtPriceLimitX96: "1100000000000000000",
			expectAmount0:     "0",
			expectAmount1:     "0",
			expectSuccess:     false,
		},
		{
			name:              "insufficient balance token1 to token0",
			token0Path:        "token0",
			token1Path:        "token1",
			fee:               3000,
			zeroForOne:        false,
			amountSpecified:   "3000000000",
			sqrtPriceLimitX96: "1100000000000000000",
			expectAmount0:     "0",
			expectAmount1:     "0",
			expectSuccess:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			amount0, amount1, success := DrySwap(
				tt.token0Path,
				tt.token1Path,
				tt.fee,
				tt.zeroForOne,
				tt.amountSpecified,
				tt.sqrtPriceLimitX96,
			)

			uassert.Equal(t, success, tt.expectSuccess)
			uassert.Equal(t, amount0, tt.expectAmount0)
			uassert.Equal(t, amount1, tt.expectAmount1)
		})
	}
}

func TestSwapAndDrySwapComparison(t *testing.T) {
	const addr = pusers.AddressOrName(consts.ROUTER_ADDR)

	tests := []struct {
		name              string
		setupFn           func(t *testing.T)
		token0Path        string
		token1Path        string
		fee               uint32
		zeroForOne        bool
		amountSpecified   string
		sqrtPriceLimitX96 string
	}{
		{
			name: "normal swap",
			setupFn: func(t *testing.T) {
				InitialisePoolTest(t)
				TokenFaucet(t, gnsPath, addr)
				TokenApprove(t, gnsPath, addr, pool, uint64(1000))
			},
			token0Path:        wugnotPath,
			token1Path:        gnsPath,
			fee:               fee3000,
			zeroForOne:        false,
			amountSpecified:   "100",
			sqrtPriceLimitX96: "1461446703485210103287273052203988822378723970341",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetObject(t)
			burnTokens(t)

			if tt.setupFn != nil {
				tt.setupFn(t)
			}

			dryAmount0, dryAmount1, drySuccess := DrySwap(
				tt.token0Path,
				tt.token1Path,
				tt.fee,
				tt.zeroForOne,
				tt.amountSpecified,
				tt.sqrtPriceLimitX96,
			)

			std.TestSetOrigCaller(consts.ROUTER_ADDR)
			actualAmount0, actualAmount1 := Swap(
				tt.token0Path,
				tt.token1Path,
				tt.fee,
				users.Resolve(addr),
				tt.zeroForOne,
				tt.amountSpecified,
				tt.sqrtPriceLimitX96,
				users.Resolve(addr),
			)

			println("Swap", actualAmount0, actualAmount1)

			if !drySuccess {
				t.Error("DrySwap failed but actual Swap succeeded")
			}

			uassert.NotEqual(t, dryAmount0, "0", "amount0 should not be zero")
			uassert.NotEqual(t, dryAmount1, "0", "amount1 should not be zero")

			uassert.Equal(t, dryAmount0, actualAmount0,
				"Amount0 mismatch between DrySwap and actual Swap")
			uassert.Equal(t, dryAmount1, actualAmount1,
				"Amount1 mismatch between DrySwap and actual Swap")
		})
	}
}
