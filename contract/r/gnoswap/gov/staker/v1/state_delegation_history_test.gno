package v1

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/staker"
)

func TestAddDelegationRecord_Comprehensive(t *testing.T) {
	tests := []struct {
		name        string
		delegations []struct {
			delegatee address
			amount    int64
			timestamp int64
		}
		expectedTotalAtTime map[int64]int64
		expectedUserAtTime  map[int64]int64
	}{
		{
			name: "single delegation record",
			delegations: []struct {
				delegatee address
				amount    int64
				timestamp int64
			}{
				{address("g1delegatee"), 1000, 100},
			},
			expectedTotalAtTime: map[int64]int64{
				100: 1000,
				200: 1000,
			},
			expectedUserAtTime: map[int64]int64{
				100: 1000,
				200: 1000,
			},
		},
		{
			name: "multiple delegation records cumulative",
			delegations: []struct {
				delegatee address
				amount    int64
				timestamp int64
			}{
				{address("g1delegatee"), 1000, 100},
				{address("g1delegatee"), 500, 200},
				{address("g1delegatee"), 300, 300},
			},
			expectedTotalAtTime: map[int64]int64{
				100: 1000,
				200: 1500,
				300: 1800,
				400: 1800,
			},
			expectedUserAtTime: map[int64]int64{
				100: 1000,
				200: 1500,
				300: 1800,
			},
		},
		{
			name: "undelegate reduces amount",
			delegations: []struct {
				delegatee address
				amount    int64
				timestamp int64
			}{
				{address("g1delegatee"), 1000, 100},
				{address("g1delegatee"), -300, 200},
			},
			expectedTotalAtTime: map[int64]int64{
				100: 1000,
				200: 700,
				300: 700,
			},
			expectedUserAtTime: map[int64]int64{
				100: 1000,
				200: 700,
			},
		},
		{
			name: "undelegate more than balance clamps to zero",
			delegations: []struct {
				delegatee address
				amount    int64
				timestamp int64
			}{
				{address("g1delegatee"), 1000, 100},
				{address("g1delegatee"), -2000, 200},
			},
			expectedTotalAtTime: map[int64]int64{
				100: 1000,
				200: 0,
			},
			expectedUserAtTime: map[int64]int64{
				100: 1000,
				200: 0,
			},
		},
		{
			name: "multiple users independent histories",
			delegations: []struct {
				delegatee address
				amount    int64
				timestamp int64
			}{
				{address("g1user1"), 1000, 100},
				{address("g1user2"), 2000, 100},
				{address("g1user1"), 500, 200},
			},
			expectedTotalAtTime: map[int64]int64{
				100: 3000,
				200: 3500,
			},
			expectedUserAtTime: map[int64]int64{
				100: 1000,
				200: 1500,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gs := createTestGovStaker()

			// Add all delegation records
			for _, d := range tt.delegations {
				gs.addDelegationRecord(d.delegatee, d.amount, d.timestamp)
			}

			// Verify total delegation history
			for timestamp, expectedTotal := range tt.expectedTotalAtTime {
				amount, found := gs.GetTotalDelegationAmountAtSnapshot(timestamp)
				uassert.True(t, found)
				uassert.Equal(t, expectedTotal, amount)
			}

			// Verify user delegation history (using first delegatee for user tests)
			if len(tt.delegations) > 0 {
				firstDelegatee := tt.delegations[0].delegatee
				for timestamp, expectedUser := range tt.expectedUserAtTime {
					amount, found := gs.GetUserDelegationAmountAtSnapshot(firstDelegatee, timestamp)
					uassert.True(t, found)
					uassert.Equal(t, expectedUser, amount)
				}
			}
		})
	}
}

func TestUpdateTotalDelegationHistory_Comprehensive(t *testing.T) {
	tests := []struct {
		name           string
		initialHistory func() *staker.UintTree
		amount         int64
		timestamp      int64
		expectedTotal  int64
	}{
		{
			name: "first entry in empty history",
			initialHistory: func() *staker.UintTree {
				return staker.NewUintTree()
			},
			amount:        1000,
			timestamp:     100,
			expectedTotal: 1000,
		},
		{
			name: "add to existing total",
			initialHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(50), int64(500))
				return h
			},
			amount:        300,
			timestamp:     100,
			expectedTotal: 800,
		},
		{
			name: "subtract from existing total",
			initialHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(50), int64(500))
				return h
			},
			amount:        -200,
			timestamp:     100,
			expectedTotal: 300,
		},
		{
			name: "negative result clamps to zero",
			initialHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(50), int64(500))
				return h
			},
			amount:        -1000,
			timestamp:     100,
			expectedTotal: 0,
		},
		{
			name: "zero amount no change",
			initialHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(50), int64(500))
				return h
			},
			amount:        0,
			timestamp:     100,
			expectedTotal: 500,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.totalDelegationHistory = tt.initialHistory()

			gs := &govStakerV1{store: store}
			gs.updateTotalDelegationHistory(tt.amount, tt.timestamp)

			// Verify the new total at timestamp
			amount, found := gs.GetTotalDelegationAmountAtSnapshot(tt.timestamp)
			uassert.True(t, found)
			uassert.Equal(t, tt.expectedTotal, amount)
		})
	}
}

func TestUpdateUserDelegationHistory_Comprehensive(t *testing.T) {
	user1 := address("g1user0000000000000000000000000000000001")

	tests := []struct {
		name           string
		initialHistory func() *avl.Tree
		delegatee      address
		amount         int64
		timestamp      int64
		expectedAmount int64
	}{
		{
			name: "first entry for new user",
			initialHistory: func() *avl.Tree {
				return avl.NewTree()
			},
			delegatee:      user1,
			amount:         1000,
			timestamp:      100,
			expectedAmount: 1000,
		},
		{
			name: "add to existing user amount",
			initialHistory: func() *avl.Tree {
				tree := avl.NewTree()
				userHistory := staker.NewUintTree()
				userHistory.Set(int64(50), int64(500))
				tree.Set(user1.String(), userHistory)
				return tree
			},
			delegatee:      user1,
			amount:         300,
			timestamp:      100,
			expectedAmount: 800,
		},
		{
			name: "subtract from existing user amount",
			initialHistory: func() *avl.Tree {
				tree := avl.NewTree()
				userHistory := staker.NewUintTree()
				userHistory.Set(int64(50), int64(500))
				tree.Set(user1.String(), userHistory)
				return tree
			},
			delegatee:      user1,
			amount:         -200,
			timestamp:      100,
			expectedAmount: 300,
		},
		{
			name: "negative result clamps to zero",
			initialHistory: func() *avl.Tree {
				tree := avl.NewTree()
				userHistory := staker.NewUintTree()
				userHistory.Set(int64(50), int64(500))
				tree.Set(user1.String(), userHistory)
				return tree
			},
			delegatee:      user1,
			amount:         -1000,
			timestamp:      100,
			expectedAmount: 0, // Clamped to 0, not negative
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := newMockGovStakerStore().(*mockGovStakerStore)
			store.userDelegationHistory = tt.initialHistory()

			gs := &govStakerV1{store: store}
			gs.updateUserDelegationHistory(tt.delegatee, tt.amount, tt.timestamp)

			// Verify the new amount at timestamp
			amount, found := gs.GetUserDelegationAmountAtSnapshot(tt.delegatee, tt.timestamp)
			uassert.True(t, found)
			uassert.Equal(t, tt.expectedAmount, amount)
		})
	}
}

func TestGetLatestTotalDelegation(t *testing.T) {
	tests := []struct {
		name           string
		setupHistory   func() *staker.UintTree
		expectedAmount int64
	}{
		{
			name: "empty history returns zero",
			setupHistory: func() *staker.UintTree {
				return staker.NewUintTree()
			},
			expectedAmount: 0,
		},
		{
			name: "single entry returns that value",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(1000))
				return h
			},
			expectedAmount: 1000,
		},
		{
			name: "multiple entries returns latest",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(1000))
				h.Set(int64(200), int64(2000))
				h.Set(int64(300), int64(3000))
				return h
			},
			expectedAmount: 3000,
		},
		{
			name: "non-chronological insertion still returns max timestamp",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(300), int64(3000))
				h.Set(int64(100), int64(1000))
				h.Set(int64(200), int64(2000))
				return h
			},
			expectedAmount: 3000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gs := &govStakerV1{store: newMockGovStakerStore()}
			history := tt.setupHistory()

			result := gs.getLatestTotalDelegation(history)

			uassert.Equal(t, tt.expectedAmount, result)
		})
	}
}

func TestGetLatestUserDelegation(t *testing.T) {
	tests := []struct {
		name           string
		setupHistory   func() *staker.UintTree
		expectedAmount int64
	}{
		{
			name: "empty history returns zero",
			setupHistory: func() *staker.UintTree {
				return staker.NewUintTree()
			},
			expectedAmount: 0,
		},
		{
			name: "single entry returns that value",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(500))
				return h
			},
			expectedAmount: 500,
		},
		{
			name: "multiple entries returns latest",
			setupHistory: func() *staker.UintTree {
				h := staker.NewUintTree()
				h.Set(int64(100), int64(500))
				h.Set(int64(200), int64(1000))
				h.Set(int64(300), int64(1500))
				return h
			},
			expectedAmount: 1500,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gs := &govStakerV1{store: newMockGovStakerStore()}
			history := tt.setupHistory()

			result := gs.getLatestUserDelegation(history)

			uassert.Equal(t, tt.expectedAmount, result)
		})
	}
}
