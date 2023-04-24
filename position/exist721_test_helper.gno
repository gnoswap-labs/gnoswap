package position

import (
	"std"
	"testing"

	"gno.land/p/demo/grc/grc721"

	"gno.land/r/bar"
	"gno.land/r/foo"

	nft "gno.land/r/foo721"
)

func GetNextId() bigint {
	return nextId
}

func tid(tokenId string) grc721.TokenID {
	return grc721.TokenID(tokenId)
}

func PrintBal(name string, addr std.Address) {
	_addr := a2u(addr)

	println("Name:", name)
	println("Address:", addr)
	println("> Token0 Foo: ", foo.BalanceOf(_addr))
	println("> Token1 Bar: ", bar.BalanceOf(_addr))
	println()
}

func Token0Bal(addr std.Address) bigint {
	return bigint(foo.BalanceOf(a2u(addr)))
}

func Token1Bal(addr std.Address) bigint {
	return bigint(bar.BalanceOf(a2u(addr)))
}

func Token1Bal(addr std.Address) bigint {
	return bigint(bar.BalanceOf(a2u(addr)))
}
