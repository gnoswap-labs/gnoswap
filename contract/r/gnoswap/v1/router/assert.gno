package router

import (
	"time"

	"gno.land/p/nt/ufmt"
)

// assertIsNotExpired ensures the transaction deadline has not passed.
func assertIsNotExpired(deadline int64) {
	now := time.Now().Unix()

	if now > deadline {
		panic(makeErrorWithDetails(
			errExpired,
			ufmt.Sprintf("transaction too old, now(%d) > deadline(%d)", now, deadline),
		))
	}
}
