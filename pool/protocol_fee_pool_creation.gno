package pool

import (
	"std"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	"gno.land/p/demo/ufmt"
)

// poolCreationFee is the fee that is charged when a user creates a pool.
//
// The fee is denominated in GNS tokens.
var (
	poolCreationFee = uint64(100_000_000) // 100_GNS
)

// GetPoolCreationFee returns the poolCreationFee
func GetPoolCreationFee() uint64 {
	return poolCreationFee
}

// SetPoolCreationFeeByAdmin sets the poolCreationFee.
// Panics if the caller is not the admin.
func SetPoolCreationFeeByAdmin(fee uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN {
		panic(
			ufmt.Sprintf(
				"[POOL] protocol_fee_pool_creation.gno__SetPoolCreationFeeByAdmin() || only admin(%s) can set pool creation fee, called from %s",
				consts.ADMIN,
				caller,
			),
		)
	}

	setPoolCreationFee(fee)

	prevAddr, prevRealm := common.GetPrev()
	std.Emit(
		"SetPoolCreationFeeByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"internal_fee", uint64ToStr(fee),
	)
}

// SetPoolCreationFee sets the poolCreationFee.
// Panics if the caller is not the governance contract.
func SetPoolCreationFee(fee uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GOV_GOVERNANCE_ADDR {
		panic(
			ufmt.Sprintf(
				"[POOL] protocol_fee_pool_creation.gno__SetPoolCreationFee() || only governance(%s) can set pool creation fee, called from %s",
				consts.GOV_GOVERNANCE_ADDR,
				caller,
			),
		)
	}

	setPoolCreationFee(fee)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetPoolCreationFee",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"internal_fee", uint64ToStr(fee),
	)
}

func setPoolCreationFee(fee uint64) {
	common.IsHalted()

	poolCreationFee = fee
}
