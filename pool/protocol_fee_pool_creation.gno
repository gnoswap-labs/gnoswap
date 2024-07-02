package pool

import (
	"std"

	"gno.land/r/demo/gnoswap/common"
)

// poolCreationFee is the fee that is charged when a user creates a pool
var (
	poolCreationFee = uint64(100_000_000) // 100_GNS
)

// GetPoolCreationFee returns the poolCreationFee
func GetPoolCreationFee() uint64 {
	return poolCreationFee
}

// SetPoolCreationFee sets the poolCreationFee
//
// Panics if any of the following conditions are met:
// - caller is not the admin
func SetPoolCreationFee(fee uint64) {
	common.MustCallFromAdmin()

	poolCreationFee = fee

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_fee", uint64ToStr(fee),
	)
}
