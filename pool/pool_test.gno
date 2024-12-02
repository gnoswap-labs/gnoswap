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
