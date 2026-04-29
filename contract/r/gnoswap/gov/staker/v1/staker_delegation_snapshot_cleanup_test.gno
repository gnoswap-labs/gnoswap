package v1

import (
	"testing"

	bptree "gno.land/p/nt/bptree/v0"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/gov/staker"
)

func TestCleanTotalDelegationHistory(t *testing.T) {
	tests := []struct {
		name                       string
		setupHistory               func() *staker.UintTree
		cutoffTimestamp            int64
		expectedEntries            int
		expectedPreservedTimestamp int64 // 0 means no pre-cutoff entry preserved
		expectedPreservedValue     int64
		expectedLatestValue        int64
	}{
		{
			name: "empty history stays empty",
			setupHistory: func() *staker.UintTree {
				return staker.NewUintTree()
			},
			cutoffTimestamp:            1000,
			expectedEntries:            0,
			expectedPreservedTimestamp: 0,
			expectedPreservedValue:     0,
			expectedLatestValue:        0,
		},
		{
			name: "all entries after cutoff are preserved",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(2000), int64(500))
				h.Set(int64(3000), int64(600))
				return h
			},
			cutoffTimestamp:            1000,
			expectedEntries:            2,
			expectedPreservedTimestamp: 0, // no pre-cutoff entry
			expectedPreservedValue:     0,
			expectedLatestValue:        600,
		},
		{
			name: "entries before cutoff are removed, last pre-cutoff value re-inserted at cutoff timestamp",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(100))
				h.Set(int64(200), int64(200))
				h.Set(int64(500), int64(500)) // most recent before cutoff
				h.Set(int64(1500), int64(1500))
				return h
			},
			cutoffTimestamp:            1000,
			expectedEntries:            2, // cutoff entry + 1500
			expectedPreservedTimestamp: 1000,
			expectedPreservedValue:     500,
			expectedLatestValue:        1500,
		},
		{
			name: "all entries before cutoff leaves only the cutoff entry",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(100))
				h.Set(int64(200), int64(200))
				h.Set(int64(500), int64(999))
				return h
			},
			cutoffTimestamp:            1000,
			expectedEntries:            1, // only the re-inserted cutoff entry
			expectedPreservedTimestamp: 1000,
			expectedPreservedValue:     999,
			expectedLatestValue:        999,
		},
		{
			name: "exact cutoff timestamp entry is preserved",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(500), int64(500))
				h.Set(int64(1000), int64(1000)) // exact cutoff
				h.Set(int64(1500), int64(1500))
				return h
			},
			cutoffTimestamp:            1000,
			expectedEntries:            2, // cutoff entry + 1500 (500 removed, 1000 kept)
			expectedPreservedTimestamp: 1000,
			expectedPreservedValue:     1000,
			expectedLatestValue:        1500,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.totalDelegationHistory = tt.setupHistory()

			gs := &govStakerV1{store: store}
			gs.cleanTotalDelegationHistory(tt.cutoffTimestamp)

			resultHistory := store.GetTotalDelegationHistory()
			uassert.Equal(t, tt.expectedEntries, resultHistory.Size())

			if tt.expectedEntries > 0 {
				// Verify the preserved pre-cutoff entry, if any.
				if tt.expectedPreservedTimestamp > 0 {
					value, exists := resultHistory.Get(tt.expectedPreservedTimestamp)
					uassert.True(t, exists)
					uassert.Equal(t, tt.expectedPreservedValue, value.(int64))
				}

				latestValue := gs.getLatestTotalDelegation(resultHistory)
				uassert.Equal(t, tt.expectedLatestValue, latestValue)
			}
		})
	}
}

func TestCleanUserDelegationHistoryForAddress(t *testing.T) {
	user1 := address("g1user0000000000000000000000000000000001")
	user2 := address("g1user0000000000000000000000000000000002")

	tests := []struct {
		name                     string
		setupHistory             func() *bptree.BPTree
		target                   address
		cutoffTimestamp          int64
		expectedTotalEntries     int
		expectedUser1Entries     int
		expectedUser1LatestValue int64
		expectedUser2Entries     int
	}{
		{
			name: "empty history stays empty",
			setupHistory: func() *bptree.BPTree {
				return bptree.NewBPTreeN(16)
			},
			target:                   user1,
			cutoffTimestamp:          1000,
			expectedTotalEntries:     0,
			expectedUser1Entries:     0,
			expectedUser1LatestValue: 0,
			expectedUser2Entries:     0,
		},
		{
			name: "target with all entries after cutoff preserved",
			setupHistory: func() *bptree.BPTree {
				tree := bptree.NewBPTreeN(16)
				tree.Set(makeUserHistoryKey(user1.String(), 2000), int64(500))
				tree.Set(makeUserHistoryKey(user1.String(), 3000), int64(600))
				return tree
			},
			target:                   user1,
			cutoffTimestamp:          1000,
			expectedTotalEntries:     2,
			expectedUser1Entries:     2,
			expectedUser1LatestValue: 600,
		},
		{
			name: "target with entries before cutoff cleaned",
			setupHistory: func() *bptree.BPTree {
				tree := bptree.NewBPTreeN(16)
				tree.Set(makeUserHistoryKey(user1.String(), 100), int64(100))
				tree.Set(makeUserHistoryKey(user1.String(), 500), int64(500))
				tree.Set(makeUserHistoryKey(user1.String(), 1500), int64(1500))
				return tree
			},
			target:                   user1,
			cutoffTimestamp:          1000,
			expectedTotalEntries:     2, // latest pre-cutoff (500) + 1500
			expectedUser1Entries:     2,
			expectedUser1LatestValue: 1500,
		},
		{
			name: "non-target user is not affected",
			setupHistory: func() *bptree.BPTree {
				tree := bptree.NewBPTreeN(16)

				tree.Set(makeUserHistoryKey(user1.String(), 100), int64(100))
				tree.Set(makeUserHistoryKey(user1.String(), 500), int64(500))
				tree.Set(makeUserHistoryKey(user1.String(), 1500), int64(1500))

				tree.Set(makeUserHistoryKey(user2.String(), 100), int64(11))
				tree.Set(makeUserHistoryKey(user2.String(), 500), int64(22))
				tree.Set(makeUserHistoryKey(user2.String(), 1500), int64(33))

				return tree
			},
			target:                   user1,
			cutoffTimestamp:          1000,
			expectedTotalEntries:     5, // user1: 500 + 1500 = 2; user2 untouched: 3
			expectedUser1Entries:     2,
			expectedUser1LatestValue: 1500,
			expectedUser2Entries:     3,
		},
		{
			name: "target with only old entries keeps the latest pre-cutoff entry",
			setupHistory: func() *bptree.BPTree {
				tree := bptree.NewBPTreeN(16)
				tree.Set(makeUserHistoryKey(user1.String(), 100), int64(100))
				tree.Set(makeUserHistoryKey(user1.String(), 500), int64(999))
				return tree
			},
			target:                   user1,
			cutoffTimestamp:          1000,
			expectedTotalEntries:     1,
			expectedUser1Entries:     1,
			expectedUser1LatestValue: 999,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.userDelegationHistory = tt.setupHistory()

			gs := &govStakerV1{store: store}
			gs.cleanUserDelegationHistoryForAddress(tt.target, tt.cutoffTimestamp)

			// Verify total entry count across all users
			uassert.Equal(t, tt.expectedTotalEntries, store.userDelegationHistory.Size())

			// Verify user1 entries
			user1Entries := countAddressEntries(store.userDelegationHistory, user1.String())
			uassert.Equal(t, tt.expectedUser1Entries, user1Entries)

			if tt.expectedUser1Entries > 0 {
				latestValue := gs.getLatestUserDelegationByAddress(store.userDelegationHistory, user1.String())
				uassert.Equal(t, tt.expectedUser1LatestValue, latestValue)
			}

			// Verify user2 entries
			user2Entries := countAddressEntries(store.userDelegationHistory, user2.String())
			uassert.Equal(t, tt.expectedUser2Entries, user2Entries)
		})
	}
}

// countAddressEntries returns the number of entries within the given address prefix.
func countAddressEntries(history *bptree.BPTree, addrStr string) int {
	lo, hi := userHistoryKeyRange(addrStr)
	count := 0
	history.Iterate(lo, hi, func(_ string, _ any) bool {
		count++
		return false
	})
	return count
}
