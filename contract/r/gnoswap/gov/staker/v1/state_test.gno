package v1

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"

	_ "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	_ "gno.land/r/gnoswap/router"
	_ "gno.land/r/gnoswap/router/v1"

	"gno.land/r/gnoswap/gov/staker"
)

func countDelegationIDs(tree *avl.Tree) int {
	total := 0
	tree.Iterate("", "", func(_ string, value interface{}) bool {
		delegationIDs, ok := value.([]int64)
		if !ok {
			return false
		}
		total += len(delegationIDs)
		return false
	})
	return total
}

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
			// When: Set lockup period
			gs := createTestGovStaker()
			gs.setUnDelegationLockupPeriod(tt.setPeriod)

			// Then: Should return expected period
			result := gs.store.GetUnDelegationLockupPeriod()
			// uassert.NoError(t, err)
			uassert.Equal(t, result, tt.expectedPeriod)
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
			delegation := staker.NewDelegation(
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
					delegation := staker.NewDelegation(
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
			uassert.Equal(t, countDelegationIDs(userDelegations), tt.expectedCount)

			// Verify all delegations belong to the user
			userDelegations.Iterate("", "", func(delegatee string, value interface{}) bool {
				delegationIDs, ok := value.([]int64)
				if !ok {
					return false
				}

				for _, id := range delegationIDs {
					delegation, exists := gs.store.GetDelegation(id)
					if !exists {
						continue
					}

					uassert.Equal(t, delegation.DelegateFrom(), user)
				}

				return false
			})
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
				delegation := staker.NewDelegation(
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

// Test delegation history management with new structure
func TestAddDelegationRecord(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Record delegation updates history",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()
			delegatee := address("g1validator1234567890abcdefghijklmno")
			timestamp := int64(100)

			// When: Record delegation
			gs.addDelegationRecord(delegatee, 1000, timestamp)

			// Then: Should update total delegation history
			totalHistory := gs.store.GetTotalDelegationHistory()
			var totalAmount int64
			totalHistory.ReverseIterate(0, timestamp+1, func(key int64, value any) bool {
				if amount, ok := value.(int64); ok {
					totalAmount = amount
				}
				return true
			})
			uassert.Equal(t, totalAmount, int64(1000))

			// Then: Should update user delegation history
			userHistoryTree := gs.store.GetUserDelegationHistory()
			var userAmount int64
			// New structure: address -> *UintTree[timestamp -> int64]
			if userHistoryRaw, exists := userHistoryTree.Get(delegatee.String()); exists {
				userHistory := userHistoryRaw.(*staker.UintTree)
				userHistory.ReverseIterate(0, timestamp+1, func(key int64, value any) bool {
					if amount, ok := value.(int64); ok {
						userAmount = amount
					}
					return true
				})
			}
			uassert.Equal(t, userAmount, int64(1000))
		})
	}
}

// Test GetTotalDelegationAmountAtSnapshot with new structure
func TestGetTotalDelegationAmountAtSnapshot(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Get total delegation at snapshot time",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()
			delegatee := address("g1validator1234567890abcdefghijklmno")

			// Record delegations at different times
			gs.addDelegationRecord(delegatee, 1000, 100) // total: 1000
			gs.addDelegationRecord(delegatee, 500, 200)  // total: 1500
			gs.addDelegationRecord(delegatee, -300, 300) // total: 1200

			// When: Get snapshot at time 150
			amount, found := gs.GetTotalDelegationAmountAtSnapshot(150)

			// Then: Should return value at or before time 150
			uassert.True(t, found)
			uassert.Equal(t, amount, int64(1000))

			// When: Get snapshot at time 250
			amount2, found2 := gs.GetTotalDelegationAmountAtSnapshot(250)

			// Then: Should return value at or before time 250
			uassert.True(t, found2)
			uassert.Equal(t, amount2, int64(1500))
		})
	}
}

// Test GetUserDelegationAmountAtSnapshot with new structure
func TestGetUserDelegationAmountAtSnapshot(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Get user delegation at snapshot time",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()
			delegatee := address("g1validator1234567890abcdefghijklmno")

			// Record delegations at different times
			gs.addDelegationRecord(delegatee, 1000, 100)
			gs.addDelegationRecord(delegatee, 500, 200)

			// When: Get user snapshot at time 150
			amount, found := gs.GetUserDelegationAmountAtSnapshot(delegatee, 150)

			// Then: Should return value at or before time 150
			uassert.True(t, found)
			uassert.Equal(t, amount, int64(1000))

			// When: Get user snapshot at time 250
			amount2, found2 := gs.GetUserDelegationAmountAtSnapshot(delegatee, 250)

			// Then: Should return value at or before time 250
			uassert.True(t, found2)
			uassert.Equal(t, amount2, int64(1500))
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
				testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
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
			setupState: func(_ *govStakerV1) string {
				return "g1nonexistentowner1234567890abcdefgh"
			},
			expectSuccess: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
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

			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
				// Given: Initial stake
				gs.addStakeFromLaunchpad(tt.address, tt.initialAmount, tt.currentHeight)

				// When: Remove partial stake
				gs.removeStakeFromLaunchpad(tt.address, tt.removeAmount, tt.currentHeight)

				// Then: Should have remaining deposit
				launchpadRewardID := gs.makeLaunchpadRewardID(tt.address)
				deposit, exists := gs.getLaunchpadProjectDeposit(launchpadRewardID)
				uassert.True(t, exists)
				uassert.Equal(t, deposit, tt.expectedRemaining)
			}(cross)
		})
	}
}

// Test getUserDelegationsWithDelegatee with comprehensive scenarios
func TestGetUserDelegationsWithDelegatee(t *testing.T) {
	tests := []struct {
		name          string
		setupState    func(gs *govStakerV1) (address, address, []int64)
		expectedCount int
	}{
		{
			name: "User with multiple delegations to same delegatee",
			setupState: func(gs *govStakerV1) (address, address, []int64) {
				user := address("g1user1234567890abcdefghijklmnopqrstu")
				delegatee := address("g1validator1234567890abcdefghijklmno")
				delegationIDs := make([]int64, 0)

				// Create 3 separate delegations from user to same delegatee
				for i := 0; i < 3; i++ {
					delegationID := gs.nextDelegationID()
					delegation := staker.NewDelegation(
						delegationID,
						user,
						delegatee,
						int64(1000*(i+1)),
						100,
						100,
					)
					gs.addDelegation(delegationID, delegation)
					delegationIDs = append(delegationIDs, delegationID)
				}
				return user, delegatee, delegationIDs
			},
			expectedCount: 3,
		},
		{
			name: "User with delegations to different delegatees - filter by specific delegatee",
			setupState: func(gs *govStakerV1) (address, address, []int64) {
				user := address("g1user9876543210abcdefghijklmnopqrstu")
				targetDelegatee := address("g1validator1111111111abcdefghijklm")
				otherDelegatee1 := address("g1validator2222222222abcdefghijklm")
				otherDelegatee2 := address("g1validator3333333333abcdefghijklm")
				delegationIDs := make([]int64, 0)

				// Add 2 delegations to target delegatee
				for i := 0; i < 2; i++ {
					delegationID := gs.nextDelegationID()
					delegation := staker.NewDelegation(
						delegationID,
						user,
						targetDelegatee,
						int64(500*(i+1)),
						100,
						100,
					)
					gs.addDelegation(delegationID, delegation)
					delegationIDs = append(delegationIDs, delegationID)
				}

				// Add delegations to other delegatees (should not be returned)
				for i := 0; i < 2; i++ {
					delegationID := gs.nextDelegationID()
					delegation := staker.NewDelegation(
						delegationID,
						user,
						otherDelegatee1,
						int64(300*(i+1)),
						100,
						100,
					)
					gs.addDelegation(delegationID, delegation)
				}

				delegationID := gs.nextDelegationID()
				delegation := staker.NewDelegation(
					delegationID,
					user,
					otherDelegatee2,
					700,
					100,
					100,
				)
				gs.addDelegation(delegationID, delegation)

				return user, targetDelegatee, delegationIDs
			},
			expectedCount: 2,
		},
		{
			name: "User with no delegations to specific delegatee",
			setupState: func(gs *govStakerV1) (address, address, []int64) {
				user := address("g1user5555555555abcdefghijklmnopqrstu")
				targetDelegatee := address("g1validator9999999999abcdefghijklm")
				otherDelegatee := address("g1validator8888888888abcdefghijklm")

				// Add delegation to different delegatee
				delegationID := gs.nextDelegationID()
				delegation := staker.NewDelegation(
					delegationID,
					user,
					otherDelegatee,
					1000,
					100,
					100,
				)
				gs.addDelegation(delegationID, delegation)

				return user, targetDelegatee, []int64{}
			},
			expectedCount: 0,
		},
		{
			name: "User with no delegations at all",
			setupState: func(gs *govStakerV1) (address, address, []int64) {
				user := address("g1newuser6666666666abcdefghijklmnopq")
				delegatee := address("g1validator7777777777abcdefghijklm")
				return user, delegatee, []int64{}
			},
			expectedCount: 0,
		},
		{
			name: "Large number of delegations to same delegatee",
			setupState: func(gs *govStakerV1) (address, address, []int64) {
				user := address("g1poweruser1234567890abcdefghijklmno")
				delegatee := address("g1bigvalidator1234567890abcdefghij")
				delegationIDs := make([]int64, 0)

				// Create 10 delegations
				for i := 0; i < 10; i++ {
					delegationID := gs.nextDelegationID()
					delegation := staker.NewDelegation(
						delegationID,
						user,
						delegatee,
						int64(100*(i+1)),
						100,
						100,
					)
					gs.addDelegation(delegationID, delegation)
					delegationIDs = append(delegationIDs, delegationID)
				}
				return user, delegatee, delegationIDs
			},
			expectedCount: 10,
		},
		{
			name: "Delegations with varying amounts including zero undelegated amount",
			setupState: func(gs *govStakerV1) (address, address, []int64) {
				user := address("g1mixeduser1234567890abcdefghijklmno")
				delegatee := address("g1mixedvalidator1234567890abcdefgh")
				delegationIDs := make([]int64, 0)

				// Add delegation with normal amounts
				delegationID1 := gs.nextDelegationID()
				delegation1 := staker.NewDelegation(
					delegationID1,
					user,
					delegatee,
					5000,
					100,
					100,
				)
				gs.addDelegation(delegationID1, delegation1)
				delegationIDs = append(delegationIDs, delegationID1)

				// Add delegation with small amount
				delegationID2 := gs.nextDelegationID()
				delegation2 := staker.NewDelegation(
					delegationID2,
					user,
					delegatee,
					1,
					100,
					100,
				)
				gs.addDelegation(delegationID2, delegation2)
				delegationIDs = append(delegationIDs, delegationID2)

				// Add delegation with large amount
				delegationID3 := gs.nextDelegationID()
				delegation3 := staker.NewDelegation(
					delegationID3,
					user,
					delegatee,
					1000000,
					100,
					100,
				)
				gs.addDelegation(delegationID3, delegation3)
				delegationIDs = append(delegationIDs, delegationID3)

				return user, delegatee, delegationIDs
			},
			expectedCount: 3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// Given: Setup state
			user, delegatee, expectedDelegationIDs := tt.setupState(gs)

			// When: Get user delegations with delegatee
			delegationIDs := gs.getUserDelegationIDsWithDelegatee(user, delegatee)

			// Then: Should return expected count
			uassert.Equal(t, len(delegationIDs), tt.expectedCount)

			// Then: All delegations should belong to the user and delegatee
			for _, id := range delegationIDs {
				delegation, exists := gs.store.GetDelegation(id)
				if !exists {
					continue
				}

				uassert.Equal(t, delegation.DelegateFrom(), user)
				uassert.Equal(t, delegation.DelegateTo(), delegatee)
			}

			// Then: Verify all expected delegation IDs are present
			if tt.expectedCount > 0 {
				foundIDs := make(map[int64]bool)
				for _, id := range delegationIDs {
					delegation, exists := gs.store.GetDelegation(id)
					if !exists {
						continue
					}

					foundIDs[delegation.ID()] = true
				}

				for _, expectedID := range expectedDelegationIDs {
					uassert.True(t, foundIDs[expectedID])
				}
			}
		})
	}
}

// Test getUserDelegations with comprehensive edge cases and scenarios
func TestGetUserDelegationsComprehensive(t *testing.T) {
	tests := []struct {
		name          string
		setupState    func(gs *govStakerV1) (address, map[address]int)
		expectedTotal int
	}{
		{
			name: "User with delegations to multiple different delegatees",
			setupState: func(gs *govStakerV1) (address, map[address]int) {
				user := address("g1multiuser1234567890abcdefghijklmno")
				delegateeCounts := make(map[address]int)

				// Add delegations to 3 different delegatees
				delegatees := []address{
					address("g1validator1111111111abcdefghijklm"),
					address("g1validator2222222222abcdefghijklm"),
					address("g1validator3333333333abcdefghijklm"),
				}

				for _, delegatee := range delegatees {
					count := 2 // 2 delegations per delegatee
					for i := 0; i < count; i++ {
						delegationID := gs.nextDelegationID()
						delegation := staker.NewDelegation(
							delegationID,
							user,
							delegatee,
							int64(1000*(i+1)),
							100,
							100,
						)
						gs.addDelegation(delegationID, delegation)
					}
					delegateeCounts[delegatee] = count
				}

				return user, delegateeCounts
			},
			expectedTotal: 6,
		},
		{
			name: "User with single delegation to single delegatee",
			setupState: func(gs *govStakerV1) (address, map[address]int) {
				user := address("g1singleuser1234567890abcdefghijklm")
				delegatee := address("g1validator4444444444abcdefghijklm")
				delegateeCounts := make(map[address]int)

				delegationID := gs.nextDelegationID()
				delegation := staker.NewDelegation(
					delegationID,
					user,
					delegatee,
					5000,
					100,
					100,
				)
				gs.addDelegation(delegationID, delegation)
				delegateeCounts[delegatee] = 1

				return user, delegateeCounts
			},
			expectedTotal: 1,
		},
		{
			name: "User with many delegations to many delegatees",
			setupState: func(gs *govStakerV1) (address, map[address]int) {
				user := address("g1heavyuser1234567890abcdefghijklmn")
				delegateeCounts := make(map[address]int)

				// 5 delegatees with varying numbers of delegations
				delegateesWithCounts := []struct {
					addr  address
					count int
				}{
					{address("g1validator5555555555abcdefghijklm"), 3},
					{address("g1validator6666666666abcdefghijklm"), 2},
					{address("g1validator7777777777abcdefghijklm"), 4},
					{address("g1validator8888888888abcdefghijklm"), 1},
					{address("g1validator9999999999abcdefghijklm"), 5},
				}

				totalDelegations := 0
				for _, dc := range delegateesWithCounts {
					for i := 0; i < dc.count; i++ {
						delegationID := gs.nextDelegationID()
						delegation := staker.NewDelegation(
							delegationID,
							user,
							dc.addr,
							int64(500*(i+1)),
							100,
							100,
						)
						gs.addDelegation(delegationID, delegation)
						totalDelegations++
					}
					delegateeCounts[dc.addr] = dc.count
				}

				return user, delegateeCounts
			},
			expectedTotal: 15,
		},
		{
			name: "User with no delegations - empty state",
			setupState: func(gs *govStakerV1) (address, map[address]int) {
				user := address("g1emptyuser1234567890abcdefghijklmn")
				return user, make(map[address]int)
			},
			expectedTotal: 0,
		},
		{
			name: "User with delegations after some are removed",
			setupState: func(gs *govStakerV1) (address, map[address]int) {
				user := address("g1removeduser1234567890abcdefghijklm")
				delegatee := address("g1validator1010101010abcdefghijklm")
				delegateeCounts := make(map[address]int)

				// Add 5 delegations
				delegationIDs := make([]int64, 0)
				for i := 0; i < 5; i++ {
					delegationID := gs.nextDelegationID()
					delegation := staker.NewDelegation(
						delegationID,
						user,
						delegatee,
						int64(1000*(i+1)),
						100,
						100,
					)
					gs.addDelegation(delegationID, delegation)
					delegationIDs = append(delegationIDs, delegationID)
				}

				// Remove 2 delegations
				gs.removeDelegation(delegationIDs[1])
				gs.removeDelegation(delegationIDs[3])

				delegateeCounts[delegatee] = 3
				return user, delegateeCounts
			},
			expectedTotal: 3,
		},
		{
			name: "Multiple users - verify isolation",
			setupState: func(gs *govStakerV1) (address, map[address]int) {
				targetUser := address("g1targetuser1234567890abcdefghijklm")
				otherUser1 := address("g1otheruser1111111111abcdefghijklm")
				otherUser2 := address("g1otheruser2222222222abcdefghijklm")
				delegatee := address("g1sharedvalidator1234567890abcdefg")
				delegateeCounts := make(map[address]int)

				// Add delegations for target user (should be returned)
				for i := 0; i < 3; i++ {
					delegationID := gs.nextDelegationID()
					delegation := staker.NewDelegation(
						delegationID,
						targetUser,
						delegatee,
						int64(1000*(i+1)),
						100,
						100,
					)
					gs.addDelegation(delegationID, delegation)
				}
				delegateeCounts[delegatee] = 3

				// Add delegations for other users (should NOT be returned)
				for i := 0; i < 2; i++ {
					delegationID := gs.nextDelegationID()
					delegation := staker.NewDelegation(
						delegationID,
						otherUser1,
						delegatee,
						int64(500*(i+1)),
						100,
						100,
					)
					gs.addDelegation(delegationID, delegation)
				}

				delegationID := gs.nextDelegationID()
				delegation := staker.NewDelegation(
					delegationID,
					otherUser2,
					delegatee,
					2000,
					100,
					100,
				)
				gs.addDelegation(delegationID, delegation)

				return targetUser, delegateeCounts
			},
			expectedTotal: 3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create test instance
			gs := createTestGovStaker()

			// Given: Setup state
			user, delegateeCounts := tt.setupState(gs)

			// When: Get all user delegations
			delegations := gs.getUserDelegations(user)

			// Then: Should return expected total count
			uassert.Equal(t, countDelegationIDs(delegations), tt.expectedTotal)

			// Then: All delegations should belong to the user
			delegations.Iterate("", "", func(delegatee string, value interface{}) bool {
				delegationIDs, ok := value.([]int64)
				if !ok {
					return false
				}

				for _, id := range delegationIDs {
					delegation, exists := gs.store.GetDelegation(id)
					if !exists {
						continue
					}

					uassert.Equal(t, delegation.DelegateFrom(), user)
				}

				return false
			})

			// Then: Verify delegations are grouped correctly by delegatee
			if tt.expectedTotal > 0 {
				delegateeCount := make(map[address]int)
				delegations.Iterate("", "", func(delegatee string, value interface{}) bool {
					delegationIDs, ok := value.([]int64)
					if !ok {
						return false
					}

					for _, id := range delegationIDs {
						delegation, exists := gs.store.GetDelegation(id)
						if !exists {
							continue
						}

						delegateeCount[delegation.DelegateTo()]++
					}

					return false
				})

				// Verify counts match expected
				for delegatee, expectedCount := range delegateeCounts {
					actualCount, exists := delegateeCount[delegatee]
					uassert.True(t, exists)
					uassert.Equal(t, actualCount, expectedCount)
				}
			}
		})
	}
}
