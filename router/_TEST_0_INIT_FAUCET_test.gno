package router

import (
	"std"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/obl"
	"gno.land/r/demo/qux"
)

func init() {
	std.TestSetPrevAddr(test1)

	// GIVE 100_000_000_000(u( ≈ 100_000
	for i := 0; i < 100; i++ {
		foo.Faucet()
		bar.Faucet()
		baz.Faucet()
		qux.Faucet()
		obl.Faucet()
		//gns.Faucet()
	}
}
