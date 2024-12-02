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
            shouldPanic bool
        }{
            {
				name: "must success for negative amount",
                amount:      u256.NewUint(500),
                isToken0:    true,
                shouldPanic: false,
            },
            {
				name: "must panic for insufficient token0 balance",
                amount:      u256.NewUint(1500),
                isToken0:    true,
                shouldPanic: true,
            },
            {
				name: "must success for negative amount",
                amount:      u256.NewUint(500),
                isToken0:    false,
                shouldPanic: false,
            },
            {
				name: "must panic for insufficient token1 balance",
                amount:      u256.NewUint(1500),
                isToken0:    false,
                shouldPanic: true,
            },
        }

        for _, tt := range tests {
            t.Run(tt.name, func(t *testing.T) {
                defer func() {
                    r := recover()
                    if tt.shouldPanic && r == nil {
                        t.Error("expected panic but no panic")
                    }
                    if !tt.shouldPanic && r != nil {
                        t.Errorf("unexpected panic: %v", r)
                    }
                }()
                
                pool.validatePoolBalance(tt.amount, tt.isToken0)
            })
        }
    })

    t.Run("updatePoolBalance", func(t *testing.T) {
        tests := []struct {
            name           string
            initialBalance *u256.Uint
            amount        *u256.Uint
            isToken0      bool
            expectedBalance *u256.Uint
            shouldPanic    bool
        }{
            {
				name: "must success for negative amount",
                initialBalance: u256.NewUint(1000),
                amount:        u256.NewUint(300),
                isToken0:      true,
                expectedBalance: u256.NewUint(700),
                shouldPanic:    false,
            },
            {
				name: "must panic for overflow",
                initialBalance: u256.NewUint(100),
                amount:        u256.NewUint(200),
                isToken0:      true,
                expectedBalance: nil,
                shouldPanic:    true,
            },
            {
				name: "must success for negative amount",
                initialBalance: u256.NewUint(1000),
                amount:        u256.NewUint(300),
                isToken0:      false,
                expectedBalance: u256.NewUint(700),
                shouldPanic:    false,
            },
        }

        for _, tt := range tests {
            t.Run(tt.name, func(t *testing.T) {
                testPool := &Pool{
                    balances: Balances{
                        token0: tt.initialBalance,
                        token1: tt.initialBalance,
                    },
                }

                defer func() {
                    r := recover()
                    if tt.shouldPanic && r == nil {
                        t.Error("expected panic but no panic")
                    }
                    if !tt.shouldPanic && r != nil {
                        t.Errorf("unexpected panic: %v", r)
                    }
                }()

                testPool.updatePoolBalance(tt.amount, tt.isToken0)
                if !tt.shouldPanic {
                    var actualBalance *u256.Uint
                    if tt.isToken0 {
                        actualBalance = testPool.balances.token0
                    } else {
                        actualBalance = testPool.balances.token1
                    }

                    if !actualBalance.Eq(tt.expectedBalance) {
                        t.Errorf("expected balance: %v, actual balance: %v", 
                            tt.expectedBalance.ToString(), 
                            actualBalance.ToString())
                    }
                }
            })
        }
    })
}

func TestUpdatePoolBalance(t *testing.T) {
    tests := []struct {
        name           string
        initialToken0  *u256.Uint
        initialToken1  *u256.Uint
        amount         *u256.Uint
        isToken0       bool
        expectedToken0 *u256.Uint
        expectedToken1 *u256.Uint
        shouldPanic    bool
    }{
        {
			name: "normal token0 decrease",
            initialToken0:  u256.NewUint(1000),
            initialToken1:  u256.NewUint(2000),
            amount:         u256.NewUint(300),
            isToken0:       true,
            expectedToken0: u256.NewUint(700),
            expectedToken1: u256.NewUint(2000),
            shouldPanic:    false,
        },
        {
			name: "normal token1 decrease",
            initialToken0:  u256.NewUint(1000),
            initialToken1:  u256.NewUint(2000),
            amount:         u256.NewUint(500),
            isToken0:       false,
            expectedToken0: u256.NewUint(1000),
            expectedToken1: u256.NewUint(1500),
            shouldPanic:    false,
        },
        {
			name: "insufficient token0 balance",
            initialToken0:  u256.NewUint(100),
            initialToken1:  u256.NewUint(2000),
            amount:         u256.NewUint(200),
            isToken0:       true,
            expectedToken0: nil,
            expectedToken1: nil,
            shouldPanic:    true,
        },
        {
			name: "insufficient token1 balance",
            initialToken0:  u256.NewUint(1000),
            initialToken1:  u256.NewUint(100),
            amount:         u256.NewUint(200),
            isToken0:       false,
            expectedToken0: nil,
            expectedToken1: nil,
            shouldPanic:    true,
        },
        {
			name: "0 value handling for token0",
            initialToken0:  u256.NewUint(1000),
            initialToken1:  u256.NewUint(2000),
            amount:         u256.NewUint(0),
            isToken0:       true,
            expectedToken0: u256.NewUint(1000),
            expectedToken1: u256.NewUint(2000),
            shouldPanic:    false,
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

            defer func() {
                r := recover()
                if tt.shouldPanic && r == nil {
                    t.Error("expected panic but no panic")
                }
                if !tt.shouldPanic && r != nil {
                    t.Errorf("unexpected panic: %v", r)
                }
            }()

            pool.updatePoolBalance(tt.amount, tt.isToken0)

            if !tt.shouldPanic {
                if !pool.balances.token0.Eq(tt.expectedToken0) {
                    t.Errorf("token0 balance mismatch. expected: %s, actual: %s",
                        tt.expectedToken0.ToString(),
                        pool.balances.token0.ToString())
                }
                if !pool.balances.token1.Eq(tt.expectedToken1) {
                    t.Errorf("token1 balance mismatch. expected: %s, actual: %s",
                        tt.expectedToken1.ToString(),
                        pool.balances.token1.ToString())
                }
            }
        })
    }
}
