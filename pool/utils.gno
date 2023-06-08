package gnoswap

import (
	"std"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
)

func BalanceOf(token *grc20.AdminToken, addr std.Address) bigint {
	balance, err := token.BalanceOf(addr)
	if err != nil {
		panic(err)
	}
	return bigint(balance)
}

func (pool *Pool) PrintUserBalance(name string, target std.Address) {
	println(name)
	println(" ㄴToken0:", BalanceOf(pool.token0, target))
	println(" ㄴToken1:", BalanceOf(pool.token1, target))
}

func requireUnsigned(x bigint, msg string) {
	if x < 0 {
		panic(msg)
	}
}
