package common

// AssertIsUserSendGNOTAmount validates that the user sent the expected GNOT amount.
// Panics with errNotSupportedCoins if unsupported native coins were sent.
// Panics with errInvalidGNOTAmount if the GNOT amount doesn't match the expected amount.
//
// Parameters:
//   - amount: expected GNOT amount in ugnot
//
// Use this when a function requires native GNOT payment.
func AssertIsUserSendGNOTAmount(amount int64) {
	if hasUnsupportedNativeCoins() {
		panic(errNotSupportedCoins)
	}

	if !isUserSendGNOTAmount(amount) {
		panic(errInvalidGNOTAmount)
	}
}

// AssertIsNotHandleNativeCoin validates that no native coins were sent with the transaction.
// Panics with errNotHandleNativeCoin if any native coins were sent.
//
// Use this when a function should only work with GRC20 tokens and not accept native coins.
func AssertIsNotHandleNativeCoin() {
	if ExistsUserSendCoins() {
		panic(errNotHandleNativeCoin)
	}
}
