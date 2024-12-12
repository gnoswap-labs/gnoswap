package router

import (
	"testing"

	pusers "gno.land/p/demo/users"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestHandleSwapFee(t *testing.T) {
	token0 := "token0"

	mockToken := &struct {
		GRC20Interface
	}{
		GRC20Interface: MockGRC20{
			TransferFn:     func(to pusers.AddressOrName, amount uint64) {},
			TransferFromFn: func(from, to pusers.AddressOrName, amount uint64) {},
			BalanceOfFn:    func(owner pusers.AddressOrName) uint64 { return 1000000 },
			ApproveFn:      func(spender pusers.AddressOrName, amount uint64) {},
		},
	}

	registerGRC20ForTest(t, token0, mockToken)
	defer unregisterGRC20ForTest(t, token0)

	tests := []struct {
		name           string
		amount         *u256.Uint
		swapFeeValue   uint64
		expectedAmount *u256.Uint
	}{
		{
			name:           "zero swap fee",
			amount:         u256.NewUint(1000),
			swapFeeValue:   0,
			expectedAmount: u256.NewUint(1000),
		},
		{
			name:           "normal swap fee calculation (0.15%)",
			amount:         u256.NewUint(10000),
			swapFeeValue:   15,
			expectedAmount: u256.NewUint(9985), // 10000 - (10000 * 0.15%)
		},
		{
			name:           "Dry Run test",
			amount:         u256.NewUint(10000),
			swapFeeValue:   15,
			expectedAmount: u256.NewUint(9985),
		},
		{
			name:           "large amount swap fee calculation",
			amount:         u256.NewUint(1000000),
			swapFeeValue:   15,
			expectedAmount: u256.NewUint(998500), // 1000000 - (1000000 * 0.15%)
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			originalSwapFee := swapFee
			swapFee = tt.swapFeeValue
			defer func() {
				swapFee = originalSwapFee
			}()

			result := handleSwapFee(token0, tt.amount)

			if !result.Eq(tt.expectedAmount) {
				t.Errorf("handleSwapFee() = %v, want %v", result, tt.expectedAmount)
			}
		})
	}
}
