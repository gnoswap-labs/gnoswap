package common

import (
	"chain"
	"testing"

	"gno.land/p/nt/uassert"
)

// TestAssert_IsNotHandleNativeCoin tests the AssertIsNotHandleNativeCoin function with various scenarios
func TestAssert_IsNotHandleNativeCoin(t *testing.T) {
	tests := []struct {
		name             string
		sendCoins        map[string]int64
		shouldPanic      bool
		expectedPanicMsg string
		description      string
	}{
		{
			name:             "valid_no_coins_sent",
			sendCoins:        map[string]int64{},
			shouldPanic:      false,
			expectedPanicMsg: "",
			description:      "No coins sent - should not panic",
		},
		{
			name:             "invalid_single_coin_sent",
			sendCoins:        map[string]int64{"test_denom": 100},
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-006] handle native coin is not allowed",
			description:      "Native coin sent - should panic",
		},
		{
			name:             "invalid_other_coin_sent",
			sendCoins:        map[string]int64{"other_denom": 100},
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-006] handle native coin is not allowed",
			description:      "Other native coin sent - should panic",
		},
		{
			name:             "invalid_multiple_coins_sent",
			sendCoins:        map[string]int64{"test_denom": 100, "other_denom": 50},
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-006] handle native coin is not allowed",
			description:      "Multiple coins sent - should panic",
		},
		{
			name:             "invalid_large_amount",
			sendCoins:        map[string]int64{"test_denom": 9223372036854775807},
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-006] handle native coin is not allowed",
			description:      "Coin with max int64 amount - should panic",
		},
		{
			name:             "invalid_small_amount",
			sendCoins:        map[string]int64{"test_denom": 1},
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-006] handle native coin is not allowed",
			description:      "Coin with minimal amount - should panic",
		},
		{
			name:             "valid_empty_coins_map",
			sendCoins:        map[string]int64{},
			shouldPanic:      false,
			expectedPanicMsg: "",
			description:      "Empty coins map - should not panic",
		},
		{
			name:             "valid_zero_amount",
			sendCoins:        map[string]int64{"test_denom": 0},
			shouldPanic:      false,
			expectedPanicMsg: "",
			description:      "Coin with zero amount - should not panic (filtered out by getUserSendCoins)",
		},
		{
			name:             "valid_negative_amount",
			sendCoins:        map[string]int64{"test_denom": -100},
			shouldPanic:      false,
			expectedPanicMsg: "",
			description:      "Coin with negative amount - should not panic (filtered out by getUserSendCoins)",
		},
		{
			name:             "invalid_multiple_different_coins",
			sendCoins:        map[string]int64{"atom": 50, "osmo": 30},
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-006] handle native coin is not allowed",
			description:      "Multiple different coins sent - should panic",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup banker environment
			coins := make(chain.Coins, 0)
			for denom, amount := range tt.sendCoins {
				coins = append(coins, chain.Coin{Denom: denom, Amount: amount})
			}
			testing.SetOriginSend(coins)

			// Test
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMsg, func() {
					AssertIsNotHandleNativeCoin()
				}, tt.description)
			} else {
				uassert.NotPanics(t, func() {
					AssertIsNotHandleNativeCoin()
				}, tt.description)
			}
		})
	}
}
