package common

func AssertIsUserSendGNOTAmount(amount int64) {
	if hasNotSupportedCoins() {
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
