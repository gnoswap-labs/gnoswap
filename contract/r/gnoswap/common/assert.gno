package common

// AssertIsNotHandleNativeCoin validates that no native coins were sent with the transaction.
//
// Use this when a function should only work with GRC20 tokens and not accept native coins.
func AssertIsNotHandleNativeCoin() {
	if err := getImplementation().ValidateNotHandleNativeCoin(); err != nil {
		panic(err)
	}
}
