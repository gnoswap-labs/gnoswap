package common

import (
	"std"
)

func UserSendCoins() map[string]int64 {
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

func HasNotSupportedCoins() bool {
	userSendCoins := UserSendCoins()
	coinsCount := len(userSendCoins)

	if _, exists := userSendCoins[GNOT_DENOM]; !exists {
		return coinsCount == 1
	}

	return coinsCount == 0
}

func IsGNOTPath(path string) bool {
	return path == GNOT_PATH || path == WUGNOT_PATH
}

func IsGNOTNativePath(path string) bool {
	return path == GNOT_PATH
}

func IsGNOTWrappedPath(path string) bool {
	return path == WUGNOT_PATH
}

func IsUserSendCoins() bool {
	return len(UserSendCoins()) > 0
}

func IsUserSendGNOTAmount(amount int64) bool {
	userSendCoins := UserSendCoins()

	gnotAmount, exists := userSendCoins[GNOT_DENOM]
	if !exists {
		return amount != 0
	}

	return gnotAmount == amount
}
