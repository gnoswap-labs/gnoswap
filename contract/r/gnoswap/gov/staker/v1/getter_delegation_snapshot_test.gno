package v1

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/staker"
)

func TestGetTotalDelegationAmountAtSnapshot_Comprehensive(t *testing.T) {
	tests := []struct {
		name           string
		setupHistory   func() *staker.UintTree
		snapshotTime   int64
		expectedAmount int64
		expectedFound  bool
	}{
		{
			name: "empty history returns false",
			setupHistory: func() *staker.UintTree {
				return staker.NewUintTree()
			},
			snapshotTime:   100,
			expectedAmount: 0,
			expectedFound:  false,
		},
		{
			name: "exact timestamp match",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(1000))
				return h
			},
			snapshotTime:   100,
			expectedAmount: 1000,
			expectedFound:  true,
		},
		{
			name: "snapshot time after all entries returns latest",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(1000))
				h.Set(int64(200), int64(2000))
				return h
			},
			snapshotTime:   500,
			expectedAmount: 2000,
			expectedFound:  true,
		},
		{
			name: "snapshot time before all entries returns false",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(1000))
				h.Set(int64(200), int64(2000))
				return h
			},
			snapshotTime:   50,
			expectedAmount: 0,
			expectedFound:  false,
		},
		{
			name: "snapshot time between entries returns earlier entry",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(1000))
				h.Set(int64(200), int64(2000))
				h.Set(int64(300), int64(3000))
				return h
			},
			snapshotTime:   250,
			expectedAmount: 2000,
			expectedFound:  true,
		},
		{
			name: "multiple entries at same timestamp uses last set value",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(1000))
				h.Set(int64(100), int64(1500)) // overwrite
				return h
			},
			snapshotTime:   100,
			expectedAmount: 1500,
			expectedFound:  true,
		},
		{
			name: "zero delegation amount is valid",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(1000))
				h.Set(int64(200), int64(0))
				return h
			},
			snapshotTime:   250,
			expectedAmount: 0,
			expectedFound:  true,
		},
		{
			name: "single entry history",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(5000))
				return h
			},
			snapshotTime:   100,
			expectedAmount: 5000,
			expectedFound:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.totalDelegationHistory = tt.setupHistory()

			gs := &govStakerV1{store: store}
			amount, found := gs.GetTotalDelegationAmountAtSnapshot(tt.snapshotTime)

			uassert.Equal(t, tt.expectedFound, found)
			uassert.Equal(t, tt.expectedAmount, amount)
		})
	}
}

func TestGetUserDelegationAmountAtSnapshot_Comprehensive(t *testing.T) {
	user1 := address("g1user0000000000000000000000000000000001")
	user2 := address("g1user0000000000000000000000000000000002")

	tests := []struct {
		name           string
		setupHistory   func() *avl.Tree
		userAddr       address
		snapshotTime   int64
		expectedAmount int64
		expectedFound  bool
	}{
		{
			name: "empty history returns false",
			setupHistory: func() *avl.Tree {
				return avl.NewTree()
			},
			userAddr:       user1,
			snapshotTime:   100,
			expectedAmount: 0,
			expectedFound:  false,
		},
		{
			name: "user not in history returns false",
			setupHistory: func() *avl.Tree {
				tree := avl.NewTree()
				userHistory := staker.NewUintTree()
				userHistory.Set(int64(100), int64(1000))
				tree.Set(user2.String(), userHistory)
				return tree
			},
			userAddr:       user1,
			snapshotTime:   100,
			expectedAmount: 0,
			expectedFound:  false,
		},
		{
			name: "exact timestamp match for user",
			setupHistory: func() *avl.Tree {
				tree := avl.NewTree()
				userHistory := staker.NewUintTree()
				userHistory.Set(int64(100), int64(1000))
				tree.Set(user1.String(), userHistory)
				return tree
			},
			userAddr:       user1,
			snapshotTime:   100,
			expectedAmount: 1000,
			expectedFound:  true,
		},
		{
			name: "snapshot time after all user entries",
			setupHistory: func() *avl.Tree {
				tree := avl.NewTree()
				userHistory := staker.NewUintTree()
				userHistory.Set(int64(100), int64(1000))
				userHistory.Set(int64(200), int64(2000))
				tree.Set(user1.String(), userHistory)
				return tree
			},
			userAddr:       user1,
			snapshotTime:   500,
			expectedAmount: 2000,
			expectedFound:  true,
		},
		{
			name: "snapshot time before all user entries returns false",
			setupHistory: func() *avl.Tree {
				tree := avl.NewTree()
				userHistory := staker.NewUintTree()
				userHistory.Set(int64(100), int64(1000))
				tree.Set(user1.String(), userHistory)
				return tree
			},
			userAddr:       user1,
			snapshotTime:   50,
			expectedAmount: 0,
			expectedFound:  false,
		},
		{
			name: "snapshot time between user entries",
			setupHistory: func() *avl.Tree {
				tree := avl.NewTree()
				userHistory := staker.NewUintTree()
				userHistory.Set(int64(100), int64(1000))
				userHistory.Set(int64(200), int64(2000))
				userHistory.Set(int64(300), int64(3000))
				tree.Set(user1.String(), userHistory)
				return tree
			},
			userAddr:       user1,
			snapshotTime:   250,
			expectedAmount: 2000,
			expectedFound:  true,
		},
		{
			name: "multiple users independent histories",
			setupHistory: func() *avl.Tree {
				tree := avl.NewTree()

				user1History := staker.NewUintTree()
				user1History.Set(int64(100), int64(1000))
				tree.Set(user1.String(), user1History)

				user2History := staker.NewUintTree()
				user2History.Set(int64(100), int64(5000))
				tree.Set(user2.String(), user2History)

				return tree
			},
			userAddr:       user1,
			snapshotTime:   100,
			expectedAmount: 1000,
			expectedFound:  true,
		},
		{
			name: "user with empty history returns false",
			setupHistory: func() *avl.Tree {
				tree := avl.NewTree()
				userHistory := staker.NewUintTree()
				tree.Set(user1.String(), userHistory)
				return tree
			},
			userAddr:       user1,
			snapshotTime:   100,
			expectedAmount: 0,
			expectedFound:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.userDelegationHistory = tt.setupHistory()

			gs := &govStakerV1{store: store}
			amount, found := gs.GetUserDelegationAmountAtSnapshot(tt.userAddr, tt.snapshotTime)

			uassert.Equal(t, tt.expectedFound, found)
			uassert.Equal(t, tt.expectedAmount, amount)
		})
	}
}

func TestHasDelegationSnapshotsKey(t *testing.T) {
	tests := []struct {
		name     string
		hasKey   bool
		expected bool
	}{
		{
			name:     "returns true when key exists",
			hasKey:   true,
			expected: true,
		},
		{
			name:     "returns false when key does not exist",
			hasKey:   false,
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.hasTotalDelegationHistoryKey = tt.hasKey

			gs := &govStakerV1{store: store}
			result := gs.HasDelegationSnapshotsKey()

			uassert.Equal(t, tt.expected, result)
		})
	}
}
