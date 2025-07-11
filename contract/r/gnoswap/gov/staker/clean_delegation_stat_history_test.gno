package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
)

func TestCleanDelegationStatHistory(t *testing.T) {
	caller := testutils.TestAddress("caller")
	to := testutils.TestAddress("delegatee")
	addrKey := to.String()

	tests := []struct {
		name          string
		currentHeight uint64
		lastCleaned   uint64
		threshold     int64
		inputHistory  []DelegationSnapShotHistory
		expectedLen   int
	}{
		{
			name:          "no cleaning needed",
			currentHeight: 1000,
			lastCleaned:   990,
			threshold:     20,
			inputHistory: []DelegationSnapShotHistory{
				{to: to, updatedBlock: 980, updatedAt: uint64(time.Now().Unix()) - 100, amount: 100},
				{to: to, updatedBlock: 995, updatedAt: uint64(time.Now().Unix()) - 10, amount: 120},
			},
			expectedLen: 2,
		},
		{
			name:          "clean old entries",
			currentHeight: 1000,
			lastCleaned:   800,
			threshold:     100,
			inputHistory: []DelegationSnapShotHistory{
				{to: to, updatedBlock: 700, updatedAt: uint64(time.Now().Unix()) - 200, amount: 50},
				{to: to, updatedBlock: 901, updatedAt: uint64(time.Now().Unix()) - 90, amount: 100},
				{to: to, updatedBlock: 950, updatedAt: uint64(time.Now().Unix()) - 10, amount: 150},
			},
			expectedLen: 3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			thresholdVotingWeightBlockHeight = tt.threshold

			// Set up the realm and state
			testing.SetOriginCaller(caller)
			testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/gov/staker"))

			historyState.SnapshotHistory()[addrKey] = tt.inputHistory

			CleanDelegationStatHistory(tt.threshold)

			snapshots := historyState.SnapshotHistory()[addrKey]
			uassert.Equal(t, tt.expectedLen, len(snapshots), "unexpected snapshot history length")
		})
	}
}
