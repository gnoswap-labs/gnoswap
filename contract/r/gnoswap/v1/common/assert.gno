package common

func AssertIsUserSendGNOTAmount(amount int64) {
	if hasNotSupportedCoins() {
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
