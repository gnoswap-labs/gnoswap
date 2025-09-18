package common

func AssertIsUserSendGNOTAmount(amount int64) {
	if HasNotSupportedCoins() {
		panic(errNotSupportedCoins)
	}

	if !IsUserSendGNOTAmount(amount) {
		panic(errInvalidGNOTAmount)
	}
}

func AssertIsNotHandleNativeCoin() {
	if IsUserSendCoins() {
		panic(errNotHandleNativeCoin)
	}
}
