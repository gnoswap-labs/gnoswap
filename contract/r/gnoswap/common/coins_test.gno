package common

import (
	"chain"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

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
			name:           "single_coin",
			sendCoins:      map[string]int64{"test_denom": 100},
			expectedResult: true,
			description:    "Single coin should return true",
		},
		{
			name:           "single_other_coin",
			sendCoins:      map[string]int64{"other_denom": 100},
			expectedResult: true,
			description:    "Single other coin should return true",
		},
		{
			name:           "multiple_coins",
			sendCoins:      map[string]int64{"test_denom": 100, "other_denom": 50},
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
			sendCoins:      map[string]int64{"test_denom": 100, "other_denom": 0, "third_denom": -5},
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
				{"test_denom", 100},
			},
			expectedResult: map[string]int64{"test_denom": 100},
			description:    "Single positive coin should be included",
		},
		{
			name: "single_zero_coin",
			inputCoins: []struct {
				Denom  string
				Amount int64
			}{
				{"test_denom", 0},
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
				{"test_denom", -10},
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
				{"test_denom", 100},
				{"other_denom", 50},
			},
			expectedResult: map[string]int64{"test_denom": 100, "other_denom": 50},
			description:    "Multiple different coins should be included",
		},
		{
			name: "duplicate_denominations",
			inputCoins: []struct {
				Denom  string
				Amount int64
			}{
				{"test_denom", 100},
				{"test_denom", 50},
				{"test_denom", 25},
			},
			expectedResult: map[string]int64{"test_denom": 175},
			description:    "Duplicate denominations should be aggregated",
		},
		{
			name: "mixed_positive_zero_negative",
			inputCoins: []struct {
				Denom  string
				Amount int64
			}{
				{"test_denom", 100},
				{"zero_denom", 0},
				{"negative_denom", -10},
				{"other_denom", 50},
			},
			expectedResult: map[string]int64{"test_denom": 100, "other_denom": 50},
			description:    "Only positive amounts should be included",
		},
		{
			name: "multiple_duplicates_with_mixed_amounts",
			inputCoins: []struct {
				Denom  string
				Amount int64
			}{
				{"test_denom", 100},
				{"test_denom", 0},
				{"test_denom", -10},
				{"test_denom", 25},
				{"other_denom", 50},
				{"other_denom", 0},
			},
			expectedResult: map[string]int64{"test_denom": 125, "other_denom": 50},
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
