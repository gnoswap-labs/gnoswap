package common

import "chain/banker"

// IsGNOTPath checks if the given path is either native gnot or wrapped gnot path
func IsGNOTPath(path string) bool {
	return path == GNOT_DENOM || path == WUGNOT_PATH
}

// IsGNOTNativePath checks if the given path is the native gnot path
func IsGNOTNativePath(path string) bool {
	return path == GNOT_DENOM
}

// IsGNOTWrappedPath checks if the given path is the wrapped gnot path
func IsGNOTWrappedPath(path string) bool {
	return path == WUGNOT_PATH
}

// ExistsUserSendCoins checks if the user has sent any coins with the transaction
func ExistsUserSendCoins() bool {
	return len(getUserSendCoins()) > 0
}

// isUserSendGNOTAmount validates if the user sent the expected gnot amount
// Returns true in the following cases:
//   - GNOT was sent and amount matches expected
//
// Returns false in the following cases:
//   - GNOT was sent and amount does not match expected
func isUserSendGNOTAmount(amount int64) bool {
	sendCoins := getUserSendCoins()

	gnotAmount := int64(0)

	if amount, exists := sendCoins[GNOT_DENOM]; exists {
		gnotAmount = amount
	}

	return gnotAmount == amount
}

// hasUnsupportedNativeCoins checks if the user sent unsupported native coins
// Gnoswap only supports GNOT native coin, so this function detects:
// Returns true (has unsupported coins) in the following cases:
//   - Multiple coin types were sent (more than 1 coin type)
//   - Single non-GNOT coin was sent
//   - Single GNOT coin was sent but amount is zero or negative
//
// Returns false (no unsupported coins) in the following cases:
//   - No coins were sent at all
//   - Single GNOT coin was sent with positive amount
func hasUnsupportedNativeCoins() bool {
	sendCoins := getUserSendCoins()
	if len(sendCoins) == 0 {
		return false
	}

	if len(sendCoins) != 1 {
		return true
	}

	amount, ok := sendCoins[GNOT_DENOM]
	if !ok || amount <= 0 {
		return true
	}

	return false
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
