// TODO: Change file name

package staker

import (
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
)

var (
	// default one day
	thresholdVotingWeightBlockHeight        = consts.SECONDS_PER_DAY / milliToSec(consts.BLOCK_GENERATION_INTERVAL)
	running                          bool   = true
	lastCleanedHeight                uint64 = 0
)

// CleanDelegationStatHistoryByAdmin cleans delegation stat history
func CleanDelegationStatHistoryByAdmin() {
	assertCallerIsAdmin()
	cleanDelegationStatHistory(thresholdVotingWeightBlockHeight)
}

// GetThresholdVotingWeightBlockHeight returns the threshold voting weight block height
func GetThresholdVotingWeightBlockHeight() int64 {
	return thresholdVotingWeightBlockHeight
}

// SetThresholdVotingWeightBlockHeightByAdmin sets the threshold voting weight block height
func SetThresholdVotingWeightBlockHeightByAdmin(cur realm, height int64) {
	assertCallerIsAdmin()
	if height < 0 {
		panic(ufmt.Sprintf("invalid height: %d", height))
	}
	thresholdVotingWeightBlockHeight = height
}

// GetRunning returns the running status
func GetRunning() bool {
	return running
}

// SetRunning sets the running status
func SetRunning(cur realm, run bool) {
	assertCallerIsAdmin()

	running = run
}

// cleanDelegationStatHistory is a wrapper for HistoryState method
func cleanDelegationStatHistory(thresholdVotingWeightBlockHeight int64) {
	if err := historyState.pruneSnapshots(thresholdVotingWeightBlockHeight); err != nil {
		panic(err)
	}
}
