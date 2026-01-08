package common

import (
	"chain"
	"math"
	"testing"

	"gno.land/p/nt/uassert"
)

// TestAssert_IsUserSendGNOTAmount tests the AssertIsUserSendGNOTAmount function with various scenarios
func TestAssert_IsUserSendGNOTAmount(t *testing.T) {
	tests := []struct {
		name             string
		sendCoins        map[string]int64
		expectedAmount   int64
		shouldPanic      bool
		expectedPanicMsg string
		description      string
	}{
		{
			name:             "valid_gnot_amount_matches",
			sendCoins:        map[string]int64{GNOT_DENOM: 100},
			expectedAmount:   100,
			shouldPanic:      false,
			expectedPanicMsg: "",
			description:      "Valid GNOT amount matches - should not panic",
		},
		{
			name:             "valid_gnot_amount_zero",
			sendCoins:        map[string]int64{},
			expectedAmount:   0,
			shouldPanic:      false,
			expectedPanicMsg: "",
			description:      "No coins sent, expected zero - should not panic",
		},
		{
			name:             "valid_gnot_amount_max_int64",
			sendCoins:        map[string]int64{GNOT_DENOM: math.MaxInt64},
			expectedAmount:   math.MaxInt64,
			shouldPanic:      false,
			expectedPanicMsg: "",
			description:      "Max int64 GNOT amount matches - should not panic",
		},
		{
			name:             "invalid_gnot_amount_mismatch",
			sendCoins:        map[string]int64{GNOT_DENOM: 100},
			expectedAmount:   200,
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-007] sent gnot amount does not match specified amount",
			description:      "GNOT amount mismatch - should panic with errInvalidGNOTAmount",
		},
		{
			name:             "invalid_no_coins_but_expected",
			sendCoins:        map[string]int64{},
			expectedAmount:   100,
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-007] sent gnot amount does not match specified amount",
			description:      "No coins sent but amount expected - should panic",
		},
		{
			name:             "invalid_gnot_with_negative_amount",
			sendCoins:        map[string]int64{GNOT_DENOM: -10},
			expectedAmount:   -10,
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-007] sent gnot amount does not match specified amount",
			description:      "Negative GNOT amount - should panic (filtered out)",
		},
		{
			name:             "unsupported_non_gnot_coin",
			sendCoins:        map[string]int64{"other_denom": 100},
			expectedAmount:   100,
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-006] sent coins contain unsupported coins",
			description:      "Non-GNOT coin sent - should panic with errNotSupportedCoins",
		},
		{
			name:             "unsupported_multiple_coins",
			sendCoins:        map[string]int64{GNOT_DENOM: 100, "other_denom": 50},
			expectedAmount:   100,
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-006] sent coins contain unsupported coins",
			description:      "Multiple coins sent - should panic with errNotSupportedCoins",
		},
		{
			name:             "unsupported_gnot_zero_amount",
			sendCoins:        map[string]int64{GNOT_DENOM: 0},
			expectedAmount:   100,
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-007] sent gnot amount does not match specified amount",
			description:      "GNOT with zero amount but expected non-zero - should panic",
		},
		{
			name:             "valid_large_gnot_amount",
			sendCoins:        map[string]int64{GNOT_DENOM: 1000000000000},
			expectedAmount:   1000000000000,
			shouldPanic:      false,
			expectedPanicMsg: "",
			description:      "Large GNOT amount matches - should not panic",
		},
		{
			name:             "boundary_max_int64_mismatch",
			sendCoins:        map[string]int64{GNOT_DENOM: math.MaxInt64},
			expectedAmount:   math.MaxInt64 - 1,
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-007] sent gnot amount does not match specified amount",
			description:      "Max int64 with one less expected - should panic",
		},
		{
			name:             "boundary_one_ugnot",
			sendCoins:        map[string]int64{GNOT_DENOM: 1},
			expectedAmount:   1,
			shouldPanic:      false,
			expectedPanicMsg: "",
			description:      "Minimum positive GNOT amount (1 ugnot) - should not panic",
		},
		{
			name:             "invalid_gnot_sent_expected_zero",
			sendCoins:        map[string]int64{GNOT_DENOM: 100},
			expectedAmount:   0,
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-007] sent gnot amount does not match specified amount",
			description:      "GNOT sent but expected zero - should panic",
		},
		{
			name:             "invalid_no_coins_expected_negative",
			sendCoins:        map[string]int64{},
			expectedAmount:   -100,
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-007] sent gnot amount does not match specified amount",
			description:      "No coins sent with negative expected amount - should panic",
		},
		{
			name:             "unsupported_multiple_non_gnot_coins",
			sendCoins:        map[string]int64{"atom": 50, "osmo": 30},
			expectedAmount:   100,
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-006] sent coins contain unsupported coins",
			description:      "Multiple non-GNOT coins sent - should panic with errNotSupportedCoins",
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
					AssertIsUserSendGNOTAmount(tt.expectedAmount)
				}, tt.description)
			} else {
				uassert.NotPanics(t, func() {
					AssertIsUserSendGNOTAmount(tt.expectedAmount)
				}, tt.description)
			}
		})
	}
}

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
			name:             "invalid_gnot_sent",
			sendCoins:        map[string]int64{GNOT_DENOM: 100},
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-008] handle native coin is not allowed",
			description:      "GNOT sent - should panic with errNotHandleNativeCoin",
		},
		{
			name:             "invalid_other_coin_sent",
			sendCoins:        map[string]int64{"other_denom": 100},
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-008] handle native coin is not allowed",
			description:      "Other native coin sent - should panic",
		},
		{
			name:             "invalid_multiple_coins_sent",
			sendCoins:        map[string]int64{GNOT_DENOM: 100, "other_denom": 50},
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-008] handle native coin is not allowed",
			description:      "Multiple coins sent - should panic",
		},
		{
			name:             "invalid_gnot_with_large_amount",
			sendCoins:        map[string]int64{GNOT_DENOM: math.MaxInt64},
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-008] handle native coin is not allowed",
			description:      "GNOT with max int64 amount - should panic",
		},
		{
			name:             "invalid_gnot_with_small_amount",
			sendCoins:        map[string]int64{GNOT_DENOM: 1},
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-008] handle native coin is not allowed",
			description:      "GNOT with minimal amount - should panic",
		},
		{
			name:             "valid_empty_coins_map",
			sendCoins:        map[string]int64{},
			shouldPanic:      false,
			expectedPanicMsg: "",
			description:      "Empty coins map - should not panic",
		},
		{
			name:             "invalid_zero_amount_gnot",
			sendCoins:        map[string]int64{GNOT_DENOM: 0},
			shouldPanic:      false,
			expectedPanicMsg: "",
			description:      "GNOT with zero amount - should not panic (filtered out by getUserSendCoins)",
		},
		{
			name:             "invalid_negative_amount_gnot",
			sendCoins:        map[string]int64{GNOT_DENOM: -100},
			shouldPanic:      false,
			expectedPanicMsg: "",
			description:      "GNOT with negative amount - should not panic (filtered out by getUserSendCoins)",
		},
		{
			name:             "invalid_multiple_non_gnot_coins",
			sendCoins:        map[string]int64{"atom": 50, "osmo": 30},
			shouldPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-008] handle native coin is not allowed",
			description:      "Multiple non-GNOT coins sent - should panic",
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
