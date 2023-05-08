package gnoswap

import (
	"std"
	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
)

type MapTicks  map[string]map[string]map[int]string
type MapTickBitmap  map[string]map[string]map[int]string
type MapPositions  map[string]map[string]map[int]string


func BalanceOf(token *grc20.AdminToken, addr std.Address) bigint {
	balance, err := token.BalanceOf(addr)
	if err != nil {
		panic(err)
	}
	return bigint(balance)
}

func PrintUserBalance(token0, token1 *grc20.AdminToken, name string, target std.Address) {
	println(name)
	println(" ㄴToken0:", BalanceOf(token0, target))
	println(" ㄴToken1:", BalanceOf(token1, target))
}

func requireUnsigned(x bigint, msg string) {
	if x < 0 {
		panic(msg)
	}
}