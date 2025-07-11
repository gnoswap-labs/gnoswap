// TODO: Change file name

package staker

import (
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
func GetThresholdVotingWeightBlockHeight() uint64 {
	return uint64(thresholdVotingWeightBlockHeight)
}

// SetThresholdVotingWeightBlockHeightByAdmin sets the threshold voting weight block height
func SetThresholdVotingWeightBlockHeightByAdmin(cur realm, height uint64) {
	assertCallerIsAdmin()

	thresholdVotingWeightBlockHeight = int64(height)
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
// TODO: should be private
func cleanDelegationStatHistory(thresholdVotingWeightBlockHeight int64) {
	historyState.pruneSnapshots(thresholdVotingWeightBlockHeight)
}
