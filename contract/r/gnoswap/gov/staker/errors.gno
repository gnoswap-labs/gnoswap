package staker

import (
	"errors"
)

var (
	errCollectAmountExceedsCollectable = errors.New("amount to collect is greater than collectable amount")
	errWithdrawNotCollectable = errors.New("withdraw is not collectable")
)
