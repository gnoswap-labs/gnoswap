package pool

import (
	"std"

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

// SetPoolCreationFee sets the poolCreationFee
//
// This function can only be called by the admin or governance.
//
// Panics:
//   - If the caller is not the admin or governance
func SetPoolCreationFee(fee uint64) {
	caller := std.PrevRealm().Addr()
	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR {
		panic(
			ufmt.Sprintf(
				"[POOL] protocol_fee_pool_creation.gno__SetPoolCreationFee() || only admin(%s) or governance(%s) can set pool creation fee, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_ADDR,
				caller,
			),
		)
	}

	poolCreationFee = fee

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_fee", uint64ToStr(fee),
	)
}
