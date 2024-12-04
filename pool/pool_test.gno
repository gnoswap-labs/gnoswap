package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"
	i256 "gno.land/p/gnoswap/int256"
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
            name        string
            amount      *u256.Uint
            isToken0    bool
            expectedError bool
        }{
            {
				name: "must success for negative amount",
                amount:      u256.NewUint(500),
                isToken0:    true,
                expectedError: false,
            },
            {
				name: "must panic for insufficient token0 balance",
                amount:      u256.NewUint(1500),
                isToken0:    true,
                expectedError: true,
            },
            {
				name: "must success for negative amount",
                amount:      u256.NewUint(500),
                isToken0:    false,
                expectedError: false,
            },
            {
				name: "must panic for insufficient token1 balance",
                amount:      u256.NewUint(1500),
                isToken0:    false,
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
			name: "normal token0 decrease",
            initialToken0: u256.NewUint(1000),
            initialToken1: u256.NewUint(2000),
            amount: u256.NewUint(300),
            isToken0: true,
            expectedBal: u256.NewUint(700),
            expectErr: false,
        },
        {
			name: "normal token1 decrease",
            initialToken0: u256.NewUint(1000),
            initialToken1: u256.NewUint(2000), 
            amount: u256.NewUint(500),
            isToken0: false,
            expectedBal: u256.NewUint(1500),
            expectErr: false,
        },
        {
			name: "insufficient token0 balance",
            initialToken0: u256.NewUint(100),
            initialToken1: u256.NewUint(2000),
            amount: u256.NewUint(200),
            isToken0: true,
            expectedBal: nil,
            expectErr: true,
        },
        {
			name: "insufficient token1 balance",
            initialToken0: u256.NewUint(1000),
            initialToken1: u256.NewUint(100),
            amount: u256.NewUint(200),
            isToken0: false,
            expectedBal: nil,
            expectErr: true,
        },
        {
			name: "zero value handling",
            initialToken0: u256.NewUint(1000),
            initialToken1: u256.NewUint(2000),
            amount: u256.NewUint(0),
            isToken0: true,
            expectedBal: u256.NewUint(1000),
            expectErr: false,
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
        state            SwapState
        sqrtPriceLimitX96 *u256.Uint
        expected         bool
    }{
        {
            name: "Should continue - amount remaining and price not at limit",
            state: SwapState{
                amountSpecifiedRemaining: i256.MustFromDecimal("1000"),
                sqrtPriceX96: u256.MustFromDecimal("1000000"),
            },
            sqrtPriceLimitX96: u256.MustFromDecimal("900000"),
            expected: true,
        },
        {
            name: "Should stop - no amount remaining",
            state: SwapState{
                amountSpecifiedRemaining: i256.Zero(),
                sqrtPriceX96: u256.MustFromDecimal("1000000"),
            },
            sqrtPriceLimitX96: u256.MustFromDecimal("900000"),
            expected: false,
        },
        {
            name: "Should stop - price at limit",
            state: SwapState{
                amountSpecifiedRemaining: i256.MustFromDecimal("1000"),
                sqrtPriceX96: u256.MustFromDecimal("900000"),
            },
            sqrtPriceLimitX96: u256.MustFromDecimal("900000"),
            expected: false,
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
        name           string
        step          StepComputations
        state         SwapState
        exactInput    bool
        expectedState SwapState
    }{
        {
            name: "Exact input update",
            step: StepComputations{
                amountIn: u256.MustFromDecimal("100"),
                amountOut: u256.MustFromDecimal("97"),
                feeAmount: u256.MustFromDecimal("3"),
            },
            state: SwapState{
                amountSpecifiedRemaining: i256.MustFromDecimal("1000"),
                amountCalculated: i256.Zero(),
            },
            exactInput: true,
            expectedState: SwapState{
                amountSpecifiedRemaining: i256.MustFromDecimal("897"), // 1000 - (100 + 3)
                amountCalculated: i256.MustFromDecimal("-97"),
            },
        },
        {
            name: "Exact output update",
            step: StepComputations{
                amountIn: u256.MustFromDecimal("100"),
                amountOut: u256.MustFromDecimal("97"),
                feeAmount: u256.MustFromDecimal("3"),
            },
            state: SwapState{
                amountSpecifiedRemaining: i256.MustFromDecimal("-1000"),
                amountCalculated: i256.Zero(),
            },
            exactInput: false,
            expectedState: SwapState{
                amountSpecifiedRemaining: i256.MustFromDecimal("-903"), // -1000 + 97
                amountCalculated: i256.MustFromDecimal("103"), // 100 + 3
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
        token0Path: "token0",
        token1Path: "token1",
        fee: 3000, // 0.3%
        tickSpacing: 60,
        slot0: Slot0{
            sqrtPriceX96: u256.MustFromDecimal("1000000000000000000"), // 1.0
            tick: 0,
            feeProtocol: 0,
            unlocked: true,
        },
        liquidity: u256.MustFromDecimal("1000000000000000000"), // 1.0
        protocolFees: ProtocolFees{
            token0: u256.Zero(),
            token1: u256.Zero(),
        },
        feeGrowthGlobal0X128: u256.Zero(),
        feeGrowthGlobal1X128: u256.Zero(),
        tickBitmaps: make(TickBitmaps),
        ticks: make(Ticks),
        positions: make(Positions),
    }

    wordPos, _ := tickBitmapPosition(0)
    mockPool.tickBitmaps[wordPos] = u256.NewUint(1)

    t.Run("basic swap", func(t *testing.T) {
        comp := SwapComputation{
            AmountSpecified: i256.MustFromDecimal("1000000"), // 1.0 token
            SqrtPriceLimitX96: u256.MustFromDecimal("1100000000000000000"), // 1.1
            ZeroForOne: true,
            ExactInput: true,
            InitialState: SwapState{
                amountSpecifiedRemaining: i256.MustFromDecimal("1000000"),
                amountCalculated: i256.Zero(),
                sqrtPriceX96: mockPool.slot0.sqrtPriceX96,
                tick: mockPool.slot0.tick,
                feeGrowthGlobalX128: mockPool.feeGrowthGlobal0X128,
                protocolFee: u256.Zero(),
                liquidity: mockPool.liquidity,
            },
            Cache: SwapCache{
                feeProtocol: 0,
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
        if result.SwapFee.IsZero() {
            t.Error("expected non-zero swap fee")
        }
    })

    t.Run("swap with protocol fee", func(t *testing.T) {
        t.Skip()
        mockPoolWithFee := *mockPool
        mockPoolWithFee.slot0.feeProtocol = 4 // 4 = 1/4 of fee goes to protocol

        comp := SwapComputation{
            AmountSpecified: i256.MustFromDecimal("1000000"),
            SqrtPriceLimitX96: u256.MustFromDecimal("1100000000000000000"),
            ZeroForOne: true,
            ExactInput: true,
            InitialState: SwapState{
                amountSpecifiedRemaining: i256.MustFromDecimal("1000000"),
                amountCalculated: i256.Zero(),
                sqrtPriceX96: mockPoolWithFee.slot0.sqrtPriceX96,
                tick: mockPoolWithFee.slot0.tick,
                feeGrowthGlobalX128: mockPoolWithFee.feeGrowthGlobal0X128,
                protocolFee: u256.Zero(),
                liquidity: mockPoolWithFee.liquidity,
            },
            Cache: SwapCache{
                feeProtocol: 4,
                liquidityStart: mockPoolWithFee.liquidity,
            },
        }

        result, err := computeSwap(&mockPoolWithFee, comp)
        if err != nil {
            t.Fatalf("expected no error, got %v", err)
        }

        // 프로토콜 수수료 검증
        if mockPoolWithFee.protocolFees.token0.IsZero() {
            t.Error("expected non-zero protocol fee for token0")
        }
    })

    t.Run("swap with zero liquidity", func(t *testing.T) {
        t.Skip()
        mockPoolZeroLiq := *mockPool
        mockPoolZeroLiq.liquidity = u256.Zero()

        comp := SwapComputation{
            AmountSpecified: i256.MustFromDecimal("1000000"),
            SqrtPriceLimitX96: u256.MustFromDecimal("1100000000000000000"),
            ZeroForOne: true,
            ExactInput: true,
            InitialState: SwapState{
                amountSpecifiedRemaining: i256.MustFromDecimal("1000000"),
                amountCalculated: i256.Zero(),
                sqrtPriceX96: mockPoolZeroLiq.slot0.sqrtPriceX96,
                tick: mockPoolZeroLiq.slot0.tick,
                feeGrowthGlobalX128: mockPoolZeroLiq.feeGrowthGlobal0X128,
                protocolFee: u256.Zero(),
                liquidity: mockPoolZeroLiq.liquidity,
            },
            Cache: SwapCache{
                feeProtocol: 0,
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
