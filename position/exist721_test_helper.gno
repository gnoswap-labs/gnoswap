package position

import (
	"std"
<<<<<<< HEAD
	"testing"
=======
>>>>>>> 4f483c7 (refactor: [GSC-69] Change position contract from type `map` to `avl.tree`)

	"gno.land/p/demo/grc/grc721"

	"gno.land/r/foo"
	"gno.land/r/bar"

	nft "gno.land/r/foo721"
)

<<<<<<< HEAD

func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, didn't expected %v", got, expected)
	}
}

func shouldGT(t *testing.T, l, r interface{}) {
	if !(l < r) {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if !(l > r) {
		t.Errorf("expected %v > %v", l, r)
	}
}


func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}

func isOwner(t *testing.T, tokenId string, addr std.Address) bool {
	owner := nft.OwnerOf(tid(tokenId))

	if owner == addr {
		return true
	}

	t.Errorf("expected owner %v, got %v", addr, owner)
	return false
}


=======
>>>>>>> 4f483c7 (refactor: [GSC-69] Change position contract from type `map` to `avl.tree`)
// Testing
func GetNextId() bigint {
	return nextId
}

func tid(tokenId string) grc721.TokenID {
	return grc721.TokenID(tokenId)
}

func PrintBal(name string, addr std.Address) {
	_addr := a2u(addr)
<<<<<<< HEAD
}


=======
	println("Name:", name)
	println("Address:", addr)
	println("> Token0 Foo: ", foo.BalanceOf(_addr))
	println("> Token1 Bar: ", bar.BalanceOf(_addr))
	println()
}

>>>>>>> 4f483c7 (refactor: [GSC-69] Change position contract from type `map` to `avl.tree`)
func Token0Bal(addr std.Address) bigint {
	return bigint(foo.BalanceOf(a2u(addr)))
}

func Token1Bal(addr std.Address) bigint {
	return bigint(bar.BalanceOf(a2u(addr)))
}