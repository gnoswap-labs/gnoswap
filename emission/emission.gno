package emission

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"
)

// lastExecutedHeight is a flag to prevent multiple calling MintAndDistributeGns in the same block height
var lastExecutedHeight int64

// lastStakerGnsBalance is history of staker GNS balance
var lastStakerGnsBalance uint64

// emissionGnsBalance is balance of emission address
var emissionGnsBalance uint64

// MintAndDistributeGns mints GNS and distributes to target
func MintAndDistributeGns() {
	common.IsHalted()

	lastStakerGnsBalance = gnsBalance(consts.STAKER_ADDR)

	height := std.GetHeight()
	if lastExecutedHeight >= height {
		// do not panic here, we don't want to panic entire transaction that calls this function
		return
	}

	amount := mintGns()

	emissionGnsBalance = gnsBalance(emissionAddr)
	distributeToTarget(emissionGnsBalance)

	std.Emit(
		"MintAndDistributeGns",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"internal_lastHeight", ufmt.Sprintf("%d", lastExecutedHeight),
		"internal_height", ufmt.Sprintf("%d", height),
		"internal_time", ufmt.Sprintf("%d", time.Now().Unix()),
		"internal_amount", ufmt.Sprintf("%d", amount),
		"internal_totalSupply", ufmt.Sprintf("%d", gns.TotalSupply()),
	)

	lastExecutedHeight = height
}

func GetLastExecutedHeight() int64 {
	return lastExecutedHeight
}

func GetLastStakerGnsBalance() uint64 {
	return lastStakerGnsBalance
}
