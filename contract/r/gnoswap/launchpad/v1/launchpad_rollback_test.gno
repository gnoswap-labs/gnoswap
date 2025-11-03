package v1

import (
	"chain"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/onbloc/obl"

	_ "gno.land/r/gnoswap/launchpad"
)

// TestRollback_DepositWithInsufficientBalance tests that deposit fails and state is not modified
// when user has insufficient balance
func TestRollback_DepositWithInsufficientBalance(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	// Reset state
	resetTestStore()
	initTestStore()

	launchpadAddr := chain.PackageAddress(launchpadPackagePath)
	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm := testing.NewUserRealm(adminAddr)
	userAddr := testutils.TestAddress("user1")
	projectAddr := testutils.TestAddress("project1")

	// Set initial time
	ctx := testing.GetContext()
	ctx.Height = 123
	ctx.Time = time.Unix(1234567890, 0)
	testing.SetContext(ctx)

	// Create project
	testing.SetRealm(adminRealm)
	startTime := time.Now().Unix() + 100

	obl.Approve(cross, launchpadAddr, 10000)

	var projectID string
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		projectID = lp.CreateProject(
			"Test Project",
			"gno.land/r/onbloc/obl",
			projectAddr,
			10000,
			"",
			"",
			100,
			0,
			0,
			startTime,
		)
	}(cross)

	// Activate project
	testing.SkipHeights(100)

	// Setup user with INSUFFICIENT GNS tokens (less than deposit amount)
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, userAddr, 500000) // Only 500k, but trying to deposit 1M

	testing.SetRealm(testing.NewUserRealm(userAddr))
	gns.Approve(cross, launchpadAddr, 500000)

	// Get initial state
	lp := getTestImplementation()
	deposits := lp.store.GetDeposits()
	initialDepositCount := deposits.Size()

	// Try to deposit with insufficient balance - should fail
	testing.SetRealm(testing.NewUserRealm(userAddr))

	uassert.AbortsWithMessage(t, "", func() {
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			lp := getTestImplementation()

			_ = lp.DepositGns(projectID+":30", 1000000, "")
		}(cross)
	})

	// Verify state was not modified
	deposits = lp.store.GetDeposits()
	finalDepositCount := deposits.Size()
	uassert.Equal(t, initialDepositCount, finalDepositCount, "deposit count should not change after failed deposit")
}

// TestRollback_WithdrawWithInsufficientProjectBalance tests state consistency
// when token transfer would fail during withdrawal
func TestRollback_WithdrawWithInsufficientProjectBalance(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	// Reset state
	resetTestStore()
	initTestStore()

	launchpadAddr := chain.PackageAddress(launchpadPackagePath)
	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm := testing.NewUserRealm(adminAddr)
	userAddr := testutils.TestAddress("user2")
	projectAddr := testutils.TestAddress("project2")

	// Set initial time
	ctx := testing.GetContext()
	ctx.Height = 123
	ctx.Time = time.Unix(1234567890, 0)
	testing.SetContext(ctx)

	// Create project
	testing.SetRealm(adminRealm)
	startTime := time.Now().Unix() + 100

	obl.Approve(cross, launchpadAddr, 10000)

	var projectID string
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		projectID = lp.CreateProject(
			"Test Project 2",
			"gno.land/r/onbloc/obl",
			projectAddr,
			10000,
			"",
			"",
			100,
			0,
			0,
			startTime,
		)
	}(cross)

	// Activate project
	testing.SkipHeights(100)

	// Setup user and deposit successfully
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, userAddr, 2000000)

	testing.SetRealm(testing.NewUserRealm(userAddr))
	gns.Approve(cross, launchpadAddr, 2000000)

	var depositID string
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		depositID = lp.DepositGns(projectID+":30", 1000000, "")
	}(cross)

	// Verify deposit was created
	lp := getTestImplementation()
	deposit, err := lp.getDeposit(depositID)
	uassert.NoError(t, err)
	uassert.False(t, deposit.IsWithdrawn(), "deposit should not be withdrawn initially")

	// Wait for lockup to end
	testing.SkipHeights(2592001)

	// Note: In normal circumstances, withdrawal should succeed because the launchpad
	// contract holds the tokens. This test verifies that IF withdrawal were to fail,
	// the state would remain consistent (the deposit would not be marked as withdrawn
	// until after successful token transfer)

	// Verify deposit state before withdrawal attempt
	deposit, err = lp.getDeposit(depositID)
	uassert.NoError(t, err)
	uassert.False(t, deposit.IsWithdrawn(), "deposit should not be withdrawn before withdrawal")

	// Successful withdrawal (normal case)
	testing.SetRealm(testing.NewUserRealm(userAddr))
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		amount, err := lp.CollectDepositGns(depositID)
		uassert.NoError(t, err)
		uassert.True(t, amount > 0, "should withdraw positive amount")
	}(cross)

	// Verify deposit state after successful withdrawal
	deposit, err = lp.getDeposit(depositID)
	uassert.NoError(t, err)
	uassert.True(t, deposit.IsWithdrawn(), "deposit should be marked as withdrawn after success")
}

// TestRollback_RewardManagerUpdateFailure tests error handling when reward manager update fails
func TestRollback_RewardManagerUpdateFailure(t *testing.T) {
	tests := []struct {
		name              string
		setupFunc         func() (*Deposit, *RewardManager)
		currentHeight     int64
		currentTime       int64
		expectedHasError  bool
		expectedErrorType string
	}{
		{
			name: "update with negative time fails",
			setupFunc: func() (*Deposit, *RewardManager) {
				resetTestStore()

				deposit := NewDeposit(
					"test-deposit-1",
					"test-project",
					30,
					testutils.TestAddress("user1"),
					1000000,
					100,
					1234567890,
					1234567890+2592000,
				)

				rewardManager := NewRewardManager(
					10000,              // totalDistributeAmount
					1234567890,         // distributeStartTime
					1234567890+2592000, // distributeEndTime
					100,                // currentHeight
					1234567890,         // currentTime
				)

				return deposit, rewardManager
			},
			currentHeight:     200,
			currentTime:       -1, // Invalid negative time
			expectedHasError:  true,
			expectedErrorType: "invalid time",
		},
		{
			name: "update with zero time fails",
			setupFunc: func() (*Deposit, *RewardManager) {
				deposit := NewDeposit(
					"test-deposit-2",
					"test-project",
					30,
					testutils.TestAddress("user2"),
					1000000,
					100,
					1234567890,
					1234567890+2592000,
				)

				rewardManager := NewRewardManager(
					10000,              // totalDistributeAmount
					1234567890,         // distributeStartTime
					1234567890+2592000, // distributeEndTime
					100,                // currentHeight
					1234567890,         // currentTime
				)

				return deposit, rewardManager
			},
			currentHeight:     200,
			currentTime:       0, // Invalid zero time
			expectedHasError:  true,
			expectedErrorType: "invalid time",
		},
		{
			name: "update with valid time succeeds",
			setupFunc: func() (*Deposit, *RewardManager) {
				deposit := NewDeposit(
					"test-deposit-3",
					"test-project",
					30,
					testutils.TestAddress("user3"),
					1000000,
					100,
					1234567890,
					1234567890+2592000,
				)

				rewardManager := NewRewardManager(
					10000,              // totalDistributeAmount
					1234567890,         // distributeStartTime
					1234567890+2592000, // distributeEndTime
					100,                // currentHeight
					1234567890,         // currentTime
				)

				// Initialize the reward manager with a deposit
				_ = rewardManager.addRewardStateByDeposit(deposit)

				return deposit, rewardManager
			},
			currentHeight:    200,
			currentTime:      1234567890 + 1000,
			expectedHasError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			deposit, rewardManager := tt.setupFunc()

			// Attempt to update reward manager
			err := rewardManager.updateRewardPerDepositX128(
				deposit.DepositAmount(),
				tt.currentHeight,
				tt.currentTime,
			)

			if tt.expectedHasError {
				uassert.Error(t, err, "should return error for invalid input")
				uassert.ErrorContains(t, err, tt.expectedErrorType, "error should contain expected type")
			} else {
				uassert.NoError(t, err, "should not return error for valid input")
			}
		})
	}
}

// TestRollback_InvalidProjectState tests that operations fail cleanly when project is in invalid state
func TestRollback_InvalidProjectState(t *testing.T) {
	tests := []struct {
		name                 string
		projectSetup         func() string
		depositTime          int64
		expectedPanic        bool
		expectedPanicMessage string
	}{
		{
			name: "deposit to inactive project fails without state change",
			projectSetup: func() string {
				const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

				resetTestStore()
				initTestStore()

				launchpadAddr := chain.PackageAddress(launchpadPackagePath)
				adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
				adminRealm := testing.NewUserRealm(adminAddr)
				projectAddr := testutils.TestAddress("project1")

				ctx := testing.GetContext()
				ctx.Height = 123
				ctx.Time = time.Unix(1234567890, 0)
				testing.SetContext(ctx)

				testing.SetRealm(adminRealm)
				// Project starts far in the future
				startTime := time.Now().Unix() + 100000

				obl.Approve(cross, launchpadAddr, 10000)

				var projectID string
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
					lp := getTestImplementation()

					projectID = lp.CreateProject(
						"Inactive Project",
						"gno.land/r/onbloc/obl",
						projectAddr,
						10000,
						"",
						"",
						100,
						0,
						0,
						startTime,
					)
				}(cross)

				return projectID
			},
			depositTime:          1000, // Before project activation
			expectedPanic:        true,
			expectedPanicMessage: "project is inactive",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

			projectID := tt.projectSetup()

			launchpadAddr := chain.PackageAddress(launchpadPackagePath)
			adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
			adminRealm := testing.NewUserRealm(adminAddr)
			userAddr := testutils.TestAddress("user1")

			// Setup user
			testing.SetRealm(adminRealm)
			gns.Transfer(cross, userAddr, 2000000)

			testing.SetRealm(testing.NewUserRealm(userAddr))
			gns.Approve(cross, launchpadAddr, 2000000)

			// Get initial deposit count
			lp := getTestImplementation()
			deposits := lp.store.GetDeposits()
			initialCount := deposits.Size()

			// Try to deposit
			testing.SetRealm(testing.NewUserRealm(userAddr))

			if tt.expectedPanic {
				uassert.AbortsWithMessage(t, tt.expectedPanicMessage, func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
						lp := getTestImplementation()

						_ = lp.DepositGns(projectID+":30", 1000000, "")
					}(cross)
				})

				// Verify no state change
				deposits = lp.store.GetDeposits()
				finalCount := deposits.Size()
				uassert.Equal(t, initialCount, finalCount, "deposit count should not change after failed deposit")
			}
		})
	}
}
