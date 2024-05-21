package consts

import (
	"std"
)

func GetPoolCreationFee() uint64 {
	return POOL_CREATION_FEE
}

func SetPoolCreationFee(fee uint64) {
	if std.GetOrigCaller() != GNOSWAP_ADMIN {
		panic("only admin can set pool creation fee")
	}

	POOL_CREATION_FEE = fee
}
