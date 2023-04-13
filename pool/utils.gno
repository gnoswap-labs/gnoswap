package gnoswap

import (
	"std"
	"gno.land/p/demo/grc/grc20"
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