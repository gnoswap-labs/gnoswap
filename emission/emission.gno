package emission

import (
	"std"

	"gno.land/r/gnoswap/v2/consts"
)

// lastExecutedHeight is a flag to prevent multiple calling MintAndDistributeGns in the same block height
var lastExecutedHeight int64

// lastStakerGnsBalance is history of staker GNS balance
var lastStakerGnsBalance uint64

// emissionGnsBalance is balance of emission address
var emissionGnsBalance uint64

// MintAndDistributeGns mints GNS and distributes to target
func MintAndDistributeGns() {
	lastStakerGnsBalance = gnsBalance(consts.STAKER_ADDR)

	height := std.GetHeight()
	if lastExecutedHeight >= height {
		// do not panic here, we don't want to panic entire transaction that calls this function
		return
	}

	mintGns()

	emissionGnsBalance = gnsBalance(emissionAddr)
	distributeToTarget(emissionGnsBalance)

	// XXX TODO: REMOVE AFTER EMISSION QA
	println("EM_emissionGnsBalance:\t\t\t", emissionGnsBalance)
	println("EM_emissionGnsBalance(75%):\t\t", emissionGnsBalance*75/100)

	lastExecutedHeight = height
}

func GetLastExecutedHeight() int64 {
	return lastExecutedHeight
}

func GetLastStakerGnsBalance() uint64 {
	return lastStakerGnsBalance
}
