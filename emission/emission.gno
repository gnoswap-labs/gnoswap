package emission

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gns"
)

var (
	leftGNSAmount      uint64
	lastExecutedHeight int64
)

func SetLeftGNSAmount(amount uint64) {
	leftGNSAmount = amount
}

func GetLeftGNSAmount() uint64 {
	return leftGNSAmount
}

func hasLeftGNSAmount() bool {
	return leftGNSAmount > 0
}

func SetLastExecutedHeight(height int64) {
	lastExecutedHeight = height
}

func GetLastExecutedHeight() int64 {
	return lastExecutedHeight
}

// MintAndDistributeGns mints GNS and distributes to target
func MintAndDistributeGns() {
	common.IsHalted()

	currentHeight := std.GetHeight()
	lastMintedHeight := gns.GetLastMintedHeight()
	if lastMintedHeight >= currentHeight {
		// do not panic here, we don't want to panic entire transaction that calls this function
		// TODO:
		// 1. will be removed after testing, do not use panic here
		println(ufmt.Sprintf("[EMISSION] emission.gno__MintAndDistributeGns() || lastMintedHeight(%d) >= currentHeight(%d)", lastMintedHeight, currentHeight))
		return
	}

	mintedEmissionRewardAmount := mintGns()
	if hasLeftGNSAmount() {
		mintedEmissionRewardAmount += GetLeftGNSAmount()
		SetLeftGNSAmount(0)
	}
	distributedGNSAmount := distributeToTarget(mintedEmissionRewardAmount)
	if mintedEmissionRewardAmount != distributedGNSAmount {
		SetLeftGNSAmount(mintedEmissionRewardAmount - distributedGNSAmount)
	}

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"MintAndDistributeGns",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"internal_lastHeight", ufmt.Sprintf("%d", lastExecutedHeight),
		"internal_height", ufmt.Sprintf("%d", currentHeight),
		"internal_time", ufmt.Sprintf("%d", time.Now().Unix()),
		"internal_amount", ufmt.Sprintf("%d", mintedEmissionRewardAmount),
		"internal_totalSupply", ufmt.Sprintf("%d", gns.TotalSupply()),
	)

	SetLastExecutedHeight(currentHeight)
}
