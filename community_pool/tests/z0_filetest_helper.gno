package community_pool

import (
	"std"

	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v2/consts"
	"gno.land/r/gnoswap/v2/gns"
)

type GNSToken struct{}

func (GNSToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return gns.Transfer
}

func (GNSToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return gns.TransferFrom
}

func (GNSToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return gns.BalanceOf
}

func (GNSToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return gns.Approve
}

func InitManual() {
	std.TestSetRealm(std.NewUserRealm(consts.TOKEN_REGISTER))
	RegisterGRC20Interface("gno.land/r/gnoswap/v2/gns", GNSToken{})
}
