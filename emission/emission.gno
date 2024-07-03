package emission

import (
	"std"
)

// lastExecutedHeight is a flag to prevent multiple calling MintAndDistributeGns in the same block height
var lastExecutedHeight int64

// MintAndDistributeGns mints GNS and distributes to target
func MintAndDistributeGns() {
	height := std.GetHeight()
	if lastExecutedHeight >= height {
		// do not panic here, we don't want to panic entire transaction that calls this function
		return
	}

	mintGns()

	emissionGnsBalance := gnsBalance(emissionAddr)
	distributeToTarget(emissionGnsBalance)

	lastExecutedHeight = height
}
