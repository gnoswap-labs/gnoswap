package staker

import (
	"std"

	"gno.land/r/gnoswap/v2/consts"
)

const BLOCK_PER_DAY = 86400 // based on block time 1s

var (
	lastCleanedHeight uint64 = 0
)

var (
	running bool = true
)

func CleanDelegationStatHistoryByAdmin() {
	prev := std.PrevRealm().Addr()
	if prev != consts.ADMIN {
		panic("only admin can clean delegation stat history")
	}

	cleanDelegationStatHistory()
}

func GetRunning() bool {
	return running
}

func SetRunning(run bool) {
	prev := std.PrevRealm().Addr()

	if prev != consts.ADMIN {
		panic("only admin can set running")
	}

	running = run
}

func cleanDelegationStatHistory() {
	height := uint64(std.GetHeight())
	sinceLast := height - lastCleanedHeight

	if sinceLast < BLOCK_PER_DAY {
		return
	}

	lastCleanedHeight = height

	// delete history older than 1 day, but keep the latest one
	keepFrom := height - BLOCK_PER_DAY
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
