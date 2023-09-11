package pool

import (
	"std"

	"gno.land/p/demo/grc/grc20"
)

func balanceOf(token *grc20.AdminToken, addr std.Address) bigint {
	balance, err := token.BalanceOf(addr)
	if err != nil {
		panic(err)
	}
	return bigint(balance)
}

func requireUnsigned(x bigint, msg string) {
	if x < 0 {
		panic(msg)
	}
}

func min(num1, num2 bigint) bigint {
	if num1 < num2 {
		return num1
	}
	return num2
}

func require(cond bool, msg string) {
	if !cond {
		panic(msg)
	}
}

func abs(x bigint) bigint {
	if x < 0 {
		return -x
	}
	return x
}
