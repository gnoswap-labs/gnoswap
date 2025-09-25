package router

import (
	"strconv"
	"time"

	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/v1/common"
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

// assertIsValidUserCoinSend asserts that the user has sent the correct amount of native coin.
func assertIsValidUserCoinSend(tokenPath, amount string) {
	amountInt, err := strconv.ParseInt(amount, 10, 64)
	if err != nil {
		panic(err)
	}

	if common.IsGNOTNativePath(tokenPath) {
		common.AssertIsUserSendGNOTAmount(amountInt)
	} else {
		common.AssertIsNotHandleNativeCoin()
	}
}

func assertIsValidRoutePaths(routePaths, inputToken, outputToken string) {
	err := validateRoutePaths(routePaths, inputToken, outputToken)
	if err != nil {
		panic(err)
	}
}
