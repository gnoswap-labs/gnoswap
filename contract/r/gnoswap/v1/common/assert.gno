package common

func AssertIsUserSendGNOTAmount(amount int64) {
	if hasUnsupportedNativeCoins() {
		panic(errNotSupportedCoins)
	}

	if !isUserSendGNOTAmount(amount) && amount > 0 {
		panic(errInvalidGNOTAmount)
	}
}

func AssertIsNotHandleNativeCoin() {
	if ExistsUserSendCoins() {
		panic(errNotHandleNativeCoin)
	}
}
