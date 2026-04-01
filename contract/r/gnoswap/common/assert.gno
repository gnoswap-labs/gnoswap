package common

import "chain/banker"

// AssertIsNotHandleNativeCoin validates that no native coins were sent with the transaction.
// Panics with errNotHandleNativeCoin if any native coins were sent.
//
// Use this when a function should only work with GRC20 tokens and not accept native coins.
func AssertIsNotHandleNativeCoin() {
	if len(banker.OriginSend()) > 0 {
		panic(errNotHandleNativeCoin)
	}
}
