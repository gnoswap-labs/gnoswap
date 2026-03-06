package common

import "chain/banker"

// IsGNOTNativePath checks if the given path is the native gnot path.
//
// Parameters:
//   - path: token path to check
//
// Returns true if the path matches GNOT_DENOM ("ugnot").
func IsGNOTNativePath(path string) bool {
	return path == GNOT_DENOM
}

// ExistsUserSendCoins checks if the user has sent any coins with the transaction.
//
// Returns true if any coins (with positive amount) were sent with the transaction.
func ExistsUserSendCoins() bool {
	return len(getUserSendCoins()) > 0
}

// getUserSendCoins retrieves and aggregates all coins sent by the user in the current transaction
// Returns a map of denomination to total amount, filtering out zero or negative amounts
func getUserSendCoins() map[string]int64 {
	coinsMap := make(map[string]int64)

	for _, coin := range banker.OriginSend() {
		if coin.Amount <= 0 {
			continue
		}

		if _, exists := coinsMap[coin.Denom]; exists {
			coinsMap[coin.Denom] += coin.Amount
		} else {
			coinsMap[coin.Denom] = coin.Amount
		}
	}

	return coinsMap
}
