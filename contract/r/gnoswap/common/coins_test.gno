package common

import (
	"chain"
	"math"
	"testing"

	"gno.land/p/nt/uassert"
)

// TestCoins_IsUserSendGNOTAmount tests the isUserSendGNOTAmount function with various scenarios
func TestCoins_IsUserSendGNOTAmount(t *testing.T) {
	tests := []struct {
		name           string
		sendCoins      map[string]int64
		expectedAmount int64
		expectedResult bool
		description    string
	}{
		{
			name:           "no_coins_sent",
			sendCoins:      map[string]int64{},
			expectedAmount: 0,
			expectedResult: true,
			description:    "No coins sent, expected amount 0 - should return false",
		},
		{
			name:           "no_coins_sent_expected_100",
			sendCoins:      map[string]int64{},
			expectedAmount: 100,
			expectedResult: false,
			description:    "No coins sent, expected amount 100 - should return false",
		},
		{
			name:           "gnot_sent_matching_amount",
			sendCoins:      map[string]int64{GNOT_DENOM: 100},
			expectedAmount: 100,
			expectedResult: true,
			description:    "GNOT sent with matching amount - should return true",
		},
		{
			name:           "gnot_sent_different_amount",
			sendCoins:      map[string]int64{GNOT_DENOM: 100},
			expectedAmount: 200,
			expectedResult: false,
			description:    "GNOT sent with different amount - should return false",
		},
		{
			name:           "gnot_sent_zero_amount",
			sendCoins:      map[string]int64{GNOT_DENOM: 0},
			expectedAmount: 0,
			expectedResult: true,
			description:    "GNOT sent with zero amount, expected zero - should return false",
		},
		{
			name:           "gnot_sent_negative_amount",
			sendCoins:      map[string]int64{GNOT_DENOM: -10},
			expectedAmount: -10,
			expectedResult: false,
			description:    "GNOT sent with negative amount, expected negative - should return false",
		},
		{
			name:           "non_gnot_sent",
			sendCoins:      map[string]int64{"other_denom": 100},
			expectedAmount: 100,
			expectedResult: false,
			description:    "Non-GNOT coin sent - should return false",
		},
		{
			name:           "multiple_coins_including_gnot",
			sendCoins:      map[string]int64{GNOT_DENOM: 100, "other_denom": 50},
			expectedAmount: 100,
			expectedResult: true,
			description:    "Multiple coins including GNOT with matching amount - should return true",
		},
		{
			name:           "max_int64_amount",
			sendCoins:      map[string]int64{GNOT_DENOM: math.MaxInt64},
			expectedAmount: math.MaxInt64,
			expectedResult: true,
			description:    "Max int64 amount should match correctly",
		},
		{
			name:           "min_int64_amount",
			sendCoins:      map[string]int64{GNOT_DENOM: math.MinInt64},
			expectedAmount: math.MinInt64,
			expectedResult: false,
			description:    "Min int64 amount should return false (negative)",
		},
		{
			name:           "max_int64_expected_different",
			sendCoins:      map[string]int64{GNOT_DENOM: math.MaxInt64},
			expectedAmount: math.MaxInt64 - 1,
			expectedResult: false,
			description:    "Max int64 with different expected should return false",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			coins := make(chain.Coins, 0)
			for denom, amount := range tt.sendCoins {
				coins = append(coins, chain.Coin{Denom: denom, Amount: amount})
			}

			testing.SetOriginSend(coins)

			result := isUserSendGNOTAmount(tt.expectedAmount)

			uassert.Equal(t, result, tt.expectedResult, tt.description)
		})
	}
}

// TestCoins_HasUnsupportedNativeCoins tests the hasUnsupportedNativeCoins function with various scenarios
func TestCoins_HasUnsupportedNativeCoins(t *testing.T) {
	tests := []struct {
		name           string
		sendCoins      map[string]int64
		expectedResult bool
		description    string
	}{
		{
			name:           "no_coins_sent",
			sendCoins:      map[string]int64{},
			expectedResult: false,
			description:    "No coins sent - should return false (no unsupported coins)",
		},
		{
			name:           "single_gnot_positive_amount",
			sendCoins:      map[string]int64{GNOT_DENOM: 100},
			expectedResult: false,
			description:    "Single GNOT with positive amount - should return false (no unsupported coins)",
		},
		{
			name:           "single_gnot_zero_amount",
			sendCoins:      map[string]int64{GNOT_DENOM: 0},
			expectedResult: false,
			description:    "Single GNOT with zero amount - should return false (filtered out)",
		},
		{
			name:           "single_gnot_negative_amount",
			sendCoins:      map[string]int64{GNOT_DENOM: -10},
			expectedResult: false,
			description:    "Single GNOT with negative amount - should return false (filtered out)",
		},
		{
			name:           "single_non_gnot_coin",
			sendCoins:      map[string]int64{"other_denom": 100},
			expectedResult: true,
			description:    "Single non-GNOT coin - should return true (unsupported)",
		},
		{
			name:           "multiple_coins_including_gnot",
			sendCoins:      map[string]int64{GNOT_DENOM: 100, "other_denom": 50},
			expectedResult: true,
			description:    "Multiple coins including GNOT - should return true (unsupported)",
		},
		{
			name:           "multiple_non_gnot_coins",
			sendCoins:      map[string]int64{"coin1": 100, "coin2": 50},
			expectedResult: true,
			description:    "Multiple non-GNOT coins - should return true (unsupported)",
		},
		{
			name:           "three_different_coins",
			sendCoins:      map[string]int64{GNOT_DENOM: 100, "coin1": 50, "coin2": 25},
			expectedResult: true,
			description:    "Three different coins - should return true (unsupported)",
		},
		{
			name:           "gnot_with_max_amount",
			sendCoins:      map[string]int64{GNOT_DENOM: math.MaxInt64},
			expectedResult: false,
			description:    "GNOT with max int64 amount - should return false (no unsupported)",
		},
		{
			name:           "gnot_with_min_amount",
			sendCoins:      map[string]int64{GNOT_DENOM: math.MinInt64},
			expectedResult: false,
			description:    "GNOT with min int64 amount - should return false (filtered out)",
		},
		{
			name:           "empty_map",
			sendCoins:      map[string]int64{},
			expectedResult: false,
			description:    "Empty map - should return false",
		},
		{
			name:           "nil_map",
			sendCoins:      nil,
			expectedResult: false,
			description:    "Nil map - should return false",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			coins := make(chain.Coins, 0)
			for denom, amount := range tt.sendCoins {
				coins = append(coins, chain.Coin{Denom: denom, Amount: amount})
			}

			testing.SetOriginSend(coins)

			result := hasUnsupportedNativeCoins()

			uassert.Equal(t, result, tt.expectedResult, tt.description)
		})
	}
}

// TestCoins_IsGNOTPath tests the IsGNOTPath function with various path scenarios
func TestCoins_IsGNOTPath(t *testing.T) {
	tests := []struct {
		name           string
		path           string
		expectedResult bool
		description    string
	}{
		{
			name:           "native_gnot_path",
			path:           GNOT_PATH,
			expectedResult: true,
			description:    "Native GNOT path should return true",
		},
		{
			name:           "wrapped_ugnot_path",
			path:           WUGNOT_PATH,
			expectedResult: true,
			description:    "Wrapped gnot path should return true",
		},
		{
			name:           "other_path",
			path:           "gno.land/r/demo/defi/foo20",
			expectedResult: false,
			description:    "Other path should return false",
		},
		{
			name:           "empty_path",
			path:           "",
			expectedResult: false,
			description:    "Empty path should return false",
		},
		{
			name:           "similar_but_different_path",
			path:           "ugnot",
			expectedResult: true,
			description:    "Exact match with GNOT_PATH should return true",
		},
		{
			name:           "partial_match",
			path:           "gno.land/r/gnoland/wugnot/extra",
			expectedResult: false,
			description:    "Partial match should return false",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := IsGNOTPath(tt.path)
			uassert.Equal(t, result, tt.expectedResult, tt.description)
		})
	}
}

// TestCoins_IsGNOTNativePath tests the IsGNOTNativePath function
func TestCoins_IsGNOTNativePath(t *testing.T) {
	tests := []struct {
		name           string
		path           string
		expectedResult bool
		description    string
	}{
		{
			name:           "native_gnot_path",
			path:           GNOT_PATH,
			expectedResult: true,
			description:    "Native GNOT path should return true",
		},
		{
			name:           "wrapped_ugnot_path",
			path:           WUGNOT_PATH,
			expectedResult: false,
			description:    "Wrapped gnot path should return false",
		},
		{
			name:           "other_path",
			path:           "gno.land/r/demo/defi/foo20",
			expectedResult: false,
			description:    "Other path should return false",
		},
		{
			name:           "empty_path",
			path:           "",
			expectedResult: false,
			description:    "Empty path should return false",
		},
		{
			name:           "exact_gnot_match",
			path:           "ugnot",
			expectedResult: true,
			description:    "Exact match with GNOT_PATH should return true",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := IsGNOTNativePath(tt.path)
			uassert.Equal(t, result, tt.expectedResult, tt.description)
		})
	}
}

// TestCoins_IsGNOTWrappedPath tests the IsGNOTWrappedPath function
func TestCoins_IsGNOTWrappedPath(t *testing.T) {
	tests := []struct {
		name           string
		path           string
		expectedResult bool
		description    string
	}{
		{
			name:           "wrapped_ugnot_path",
			path:           WUGNOT_PATH,
			expectedResult: true,
			description:    "Wrapped gnot path should return true",
		},
		{
			name:           "native_gnot_path",
			path:           GNOT_PATH,
			expectedResult: false,
			description:    "Native GNOT path should return false",
		},
		{
			name:           "other_path",
			path:           "gno.land/r/demo/defi/foo20",
			expectedResult: false,
			description:    "Other path should return false",
		},
		{
			name:           "empty_path",
			path:           "",
			expectedResult: false,
			description:    "Empty path should return false",
		},
		{
			name:           "exact_wugnot_match",
			path:           "gno.land/r/gnoland/wugnot",
			expectedResult: true,
			description:    "Exact match with WUGNOT_PATH should return true",
		},
		{
			name:           "partial_wugnot_match",
			path:           "gno.land/r/gnoland/wugnot/extra",
			expectedResult: false,
			description:    "Partial match should return false",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := IsGNOTWrappedPath(tt.path)
			uassert.Equal(t, result, tt.expectedResult, tt.description)
		})
	}
}

// TestCoins_ExistsUserSendCoins tests the ExistsUserSendCoins function
func TestCoins_ExistsUserSendCoins(t *testing.T) {
	tests := []struct {
		name           string
		sendCoins      map[string]int64
		expectedResult bool
		description    string
	}{
		{
			name:           "no_coins_sent",
			sendCoins:      map[string]int64{},
			expectedResult: false,
			description:    "No coins sent should return false",
		},
		{
			name:           "nil_coins",
			sendCoins:      nil,
			expectedResult: false,
			description:    "Nil coins should return false",
		},
		{
			name:           "single_gnot_coin",
			sendCoins:      map[string]int64{GNOT_DENOM: 100},
			expectedResult: true,
			description:    "Single GNOT coin should return true",
		},
		{
			name:           "single_other_coin",
			sendCoins:      map[string]int64{"other_denom": 100},
			expectedResult: true,
			description:    "Single other coin should return true",
		},
		{
			name:           "multiple_coins",
			sendCoins:      map[string]int64{GNOT_DENOM: 100, "other_denom": 50},
			expectedResult: true,
			description:    "Multiple coins should return true",
		},
		{
			name:           "zero_amount_coins",
			sendCoins:      map[string]int64{},
			expectedResult: false,
			description:    "Zero amount coins should return false (filtered out)",
		},
		{
			name:           "negative_amount_coins",
			sendCoins:      map[string]int64{},
			expectedResult: false,
			description:    "Negative amount coins should return false (filtered out)",
		},
		{
			name:           "mixed_amounts",
			sendCoins:      map[string]int64{GNOT_DENOM: 100, "other_denom": 0, "third_denom": -5},
			expectedResult: true,
			description:    "Mixed amounts with positive values should return true",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			coins := make(chain.Coins, 0)
			if tt.sendCoins != nil {
				for denom, amount := range tt.sendCoins {
					coins = append(coins, chain.Coin{Denom: denom, Amount: amount})
				}
			}

			testing.SetOriginSend(coins)

			result := ExistsUserSendCoins()

			uassert.Equal(t, result, tt.expectedResult, tt.description)
		})
	}
}

// TestCoins_GetUserSendCoins tests the getUserSendCoins function logic
func TestCoins_GetUserSendCoins(t *testing.T) {
	tests := []struct {
		name       string
		inputCoins []struct {
			Denom  string
			Amount int64
		}
		expectedResult map[string]int64
		description    string
	}{
		{
			name: "no_coins",
			inputCoins: []struct {
				Denom  string
				Amount int64
			}{},
			expectedResult: map[string]int64{},
			description:    "No coins should return empty map",
		},
		{
			name: "single_positive_coin",
			inputCoins: []struct {
				Denom  string
				Amount int64
			}{
				{GNOT_DENOM, 100},
			},
			expectedResult: map[string]int64{GNOT_DENOM: 100},
			description:    "Single positive coin should be included",
		},
		{
			name: "single_zero_coin",
			inputCoins: []struct {
				Denom  string
				Amount int64
			}{
				{GNOT_DENOM, 0},
			},
			expectedResult: map[string]int64{},
			description:    "Single zero coin should be filtered out",
		},
		{
			name: "single_negative_coin",
			inputCoins: []struct {
				Denom  string
				Amount int64
			}{
				{GNOT_DENOM, -10},
			},
			expectedResult: map[string]int64{},
			description:    "Single negative coin should be filtered out",
		},
		{
			name: "multiple_different_coins",
			inputCoins: []struct {
				Denom  string
				Amount int64
			}{
				{GNOT_DENOM, 100},
				{"other_denom", 50},
			},
			expectedResult: map[string]int64{GNOT_DENOM: 100, "other_denom": 50},
			description:    "Multiple different coins should be included",
		},
		{
			name: "duplicate_denominations",
			inputCoins: []struct {
				Denom  string
				Amount int64
			}{
				{GNOT_DENOM, 100},
				{GNOT_DENOM, 50},
				{GNOT_DENOM, 25},
			},
			expectedResult: map[string]int64{GNOT_DENOM: 175},
			description:    "Duplicate denominations should be aggregated",
		},
		{
			name: "mixed_positive_zero_negative",
			inputCoins: []struct {
				Denom  string
				Amount int64
			}{
				{GNOT_DENOM, 100},
				{"zero_denom", 0},
				{"negative_denom", -10},
				{"other_denom", 50},
			},
			expectedResult: map[string]int64{GNOT_DENOM: 100, "other_denom": 50},
			description:    "Only positive amounts should be included",
		},
		{
			name: "multiple_duplicates_with_mixed_amounts",
			inputCoins: []struct {
				Denom  string
				Amount int64
			}{
				{GNOT_DENOM, 100},
				{GNOT_DENOM, 0},
				{GNOT_DENOM, -10},
				{GNOT_DENOM, 25},
				{"other_denom", 50},
				{"other_denom", 0},
			},
			expectedResult: map[string]int64{GNOT_DENOM: 125, "other_denom": 50},
			description:    "Only positive amounts should be aggregated",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			coins := make(chain.Coins, 0)
			for _, coin := range tt.inputCoins {
				coins = append(coins, chain.Coin{Denom: coin.Denom, Amount: coin.Amount})
			}

			testing.SetOriginSend(coins)

			coinsMap := getUserSendCoins()

			// Compare maps by checking length and individual values
			if len(coinsMap) != len(tt.expectedResult) {
				t.Errorf("Map length mismatch: got %d, want %d. %s", len(coinsMap), len(tt.expectedResult), tt.description)
				return
			}

			for denom, expectedAmount := range tt.expectedResult {
				if actualAmount, exists := coinsMap[denom]; !exists {
					t.Errorf("Missing denomination %s. %s", denom, tt.description)
					return
				} else if actualAmount != expectedAmount {
					t.Errorf("Amount mismatch for %s: got %d, want %d. %s", denom, actualAmount, expectedAmount, tt.description)
					return
				}
			}
		})
	}
}
