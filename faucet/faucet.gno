package faucet

import (
	"std"

	"gno.land/r/demo/gns"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/qux"
)

func Faucet(addr std.Address) {
	faucetNative(addr)
	faucetGRC20(addr)
}

func faucetNative(addr std.Address) {
	banker := std.GetBanker(std.BankerTypeRealmIssue)
	banker.IssueCoin(addr, "ugnot", 100_000_000)
}

func faucetGRC20(addr std.Address) {
	gns.Faucet(addr)
	bar.Faucet(addr)
	baz.Faucet(addr)
	foo.Faucet(addr)
	qux.Faucet(addr)
}
