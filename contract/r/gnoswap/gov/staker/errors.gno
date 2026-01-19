package staker

import (
	"errors"
)

var (
	ErrWithdrawNotCollectable = errors.New("withdraw is not collectable")
)
