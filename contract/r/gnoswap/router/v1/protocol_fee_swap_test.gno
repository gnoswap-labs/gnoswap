package v1

import (
	"testing"

	"gno.land/r/onbloc/bar"
)

func TestHandleSwapFee(t *testing.T) {
	tests := []struct {
		name           string
		amount         int64
		swapFeeValue   uint64
		expectedAmount int64
	}{
		{
			name:           "zero swap fee",
			amount:         1000,
			swapFeeValue:   0,
			expectedAmount: 1000,
		},
		{
			name:           "normal swap fee calculation (0.15%)",
			amount:         10000,
			swapFeeValue:   15,
			expectedAmount: 9985, // 10000 - (10000 * 0.15%)
		},
		{
			name:           "Dry Run test",
			amount:         10000,
			swapFeeValue:   15,
			expectedAmount: 9985,
		},
		{
			name:           "large amount swap fee calculation",
			amount:         1000000,
			swapFeeValue:   15,
			expectedAmount: 998500, // 1000000 - (1000000 * 0.15%)
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := mockRouter()

			testing.SetRealm(adminRealm)
			func(cur realm) {
				router.SetSwapFee(tt.swapFeeValue)
			}(cross)

			testing.SetRealm(testing.NewUserRealm(adminAddr))
			bar.Transfer(cross, routerAddr, tt.amount)

			func(cur realm) {
				testing.SetRealm(routerRealm)
				result := router.handleSwapFee(barPath, tt.amount)

				if result != tt.expectedAmount {
					t.Errorf("handleSwapFee() = %d, want %d", result, tt.expectedAmount)
				}
			}(cross)
		})
	}
}
