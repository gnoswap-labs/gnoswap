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
		sendCoins      chain.Coins
		expectedResult bool
		description    string
	}{
		{
			name:           "no_coins_sent",
			sendCoins:      chain.Coins{},
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
			sendCoins:      chain.Coins{chain.Coin{Denom: "test_denom", Amount: 100}},
			expectedResult: true,
			description:    "Single coin should return true",
		},
		{
			name:           "single_other_coin",
			sendCoins:      chain.Coins{chain.Coin{Denom: "other_denom", Amount: 100}},
			expectedResult: true,
			description:    "Single other coin should return true",
		},
		{
			name:           "multiple_coins",
			sendCoins:      chain.Coins{chain.Coin{Denom: "test_denom", Amount: 100}, chain.Coin{Denom: "other_denom", Amount: 50}},
			expectedResult: true,
			description:    "Multiple coins should return true",
		},
		{
			name:           "zero_amount_coins",
			sendCoins:      chain.Coins{chain.Coin{Denom: "test_denom", Amount: 0}},
			expectedResult: false,
			description:    "Zero amount coins should return false (filtered out)",
		},
		{
			name:           "negative_amount_coins",
			sendCoins:      chain.Coins{chain.Coin{Denom: "test_denom", Amount: -10}},
			expectedResult: false,
			description:    "Negative amount coins should return false (filtered out)",
		},
		{
			name:           "mixed_amounts",
			sendCoins:      chain.Coins{chain.Coin{Denom: "test_denom", Amount: 100}, chain.Coin{Denom: "other_denom", Amount: 0}, chain.Coin{Denom: "third_denom", Amount: -5}},
			expectedResult: true,
			description:    "Mixed amounts with positive values should return true",
		},
		{
			name:           "positive_coin_after_non_positive_entries",
			sendCoins:      chain.Coins{chain.Coin{Denom: "zero_denom", Amount: 0}, chain.Coin{Denom: "negative_denom", Amount: -5}, chain.Coin{Denom: "test_denom", Amount: 1}},
			expectedResult: true,
			description:    "Mixed amounts with positive values should return true",
		},
		{
			name:           "duplicate_denominations_with_positive_amount",
			sendCoins:      chain.Coins{chain.Coin{Denom: "test_denom", Amount: 0}, chain.Coin{Denom: "test_denom", Amount: -5}, chain.Coin{Denom: "test_denom", Amount: 1}},
			expectedResult: true,
			description:    "Duplicate denominations should return true when any entry is positive",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetOriginSend(tt.sendCoins)

			result := ExistsUserSendCoins()

			uassert.Equal(t, result, tt.expectedResult, tt.description)
		})
	}
}
