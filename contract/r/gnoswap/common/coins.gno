package common

import "chain/banker"

// ExistsUserSendCoins checks if the user has sent any coins with the transaction.
//
// Returns true if any coins (with positive amount) were sent with the transaction.
func ExistsUserSendCoins() bool {
	for _, coin := range banker.OriginSend() {
		if coin.Amount > 0 {
			return true
		}
	}
	return false
}
