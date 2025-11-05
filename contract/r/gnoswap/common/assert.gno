package common

func AssertIsUserSendGNOTAmount(amount int64) {
	if hasUnsupportedNativeCoins() {
		panic(errNotSupportedCoins)
	}

	if !isUserSendGNOTAmount(amount) {
		panic(errInvalidGNOTAmount)
	}
}

func AssertIsNotHandleNativeCoin() {
	if ExistsUserSendCoins() {
		panic(errNotHandleNativeCoin)
	}
}
