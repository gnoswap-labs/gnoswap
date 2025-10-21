package v1

import (
	"testing"

	_ "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	_ "gno.land/r/gnoswap/router"
	_ "gno.land/r/gnoswap/router/v1"

	"gno.land/p/nt/uassert"
)

// Test lockup period management
func TestUnDelegationLockupPeriod(t *testing.T) {
	tests := []struct {
		name           string
		setPeriod      int64
		expectedPeriod int64
	}{
		{
			name:           "Set standard lockup period",
			setPeriod:      60 * 60 * 24 * 7, // 7 days
			expectedPeriod: 60 * 60 * 24 * 7,
		},
		{
			name:           "Set custom lockup period",
			setPeriod:      60 * 60 * 24 * 14, // 14 days
			expectedPeriod: 60 * 60 * 24 * 14,
		},
		{
			name:           "Set zero lockup period",
			setPeriod:      0,
			expectedPeriod: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// When: Set lockup period
			gs.setUnDelegationLockupPeriod(tt.setPeriod)

			// Then: Should return expected period
			result := gs.getUnDelegationLockupPeriod()
			uassert.Equal(t, result, tt.expectedPeriod)
		})
	}
}

// Test delegation ID management
func TestDelegationIDManagement(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Get and increment delegation IDs",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// Given: Initial state
			initialID := gs.getCurrentDelegationID()

			// When: Get next delegation ID
			nextID := gs.nextDelegationID()

			// Then: Should increment correctly
			uassert.Equal(t, nextID, initialID+1)
			uassert.Equal(t, gs.getCurrentDelegationID(), nextID)
		})
	}
}

// Test delegation management
func TestDelegationManagement(t *testing.T) {
	tests := []struct {
		name           string
		delegateFrom   address
		delegateTo     address
		delegateAmount int64
		expectSuccess  bool
	}{
		{
			name:           "Add valid delegation",
			delegateFrom:   address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
			delegateTo:     address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
			delegateAmount: 1000,
			expectSuccess:  true,
		},
		{
			name:           "Add another delegation",
			delegateFrom:   address("g1w8m4s75k9l6n8vc6fmpcprgey4ck233kfhx5tz"),
			delegateTo:     address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
			delegateAmount: 500,
			expectSuccess:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// Given: Create new delegation
			delegationID := gs.nextDelegationID()
			delegation := NewDelegation(
				delegationID,
				tt.delegateFrom,
				tt.delegateTo,
				tt.delegateAmount,
				100,
				100,
			)

			// When: Add delegation
			result := gs.addDelegation(delegationID, delegation)

			// Then: Should succeed
			if tt.expectSuccess {
				uassert.True(t, result)

				// Verify delegation was stored
				storedDelegation := gs.getDelegation(delegationID)
				uassert.NotEqual(t, storedDelegation, nil)
				uassert.Equal(t, storedDelegation.DelegateFrom(), tt.delegateFrom)
				uassert.Equal(t, storedDelegation.DelegateTo(), tt.delegateTo)
				uassert.Equal(t, storedDelegation.TotalDelegatedAmount(), tt.delegateAmount)
			} else {
				uassert.False(t, result)
			}
		})
	}
}

// Test user delegation retrieval
func TestGetUserDelegations(t *testing.T) {
	tests := []struct {
		name          string
		setupState    func(gs *govStakerV1) (address, []int64)
		expectedCount int
	}{
		{
			name: "Get delegations for user with multiple delegations",
			setupState: func(gs *govStakerV1) (address, []int64) {
				user := address("g1testuser1234567890abcdefghijklmnopqr")
				delegationIDs := make([]int64, 0)

				// Add multiple delegations for the user
				for i := 0; i < 3; i++ {
					delegationID := gs.nextDelegationID()
					delegation := NewDelegation(
						delegationID,
						user,
						address("g1validator1234567890abcdefghijklmnop"),
						int64(1000*(i+1)),
						100,
						100,
					)
					gs.addDelegation(delegationID, delegation)
					delegationIDs = append(delegationIDs, delegationID)
				}
				return user, delegationIDs
			},
			expectedCount: 3,
		},
		{
			name: "Get delegations for user with no delegations",
			setupState: func(gs *govStakerV1) (address, []int64) {
				user := address("g1newuser1234567890abcdefghijklmnopqr")
				return user, []int64{}
			},
			expectedCount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// Given: Setup state
			user, _ := tt.setupState(gs)

			// When: Get user delegations
			userDelegations := gs.getUserDelegations(user)

			// Then: Should return expected count
			uassert.Equal(t, len(userDelegations), tt.expectedCount)

			// Verify all delegations belong to the user
			for _, delegation := range userDelegations {
				uassert.Equal(t, delegation.DelegateFrom(), user)
			}
		})
	}
}

// Test delegation removal
func TestRemoveDelegation(t *testing.T) {
	tests := []struct {
		name          string
		setupState    func(gs *govStakerV1) int64
		expectSuccess bool
	}{
		{
			name: "Remove existing delegation",
			setupState: func(gs *govStakerV1) int64 {
				delegationID := gs.nextDelegationID()
				delegation := NewDelegation(
					delegationID,
					address("g1user1234567890abcdefghijklmnopqrst"),
					address("g1validator1234567890abcdefghijklmno"),
					1000,
					100,
					100,
				)
				gs.addDelegation(delegationID, delegation)
				return delegationID
			},
			expectSuccess: true,
		},
		{
			name: "Remove non-existent delegation",
			setupState: func(gs *govStakerV1) int64 {
				return 99999 // Non-existent ID
			},
			expectSuccess: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// Given: Setup state
			delegationID := tt.setupState(gs)

			// When: Remove delegation
			result := gs.removeDelegation(delegationID)

			// Then: Should return expected result
			uassert.Equal(t, result, tt.expectSuccess)

			if tt.expectSuccess {
				// Verify delegation was removed
				delegation := gs.getDelegation(delegationID)
				uassert.Equal(t, delegation, nil)
			}
		})
	}
}

// Test delegation history management
func TestDelegationHistoryManagement(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Add delegation record to history",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// Given: Initial history state
			initialHistory := gs.getDelegationHistory()
			initialLength := len(initialHistory)

			// Create delegation record
			record := &DelegationRecord{
				delegateFrom:   address("g1user1234567890abcdefghijklmnopqrst"),
				delegateTo:     address("g1validator1234567890abcdefghijklmno"),
				delegateAmount: 1000,
				delegationType: DelegateType,
				createdAt:      100,
			}

			// When: Add delegation record
			gs.addDelegationRecord(record)

			// Then: Should increase history length
			updatedHistory := gs.getDelegationHistory()
			uassert.Equal(t, len(updatedHistory), initialLength+1)
		})
	}
}

// Test delegation snapshots management
func TestDelegationSnapshotsManagement(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Set and get delegation snapshots",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// Given: Create new snapshot
			newSnapshot := make(DelegationSnapshot)
			newSnapshot["user1"] = &DelegationSnapshotItem{
				delegationAmount: 1000,
				delegatorAddress: address("user1"),
			}

			// When: Set delegation snapshots
			gs.setDelegationSnapshots(newSnapshot)

			// Then: Should retrieve the same snapshot
			retrievedSnapshot := gs.getDelegationSnapshots()
			uassert.Equal(t, len(retrievedSnapshot), len(newSnapshot))

			if item, exists := retrievedSnapshot["user1"]; exists {
				uassert.Equal(t, item.delegationAmount, int64(1000))
				uassert.Equal(t, item.delegatorAddress, address("user1"))
			} else {
				t.Errorf("Expected snapshot item for user1 not found")
			}
		})
	}
}

// Test launchpad project deposits
func TestLaunchpadProjectDeposits(t *testing.T) {
	tests := []struct {
		name          string
		ownerAddress  string
		depositAmount int64
		expectSuccess bool
	}{
		{
			name:          "Set launchpad project deposit",
			ownerAddress:  "g1projectowner1234567890abcdefghijklm",
			depositAmount: 5000,
			expectSuccess: true,
		},
		{
			name:          "Update existing deposit",
			ownerAddress:  "g1projectowner1234567890abcdefghijklm",
			depositAmount: 7500,
			expectSuccess: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// When: Set launchpad project deposit
			result := gs.setLaunchpadProjectDeposit(tt.ownerAddress, tt.depositAmount)

			// Then: Should succeed
			uassert.Equal(t, result, tt.expectSuccess)

			if tt.expectSuccess {
				// Verify deposit was stored
				storedDeposit, exists := gs.getLaunchpadProjectDeposit(tt.ownerAddress)
				uassert.True(t, exists)
				uassert.Equal(t, storedDeposit, tt.depositAmount)
			}
		})
	}
}

// Test launchpad deposit removal
func TestRemoveLaunchpadProjectDeposit(t *testing.T) {
	tests := []struct {
		name          string
		setupState    func(gs *govStakerV1) string
		expectSuccess bool
	}{
		{
			name: "Remove existing deposit",
			setupState: func(gs *govStakerV1) string {
				ownerAddress := "g1projectowner9876543210abcdefghijklm"
				gs.setLaunchpadProjectDeposit(ownerAddress, 3000)
				return ownerAddress
			},
			expectSuccess: true,
		},
		{
			name: "Remove non-existent deposit",
			setupState: func(gs *govStakerV1) string {
				return "g1nonexistentowner1234567890abcdefgh"
			},
			expectSuccess: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// Given: Setup state
			ownerAddress := tt.setupState(gs)

			// When: Remove launchpad project deposit
			result := gs.removeLaunchpadProjectDeposit(ownerAddress)

			// Then: Should return expected result
			uassert.Equal(t, result, tt.expectSuccess)

			if tt.expectSuccess {
				// Verify deposit was removed
				_, exists := gs.getLaunchpadProjectDeposit(ownerAddress)
				uassert.False(t, exists)
			}
		})
	}
}

// Test makeLaunchpadRewardID
func TestMakeLaunchpadRewardID(t *testing.T) {
	tests := []struct {
		name     string
		address  string
		expected string
	}{
		{
			name:     "Create launchpad reward ID",
			address:  "g1projectowner1234567890abcdefghijklm",
			expected: "launchpad:g1projectowner1234567890abcdefghijklm",
		},
		{
			name:     "Create reward ID with different address",
			address:  "user1",
			expected: "launchpad:user1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// When: Create launchpad reward ID
			result := gs.makeLaunchpadRewardID(tt.address)

			// Then: Should return expected format
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test launchpad stake operations
func TestLaunchpadStakeOperations(t *testing.T) {
	tests := []struct {
		name          string
		address       string
		amount        int64
		currentHeight int64
	}{
		{
			name:          "Add stake from launchpad",
			address:       "g1projectowner1234567890abcdefghijklm",
			amount:        2000,
			currentHeight: 100,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// When: Add stake from launchpad
			testing.SetRealm(adminRealm)
			func(cur realm) {
				gs.addStakeFromLaunchpad(tt.address, tt.amount, tt.currentHeight)
			}(cross)

			// Then: Should create deposit record
			launchpadRewardID := gs.makeLaunchpadRewardID(tt.address)
			deposit, exists := gs.getLaunchpadProjectDeposit(launchpadRewardID)
			uassert.True(t, exists)
			uassert.Equal(t, deposit, tt.amount)

			// When: Remove stake from launchpad
			gs.removeStakeFromLaunchpad(tt.address, tt.amount, tt.currentHeight)

			// Then:
			launchpadDepositAmount, _ := gs.getLaunchpadProjectDeposit(launchpadRewardID)
			uassert.Equal(t, launchpadDepositAmount, int64(0))
		})
	}
}

// Test partial launchpad stake removal
func TestPartialLaunchpadStakeRemoval(t *testing.T) {
	tests := []struct {
		name              string
		address           string
		initialAmount     int64
		removeAmount      int64
		expectedRemaining int64
		currentHeight     int64
	}{
		{
			name:              "Partial removal leaves remaining deposit",
			address:           "g1projectowner5555555555abcdefghijklm",
			initialAmount:     3000,
			removeAmount:      1000,
			expectedRemaining: 2000,
			currentHeight:     100,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// Given: Initial stake
			gs.addStakeFromLaunchpad(tt.address, tt.initialAmount, tt.currentHeight)

			// When: Remove partial stake
			gs.removeStakeFromLaunchpad(tt.address, tt.removeAmount, tt.currentHeight)

			// Then: Should have remaining deposit
			launchpadRewardID := gs.makeLaunchpadRewardID(tt.address)
			deposit, exists := gs.getLaunchpadProjectDeposit(launchpadRewardID)
			uassert.True(t, exists)
			uassert.Equal(t, deposit, tt.expectedRemaining)
		})
	}
}
