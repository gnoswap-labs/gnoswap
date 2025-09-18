package common

import (
	"std"
)

func IsGNOTPath(path string) bool {
	return path == GNOT_PATH || path == WUGNOT_PATH
}

func IsGNOTNativePath(path string) bool {
	return path == GNOT_PATH
}

func IsGNOTWrappedPath(path string) bool {
	return path == WUGNOT_PATH
}

func ExistsUserSendCoins() bool {
	return len(getUserSendCoins()) > 0
}

func isUserSendGNOTAmount(amount int64) bool {
	sendCoins := getUserSendCoins()

	gnotAmount, exists := sendCoins[GNOT_DENOM]
	if !exists {
		return amount != 0
	}

	return gnotAmount == amount
}

func hasNotSupportedCoins() bool {
	sendCoins := getUserSendCoins()
	coinsCount := len(sendCoins)

	if _, exists := sendCoins[GNOT_DENOM]; !exists {
		return coinsCount == 1
	}

	return coinsCount == 0
}

func getUserSendCoins() map[string]int64 {
	coinsMap := make(map[string]int64)

	for _, coin := range std.OriginSend() {
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
