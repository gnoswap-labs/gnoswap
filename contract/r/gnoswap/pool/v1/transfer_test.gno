package v1

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	testutils "gno.land/p/nt/testutils/v0"
	pl "gno.land/r/gnoswap/pool"
)

func TestValidatePoolBalance(t *testing.T) {
	tests := []struct {
		name          string
		token0        int64
		token1        int64
		amount        int64
		isToken0      bool
		expectedError bool
	}{
		{
			name:          "successful token0 transfer",
			token0:        1000,
			token1:        1000,
			amount:        500,
			isToken0:      true,
			expectedError: false,
		},
		{
			name:          "successful token1 transfer",
			token0:        1000,
			token1:        1000,
			amount:        500,
			isToken0:      false,
			expectedError: false,
		},
		{
			name:          "insufficient token0 balance",
			token0:        100,
			token1:        1000,
			amount:        500,
			isToken0:      true,
			expectedError: true,
		},
		{
			name:          "insufficient token1 balance",
			token0:        1000,
			token1:        100,
			amount:        500,
			isToken0:      false,
			expectedError: true,
		},
		{
			name:          "negative amount",
			token0:        1000,
			token1:        1000,
			amount:        -1,
			isToken0:      true,
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validatePoolBalance(tt.token0, tt.token1, tt.amount, tt.isToken0)
			if tt.expectedError {
				if err == nil {
					t.Errorf("expected error but got none")
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
			}
		})
	}
}

func TestUpdatePoolBalance(t *testing.T) {
	tests := []struct {
		name          string
		token0        int64
		token1        int64
		amount        int64
		isToken0      bool
		expectedBal   int64
		expectedError bool
	}{
		{
			name:          "successful token0 decrease",
			token0:        1000,
			token1:        1000,
			amount:        500,
			isToken0:      true,
			expectedBal:   500,
			expectedError: false,
		},
		{
			name:          "successful token1 decrease",
			token0:        1000,
			token1:        1000,
			amount:        500,
			isToken0:      false,
			expectedBal:   500,
			expectedError: false,
		},
		{
			name:          "insufficient token0 balance",
			token0:        100,
			token1:        1000,
			amount:        500,
			isToken0:      true,
			expectedBal:   0,
			expectedError: true,
		},
		{
			name:          "insufficient token1 balance",
			token0:        1000,
			token1:        100,
			amount:        500,
			isToken0:      false,
			expectedBal:   0,
			expectedError: true,
		},
		{
			name:          "zero amount",
			token0:        1000,
			token1:        1000,
			amount:        0,
			isToken0:      true,
			expectedBal:   1000,
			expectedError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			newBal, err := updatePoolBalance(tt.token0, tt.token1, tt.amount, tt.isToken0)
			if tt.expectedError {
				if err == nil {
					t.Errorf("expected error but got none")
				}
				return
			}
			if err != nil {
				t.Errorf("unexpected error: %v", err)
				return
			}
			if newBal != tt.expectedBal {
				t.Errorf("balance mismatch: expected %d, got %d", tt.expectedBal, newBal)
			}
		})
	}
}

func TestTransferFromAndVerify(t *testing.T) {
	makeMockPoolWithBalance := func(token0 int64, token1 int64) *pl.Pool {
		mockPool := &pl.Pool{}

		balances := pl.Balances{}
		balances.SetToken0(token0)
		balances.SetToken1(token1)
		mockPool.SetBalances(balances)
		return mockPool
	}

		tests := []struct {
			name         string
			pool         *pl.Pool
		from         address
		to           address
		tokenPath    string
		amount       *i256.Int
		isToken0     bool
			expectedBal0 int64
			expectedBal1 int64
		}{
			{
				name:         "normal token0 transfer",
				pool:         makeMockPoolWithBalance(1000, 2000),
			from:         testutils.TestAddress("from_addr"),
			to:           testutils.TestAddress("to_addr"),
			tokenPath:    fooPath,
			amount:       i256.NewInt(500),
			isToken0:     true,
				expectedBal0: 1500, // 1000 + 500
				expectedBal1: 2000, // unchanged
			},
			{
				name:         "normal token1 transfer",
				pool:         makeMockPoolWithBalance(1000, 2000),
			from:         testutils.TestAddress("from_addr"),
			to:           testutils.TestAddress("to_addr"),
			tokenPath:    fooPath,
			amount:       i256.NewInt(800),
			isToken0:     false,
				expectedBal0: 1000, // unchanged
				expectedBal1: 2800, // 2000 + 800
			},
			{
				name:         "zero value transfer",
				pool:         makeMockPoolWithBalance(1000, 2000),
			from:         testutils.TestAddress("from_addr"),
			to:           testutils.TestAddress("to_addr"),
			tokenPath:    fooPath,
			amount:       i256.NewInt(0),
			isToken0:     true,
				expectedBal0: 1000, // unchanged
				expectedBal1: 2000, // unchanged
			},
		}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			TokenFaucet(t, tt.tokenPath, tt.from)
			TokenApprove(t, tt.tokenPath, tt.from, poolAddr, u256.MustFromDecimal(tt.amount.ToString()).Int64())

			mockInstanceSafeTransferFrom(tt.pool, tt.from, tt.to, tt.tokenPath, u256.MustFromDecimal(tt.amount.ToString()), tt.isToken0)

			if tt.pool.BalanceToken0() != tt.expectedBal0 {
				t.Errorf("token0 balance mismatch: expected %d, got %d",
					tt.expectedBal0,
					tt.pool.BalanceToken0())
			}

			if tt.pool.BalanceToken1() != tt.expectedBal1 {
				t.Errorf("token1 balance mismatch: expected %d, got %d",
					tt.expectedBal1,
					tt.pool.BalanceToken1())
			}
		})
	}

	t.Run("negative value handling", func(t *testing.T) {
		pool := makeMockPoolWithBalance(1000, 2000)

		negativeAmount := i256.NewInt(-500)

		TokenFaucet(t, fooPath, testutils.TestAddress("from_addr"))
		TokenApprove(t, fooPath, testutils.TestAddress("from_addr"), poolAddr, u256.MustFromDecimal(negativeAmount.Abs().ToString()).Int64())
		mockInstanceSafeTransferFrom(pool, testutils.TestAddress("from_addr"), testutils.TestAddress("to_addr"), fooPath, u256.MustFromDecimal(negativeAmount.Abs().ToString()), true)

		expectedBal := int64(1500) // 1000 + 500 (absolute value)
		if pool.BalanceToken0() != expectedBal {
			t.Errorf("negative amount handling failed: expected %d, got %d", expectedBal, pool.BalanceToken0())
		}
	})
}
