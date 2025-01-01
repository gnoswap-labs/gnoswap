package staker

import (
	"std"

	"gno.land/r/gnoswap/v1/consts"
)

var BLOCK_PER_DAY = consts.TIMESTAMP_DAY / consts.BLOCK_GENERATION_INTERVAL

var (
	lastCleanedHeight uint64 = 0
	running           bool   = true
)

func CleanDelegationStatHistoryByAdmin() {
	assertCallerIsAdmin()
	cleanDelegationStatHistory()
}

func GetRunning() bool {
	return running
}

func SetRunning(run bool) {
	assertCallerIsAdmin()

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

	delegationStatHistory.Iterate("", "", func(key string, value interface{}) bool {
		history := value.([]DelegationStatHistory)

		// reverse history
		for i := len(history) - 1; i >= 0; i-- {
			if history[i].updatedBlock > keepFrom {
				continue
			}

			// save truncated history
			newHistory := history[i:]
			delegationStatHistory.Set(key, newHistory)
			break
		}

		return false
	})
}
