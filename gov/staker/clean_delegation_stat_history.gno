package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/gnoswap/v1/common"
)

var BLOCK_PER_DAY = consts.TIMESTAMP_DAY / consts.BLOCK_GENERATION_INTERVAL

var (
	lastCleanedHeight uint64 = 0
)

var (
	running bool = true
)

func CleanDelegationStatHistoryByAdmin() {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	cleanDelegationStatHistory()
}

func GetRunning() bool {
	return running
}

func SetRunning(run bool) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	running = run
}

func cleanDelegationStatHistory() {
	height := uint64(std.GetHeight())
	sinceLast := height - lastCleanedHeight

	if sinceLast < uint64(BLOCK_PER_DAY) {
		return
	}

	lastCleanedHeight = height

	// delete history older than 1 day, but keep the latest one
	keepFrom := height - uint64(BLOCK_PER_DAY)
	for to, history := range delegationStatHistory {
		// reverse history
		for i := len(history) - 1; i >= 0; i-- {
			if history[i].updatedBlock > keepFrom {
				continue
			}

			delegationStatHistory[to] = delegationStatHistory[to][i:]
			break
		}

	}
}
