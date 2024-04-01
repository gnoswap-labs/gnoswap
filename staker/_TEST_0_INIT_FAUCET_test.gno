package staker

import (
	"std"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/obl"
	"gno.land/r/demo/qux"

	_ "gno.land/p/demo/users"
)

func init() {
	std.TestSetPrevAddr(test1)

	// GIVE 10_000_000_000(u) ≈ 10_000
	// 10000000000
	for i := 0; i < 100; i++ {
		foo.Faucet()
		bar.Faucet()
		baz.Faucet()
		qux.Faucet()
		obl.Faucet()
		//gns.Faucet()
	}
}
