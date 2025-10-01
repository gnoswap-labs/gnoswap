package common

import "chain/banker"

// IsGNOTPath checks if the given path is either native gnot or wrapped ugnot path
func IsGNOTPath(path string) bool {
	return path == GNOT_PATH || path == WUGNOT_PATH
}

// IsGNOTNativePath checks if the given path is the native gnot path
func IsGNOTNativePath(path string) bool {
	return path == GNOT_PATH
}

// IsGNOTWrappedPath checks if the given path is the wrapped ugnot path
func IsGNOTWrappedPath(path string) bool {
	return path == WUGNOT_PATH
}

// ExistsUserSendCoins checks if the user has sent any coins with the transaction
func ExistsUserSendCoins() bool {
	return len(getUserSendCoins()) > 0
}

// isUserSendGNOTAmount validates if the user sent the expected gnot amount
// Returns true if no gnot was sent and amount is non-zero, or if sent amount matches expected amount
func isUserSendGNOTAmount(amount int64) bool {
	sendCoins := getUserSendCoins()

	gnotAmount, exists := sendCoins[GNOT_DENOM]
	if !exists {
		return false
	}

	return gnotAmount == amount
}

// hasNotSupportedCoins checks if the user sent unsupported coins
// Returns true if non-gnot coins were sent or if no coins were sent at all
func hasNotSupportedCoins() bool {
	sendCoins := getUserSendCoins()
	coinsCount := len(sendCoins)

	if _, exists := sendCoins[GNOT_DENOM]; !exists {
		return coinsCount == 1
	}

	return coinsCount == 0
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
