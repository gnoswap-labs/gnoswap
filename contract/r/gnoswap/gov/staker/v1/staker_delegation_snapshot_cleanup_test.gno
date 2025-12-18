package v1

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/staker"
)

func TestCleanTotalDelegationHistory(t *testing.T) {
	tests := []struct {
		name                  string
		setupHistory          func() *staker.UintTree
		cutoffTimestamp       int64
		expectedEntries       int
		expectedValueAtCutoff int64
		expectedLatestValue   int64
	}{
		{
			name: "empty history stays empty",
			setupHistory: func() *staker.UintTree {
				return staker.NewUintTree()
			},
			cutoffTimestamp:       1000,
			expectedEntries:       0,
			expectedValueAtCutoff: 0,
			expectedLatestValue:   0,
		},
		{
			name: "all entries after cutoff are preserved",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(2000), int64(500))
				h.Set(int64(3000), int64(600))
				return h
			},
			cutoffTimestamp:       1000,
			expectedEntries:       2,
			expectedValueAtCutoff: 0,
			expectedLatestValue:   600,
		},
		{
			name: "entries before cutoff are removed, last value preserved at cutoff",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(100))
				h.Set(int64(200), int64(200))
				h.Set(int64(500), int64(500)) // most recent before cutoff
				h.Set(int64(1500), int64(1500))
				return h
			},
			cutoffTimestamp:       1000,
			expectedEntries:       2, // cutoff entry + 1500
			expectedValueAtCutoff: 500,
			expectedLatestValue:   1500,
		},
		{
			name: "all entries before cutoff leaves only preserved value",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(100))
				h.Set(int64(200), int64(200))
				h.Set(int64(500), int64(999))
				return h
			},
			cutoffTimestamp:       1000,
			expectedEntries:       1, // only preserved cutoff entry
			expectedValueAtCutoff: 999,
			expectedLatestValue:   999,
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
			cutoffTimestamp:       1000,
			expectedEntries:       2, // cutoff entry + 1500
			expectedValueAtCutoff: 1000,
			expectedLatestValue:   1500,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.totalDelegationHistory = tt.setupHistory()

			gs := &govStakerV1{store: store}
			gs.cleanTotalDelegationHistory(tt.cutoffTimestamp)

			// Verify entry count
			resultHistory := store.GetTotalDelegationHistory()
			uassert.Equal(t, tt.expectedEntries, resultHistory.Size())

			// Verify value at cutoff if there are entries
			if tt.expectedEntries > 0 {
				valueAtCutoff, exists := resultHistory.Get(tt.cutoffTimestamp)
				if tt.expectedValueAtCutoff > 0 {
					uassert.True(t, exists)
					uassert.Equal(t, tt.expectedValueAtCutoff, valueAtCutoff.(int64))
				}

				// Verify latest value
				latestValue := gs.getLatestTotalDelegation(resultHistory)
				uassert.Equal(t, tt.expectedLatestValue, latestValue)
			}
		})
	}
}

func TestCleanUserDelegationHistory(t *testing.T) {
	user1 := address("g1user0000000000000000000000000000000001")
	user2 := address("g1user0000000000000000000000000000000002")

	tests := []struct {
		name                     string
		setupHistory             func() *avl.Tree
		cutoffTimestamp          int64
		expectedUserCount        int
		expectedUser1Entries     int
		expectedUser1LatestValue int64
	}{
		{
			name: "empty history stays empty",
			setupHistory: func() *avl.Tree {
				return avl.NewTree()
			},
			cutoffTimestamp:          1000,
			expectedUserCount:        0,
			expectedUser1Entries:     0,
			expectedUser1LatestValue: 0,
		},
		{
			name: "user with all entries after cutoff preserved",
			setupHistory: func() *avl.Tree {
				tree := avl.NewTree()
				userHistory := staker.NewUintTree()
				userHistory.Set(int64(2000), int64(500))
				userHistory.Set(int64(3000), int64(600))
				tree.Set(user1.String(), userHistory)
				return tree
			},
			cutoffTimestamp:          1000,
			expectedUserCount:        1,
			expectedUser1Entries:     2,
			expectedUser1LatestValue: 600,
		},
		{
			name: "user with entries before cutoff cleaned",
			setupHistory: func() *avl.Tree {
				tree := avl.NewTree()
				userHistory := staker.NewUintTree()
				userHistory.Set(int64(100), int64(100))
				userHistory.Set(int64(500), int64(500))
				userHistory.Set(int64(1500), int64(1500))
				tree.Set(user1.String(), userHistory)
				return tree
			},
			cutoffTimestamp:          1000,
			expectedUserCount:        1,
			expectedUser1Entries:     2, // cutoff preserved + 1500
			expectedUser1LatestValue: 1500,
		},
		{
			name: "multiple users cleaned independently",
			setupHistory: func() *avl.Tree {
				tree := avl.NewTree()

				user1History := staker.NewUintTree()
				user1History.Set(int64(500), int64(500))
				user1History.Set(int64(1500), int64(1500))
				tree.Set(user1.String(), user1History)

				user2History := staker.NewUintTree()
				user2History.Set(int64(2000), int64(2000))
				tree.Set(user2.String(), user2History)

				return tree
			},
			cutoffTimestamp:          1000,
			expectedUserCount:        2,
			expectedUser1Entries:     2,
			expectedUser1LatestValue: 1500,
		},
		{
			name: "user with only old entries gets cutoff value preserved",
			setupHistory: func() *avl.Tree {
				tree := avl.NewTree()
				userHistory := staker.NewUintTree()
				userHistory.Set(int64(100), int64(100))
				userHistory.Set(int64(500), int64(999))
				tree.Set(user1.String(), userHistory)
				return tree
			},
			cutoffTimestamp:          1000,
			expectedUserCount:        1,
			expectedUser1Entries:     1, // only preserved cutoff
			expectedUser1LatestValue: 999,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.userDelegationHistory = tt.setupHistory()

			gs := &govStakerV1{store: store}
			gs.cleanUserDelegationHistory(tt.cutoffTimestamp)

			// Verify user count
			uassert.Equal(t, tt.expectedUserCount, store.userDelegationHistory.Size())

			// Verify user1 entries if expected
			if tt.expectedUser1Entries > 0 {
				user1HistoryRaw, exists := store.userDelegationHistory.Get(user1.String())
				uassert.True(t, exists)

				user1History := user1HistoryRaw.(*staker.UintTree)
				uassert.Equal(t, tt.expectedUser1Entries, user1History.Size())

				latestValue := gs.getLatestUserDelegation(user1History)
				uassert.Equal(t, tt.expectedUser1LatestValue, latestValue)
			}
		})
	}
}

func TestCleanUserDelegationHistory_UserRemovedWhenEmpty(t *testing.T) {
	user1 := address("g1user0000000000000000000000000000000001")

	// User has entries but all are before cutoff and no preserved value
	// This case: user has no entries at all after cleanup
	store := newMockGovStakerStore().(*mockGovStakerStore)
	tree := avl.NewTree()
	// Empty user history should result in user being removed
	userHistory := staker.NewUintTree()
	tree.Set(user1.String(), userHistory)
	store.userDelegationHistory = tree

	gs := &govStakerV1{store: store}
	gs.cleanUserDelegationHistory(1000)

	// User should be removed since history is empty
	result, exists := store.userDelegationHistory.Get(user1.String())
	uassert.True(t, exists)
	uassert.Equal(t, 0, result.(*staker.UintTree).Size())
}
