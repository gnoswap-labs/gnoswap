package v1

import (
	"chain"
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/xgns"
	"gno.land/r/gnoswap/launchpad"
	"gno.land/r/onbloc/obl"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"
)

func TestLaunchpadWithdraw_CollectDepositGns(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	userAddr := testutils.TestAddress("user1")
	otherAddr := testutils.TestAddress("other")

	launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())

	tests := []struct {
		name                 string
		depositID            string
		callerAddress        address
		expectedHasAbort     bool
		expectedAbortMessage string
		expectedAmount       int64
	}{
		{
			name:             "success - collect deposit gns successfully",
			depositID:        "1",
			callerAddress:    userAddr,
			expectedHasAbort: false,
			expectedAmount:   1000000000,
		},
		{
			name:                 "fail - collect deposit gns with invalid deposit id",
			depositID:            "invalid_deposit",
			callerAddress:        userAddr,
			expectedHasAbort:     true,
			expectedAbortMessage: "[GNOSWAP-LAUNCHPAD-020] not exist deposit || (invalid_deposit)",
		},
		{
			name:                 "fail - collect deposit gns with invalid owner",
			depositID:            "1",
			callerAddress:        otherAddr,
			expectedHasAbort:     true,
			expectedAbortMessage: "[GNOSWAP-LAUNCHPAD-026] invalid owner",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadWithdrawTest(t, userAddr)
			lp := getTestImplementation()

			testing.SetRealm(testing.NewUserRealm(adminAddr))
			gns.Transfer(cross, launchpadAddr, 1000000000)

			testing.SetRealm(testing.NewUserRealm(tt.callerAddress))
			testing.SkipHeights(60*60*24*180/5 + 2)

			if tt.expectedHasAbort {
				collectDepositFn := func() {
					func(cur realm) {
						lp.CollectDepositGns(tt.depositID)
					}(cross)
				}
				uassert.AbortsContains(t, tt.expectedAbortMessage, collectDepositFn)
				return
			}

			// Success case
			var amount int64
			var err error
			testing.SetOriginCaller(tt.callerAddress)
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
				amount, err = lp.CollectDepositGns(tt.depositID)
			}(cross)

			testing.SkipHeights(-(60*60*24*180/5 + 2))
			uassert.NoError(t, err)
			uassert.Equal(t, tt.expectedAmount, amount)
		})
	}
}

func TestLaunchpadWithdraw_CollectDepositGnsUnauthorized(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	initLaunchpadWithdrawTest(t, testutils.TestAddress("user"))
	lp := getTestImplementation()

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/test/contract"))

	uassert.AbortsWithMessage(t, "caller is not user", func() {
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			lp.CollectDepositGns("1")
		}(cross)
	})
}

// TestLaunchpadWithdraw_WithdrawDeposit tests the withdrawDeposit function
// including both success and error cases across different tier durations.
func TestLaunchpadWithdraw_WithdrawDeposit(t *testing.T) {
	userAddr := testutils.TestAddress("user_withdraw")

	// Skip heights constants for different tier durations
	// Formula: seconds_in_period / 5 (block time) + buffer
	const (
		skipHeightTier30  = 60*60*24*30/5 + 2  // 30 days
		skipHeightTier90  = 60*60*24*90/5 + 2  // 90 days
		skipHeightTier180 = 60*60*24*180/5 + 2 // 180 days
		depositAmount     = int64(1000000000)
	)

	tests := []struct {
		name           string
		tierDuration   int64
		skipHeights    int64
		useNilDeposit  bool
		currentTime    func() int64
		withdrawTwice  bool
		expectedErr    bool
		expectedErrMsg string
		expectedAmount int64
	}{
		// Success cases for different tiers
		{
			name:           "success - withdraw tier 30 deposit after tier ends",
			tierDuration:   30,
			skipHeights:    skipHeightTier30,
			useNilDeposit:  false,
			currentTime:    func() int64 { return time.Now().Unix() },
			withdrawTwice:  false,
			expectedErr:    false,
			expectedAmount: depositAmount,
		},
		{
			name:           "success - withdraw tier 90 deposit after tier ends",
			tierDuration:   90,
			skipHeights:    skipHeightTier90,
			useNilDeposit:  false,
			currentTime:    func() int64 { return time.Now().Unix() },
			withdrawTwice:  false,
			expectedErr:    false,
			expectedAmount: depositAmount,
		},
		{
			name:           "success - withdraw tier 180 deposit after tier ends",
			tierDuration:   180,
			skipHeights:    skipHeightTier180,
			useNilDeposit:  false,
			currentTime:    func() int64 { return time.Now().Unix() },
			withdrawTwice:  false,
			expectedErr:    false,
			expectedAmount: depositAmount,
		},
		// Error cases
		{
			name:           "fail - tier 30 deposit not yet ended",
			tierDuration:   30,
			skipHeights:    0,
			useNilDeposit:  false,
			currentTime:    func() int64 { return time.Now().Unix() },
			withdrawTwice:  false,
			expectedErr:    true,
			expectedErrMsg: "project lock period is not over yet",
		},
		{
			name:           "fail - tier 90 deposit not yet ended (only 30 days passed)",
			tierDuration:   90,
			skipHeights:    skipHeightTier30, // Only skip 30 days, not enough for 90-day tier
			useNilDeposit:  false,
			currentTime:    func() int64 { return time.Now().Unix() },
			withdrawTwice:  false,
			expectedErr:    true,
			expectedErrMsg: "project lock period is not over yet",
		},
		{
			name:           "fail - deposit already withdrawn",
			tierDuration:   30,
			skipHeights:    skipHeightTier30,
			useNilDeposit:  false,
			currentTime:    func() int64 { return time.Now().Unix() },
			withdrawTwice:  true,
			expectedErr:    true,
			expectedErrMsg: "already collected",
		},
		{
			name:           "fail - invalid currentTime zero",
			tierDuration:   30,
			skipHeights:    skipHeightTier30,
			useNilDeposit:  false,
			currentTime:    func() int64 { return 0 },
			withdrawTwice:  false,
			expectedErr:    true,
			expectedErrMsg: "currentTime must be positive",
		},
		{
			name:           "fail - invalid currentTime negative",
			tierDuration:   30,
			skipHeights:    skipHeightTier30,
			useNilDeposit:  false,
			currentTime:    func() int64 { return -100 },
			withdrawTwice:  false,
			expectedErr:    true,
			expectedErrMsg: "currentTime must be positive",
		},
		{
			name:           "fail - nil deposit",
			tierDuration:   30,
			skipHeights:    0,
			useNilDeposit:  true,
			currentTime:    func() int64 { return time.Now().Unix() },
			withdrawTwice:  false,
			expectedErr:    true,
			expectedErrMsg: "deposit is nil",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadWithdrawTestWithTier(t, userAddr, tt.tierDuration)
			lp := getTestImplementation()

			if tt.skipHeights > 0 {
				testing.SkipHeights(tt.skipHeights)
			}

			var deposit *launchpad.Deposit
			var err error

			if !tt.useNilDeposit {
				deposit, err = getDeposit("1")
				uassert.NoError(t, err)
			}

			currentTime := tt.currentTime()

			if tt.withdrawTwice {
				// First withdrawal should succeed
				_, _, err = lp.withdrawDeposit(deposit, runtime.ChainHeight(), currentTime)
				uassert.NoError(t, err)

				// Refresh deposit to get updated state
				deposit, err = getDeposit("1")
				uassert.NoError(t, err)
			}

			// Execute withdrawal (or second withdrawal for withdrawTwice case)
			_, amount, err := lp.withdrawDeposit(deposit, runtime.ChainHeight(), currentTime)

			if tt.expectedErr {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, tt.expectedErrMsg)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tt.expectedAmount, amount)
			}
		})
	}
}

func TestLaunchpadWithdraw_CollectDepositGnsTokensRemainLocked(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"
	launchpadAddr := chain.PackageAddress(launchpadPackagePath)

	userAddr := testutils.TestAddress("user3")
	adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())

	initLaunchpadWithdrawTest(t, userAddr)
	lp := getTestImplementation()

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, launchpadAddr, 1000000000)

	// Set caller as user and skip to withdrawal time
	testing.SetRealm(testing.NewUserRealm(userAddr))
	testing.SkipHeights(60*60*24*180/5 + 2)

	userBalanceBefore := gns.BalanceOf(userAddr)
	launchpadBalanceBefore := gns.BalanceOf(launchpadAddr)

	// withdrawal here.
	// this should unstake and return GNS
	var amount int64
	var err error

	testing.SetOriginCaller(userAddr)
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		amount, err = lp.CollectDepositGns("1")
		uassert.NoError(t, err)
		uassert.Equal(t, int64(1000000000), amount)
	}(cross)

	// Check final balances
	userBalanceAfter := gns.BalanceOf(userAddr)
	launchpadBalanceAfter := gns.BalanceOf(launchpadAddr)

	// With the fix, these tests should be passed.
	// 1. User's GNS balance should increase by the deposit amount
	// 2. Launchpad's GNS balance should decrease by the same amount

	t.Run("user_receives_gns_correctly", func(t *testing.T) {
		expectedUserBalance := int64(userBalanceBefore + amount)
		uassert.Equal(t, expectedUserBalance, userBalanceAfter,
			"User should receive GNS tokens back")
	})

	t.Run("launchpad_transfers_gns_correctly", func(t *testing.T) {
		expectedLaunchpadBalance := launchpadBalanceBefore - amount
		uassert.Equal(t, expectedLaunchpadBalance, launchpadBalanceAfter,
			"Launchpad should transfer GNS tokens out")
	})

	t.Run("tokens_are_properly_returned", func(t *testing.T) {
		userBalanceChange := userBalanceAfter - userBalanceBefore
		launchpadBalanceChange := launchpadBalanceAfter - launchpadBalanceBefore

		uassert.Equal(t, amount, userBalanceChange,
			"User balance should increase by withdrawal amount")
		uassert.Equal(t, -amount, launchpadBalanceChange,
			"Launchpad balance should decrease by withdrawal amount")
	})
}

// This test verifies complete balance restoration after deposit and withdrawal
func TestLaunchpadWithdraw_CollectDepositGnsFullBalanceRestoration(t *testing.T) {
	// init test environment
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"
	launchpadAddr := chain.PackageAddress(launchpadPackagePath)

	userAddr := testutils.TestAddress("user4")
	adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())

	testing.SetHeight(123)
	resetTestStore()
	lp := getTestImplementation()

	// Setup test project
	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()

	project, _ := lp.createProject(
		&createProjectParams{
			name:          "Test Project",
			tokenPath:     "gno.land/r/onbloc/obl",
			depositAmount: 1000000,
			tier30Ratio:   30,
			tier90Ratio:   30,
			tier180Ratio:  40,
			recipient:     testutils.TestAddress("project"),
			startTime:     currentTime + 10,
			currentTime:   currentTime,
			currentHeight: currentHeight,
		},
	)

	projects := lp.store.GetProjects()
	projects.Set(project.ID(), project)
	lp.store.SetProjects(projects)

	testing.SkipHeights(10)

	// Give user initial GNS balance
	initialUserBalance := int64(5000000000) // 5000 GNS
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, userAddr, initialUserBalance)

	// Record initial balance
	userBalanceBeforeDeposit := gns.BalanceOf(userAddr)
	uassert.Equal(t, initialUserBalance, userBalanceBeforeDeposit, "Initial balance should match transferred amount")

	// User deposits GNS
	depositAmount := int64(1000000000) // 1000 GNS
	testing.SetOriginCaller(userAddr)

	// Need to approve GNS before deposit
	testing.SetRealm(testing.NewUserRealm(userAddr))
	gns.Approve(cross, launchpadAddr, depositAmount)

	// Use public DepositGns function to properly handle token transfer
	var depositID string
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		depositID = lp.DepositGns(project.ID()+":30", depositAmount, "")
	}(cross)

	// Check balance after deposit
	userBalanceAfterDeposit := gns.BalanceOf(userAddr)
	expectedBalanceAfterDeposit := initialUserBalance - depositAmount
	uassert.Equal(t, expectedBalanceAfterDeposit, userBalanceAfterDeposit,
		"User balance should decrease by deposit amount")

	// Setup governance staking (simulating what happens in real scenario)
	govStakerAddr, _ := access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm := testing.NewUserRealm(govStakerAddr)
	testing.SetRealm(govStakerRealm)
	xgns.Mint(cross, launchpadAddr, depositAmount)

	// Give launchpad GNS for withdrawal
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, launchpadAddr, depositAmount)

	// Skip to end of tier period
	projectTier, _ := getProjectTier(project, 30)
	testing.SetHeight(projectTier.EndTime() + 1)
	testing.SkipHeights(60*60*24*180/5 + 2)

	// Perform withdrawal
	testing.SetRealm(testing.NewUserRealm(userAddr))
	var withdrawnAmount int64
	var err error
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		withdrawnAmount, err = lp.CollectDepositGns(depositID)
	}(cross)
	uassert.NoError(t, err)
	uassert.Equal(t, depositAmount, withdrawnAmount, "Withdrawn amount should match deposit")

	// Verify complete balance restoration
	userBalanceFinal := gns.BalanceOf(userAddr)

	t.Run("exact_balance_restoration", func(t *testing.T) {
		// User should have exactly the initial balance after withdrawal
		uassert.Equal(t, initialUserBalance, userBalanceFinal,
			"User balance should be fully restored to initial amount")
	})

	t.Run("deposit_withdrawal_symmetry", func(t *testing.T) {
		// The amount lost during deposit should equal amount gained during withdrawal
		depositLoss := userBalanceBeforeDeposit - userBalanceAfterDeposit
		withdrawalGain := userBalanceFinal - userBalanceAfterDeposit

		uassert.Equal(t, depositLoss, withdrawalGain,
			"Deposit loss should equal withdrawal gain")
		uassert.Equal(t, depositAmount, depositLoss,
			"Deposit loss should equal deposit amount")
		uassert.Equal(t, withdrawnAmount, withdrawalGain,
			"Withdrawal gain should equal withdrawn amount")
	})

	t.Run("verify_no_tokens_lost", func(t *testing.T) {
		netChange := userBalanceFinal - userBalanceBeforeDeposit
		uassert.Equal(t, int64(0), netChange,
			"Net change in user balance should be zero (no tokens lost)")
	})
}

// TestLaunchpadWithdraw_RewardStateRemoval tests that reward state is removed after withdrawal
func TestLaunchpadWithdraw_RewardStateRemoval(t *testing.T) {
	tests := []struct {
		name                          string
		depositID                     string
		tierDuration                  int64
		skipHeight                    int64
		expectedRewardStateSizeAfter  int
		expectedRewardStateAccessible bool
	}{
		{
			name:                          "single deposit - reward state removed after withdrawal",
			depositID:                     "1",
			tierDuration:                  30,
			skipHeight:                    60*60*24*180/5 + 2,
			expectedRewardStateSizeAfter:  0,
			expectedRewardStateAccessible: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			userAddr := testutils.TestAddress("user5")
			initLaunchpadWithdrawTest(t, userAddr)
			lp := getTestImplementation()

			// Get deposit to retrieve project info
			deposit, _ := getDeposit(tt.depositID)
			projectID := deposit.ProjectID()
			tierDuration := deposit.Tier()

			// Get project and tier
			project, _ := lp.getProject(projectID)
			projectTier, _ := getProjectTier(project, tierDuration)
			tierID := projectTier.ID()

			// Verify reward state exists before withdrawal
			rewardManagerBefore, err := lp.getProjectTierRewardManager(tierID)
			uassert.NoError(t, err)
			initialRewardsSize := rewardManagerBefore.Rewards().Size()
			uassert.True(t, initialRewardsSize > 0, "reward state should exist before withdrawal")

			// Verify reward state is accessible before withdrawal
			_, err = getDepositRewardState(rewardManagerBefore, tt.depositID)
			uassert.NoError(t, err, "reward state should be accessible before withdrawal")

			// Perform withdrawal
			testing.SkipHeights(tt.skipHeight)
			currentTime := time.Now().Unix()
			_, _, err = lp.withdrawDeposit(deposit, runtime.ChainHeight(), currentTime)
			uassert.NoError(t, err)

			// Verify reward state is removed after withdrawal
			rewardManagerAfter, _ := lp.getProjectTierRewardManager(tierID)
			afterRewardsSize := rewardManagerAfter.Rewards().Size()
			uassert.Equal(t, tt.expectedRewardStateSizeAfter, afterRewardsSize)

			// Verify reward state accessibility after withdrawal
			_, err = getDepositRewardState(rewardManagerAfter, tt.depositID)
			if tt.expectedRewardStateAccessible {
				uassert.NoError(t, err)
			} else {
				uassert.Error(t, err, "reward state should not be accessible after withdrawal")
			}
		})
	}
}

// TestLaunchpadWithdraw_RewardStateRemovalWithMultipleDeposits tests reward state removal
// when multiple deposits exist in the same tier
func TestLaunchpadWithdraw_RewardStateRemovalWithMultipleDeposits(t *testing.T) {
	tests := []struct {
		name                         string
		numDeposits                  int
		withdrawDepositIndex         int
		skipHeight                   int64
		expectedRewardStateSizeAfter int
	}{
		{
			name:                         "withdraw first deposit - second deposit reward state remains",
			numDeposits:                  2,
			withdrawDepositIndex:         0,
			skipHeight:                   60*60*24*180/5 + 2,
			expectedRewardStateSizeAfter: 1,
		},
		{
			name:                         "withdraw second deposit - first deposit reward state remains",
			numDeposits:                  2,
			withdrawDepositIndex:         1,
			skipHeight:                   60*60*24*180/5 + 2,
			expectedRewardStateSizeAfter: 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetHeight(123)
			resetTestStore()
			lp := getTestImplementation()

			// Setup project
			currentTime := time.Now().Unix()
			currentHeight := runtime.ChainHeight()

			project, _ := lp.createProject(&createProjectParams{
				name:          "Test Project",
				tokenPath:     "gno.land/r/onbloc/obl",
				depositAmount: 1000000,
				tier30Ratio:   30,
				tier90Ratio:   30,
				tier180Ratio:  40,
				recipient:     testutils.TestAddress("project"),
				startTime:     currentTime + 10,
				currentTime:   currentTime,
				currentHeight: currentHeight,
			})
			projects := lp.store.GetProjects()
			projects.Set(project.ID(), project)
			lp.store.SetProjects(projects)

			testing.SkipHeights(10)

			// Create multiple deposits
			depositIDs := make([]string, tt.numDeposits)
			depositAmount := int64(1000000000)

			for i := 0; i < tt.numDeposits; i++ {
				userAddr := testutils.TestAddress("multiuser" + formatInt(int64(i)))
				testing.SetOriginCaller(userAddr)
				deposit, _, _, _, _ := lp.depositGns(project, 30, depositAmount, userAddr)
				depositIDs[i] = deposit.ID()
			}

			// Setup xgns for each deposit
			govStakerAddr, _ := access.GetAddress(prbac.ROLE_GOV_STAKER.String())
			launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
			govStakerRealm := testing.NewUserRealm(govStakerAddr)
			testing.SetRealm(govStakerRealm)
			xgns.Mint(cross, launchpadAddr, depositAmount*int64(tt.numDeposits))

			// Skip to end of tier
			projectTier, _ := getProjectTier(project, 30)
			testing.SetHeight(projectTier.EndTime() + 1)
			testing.SkipHeights(tt.skipHeight)

			// Get tier ID
			tierID := projectTier.ID()

			// Verify initial reward state count
			rewardManagerBefore, _ := lp.getProjectTierRewardManager(tierID)
			uassert.Equal(t, tt.numDeposits, rewardManagerBefore.Rewards().Size())

			// Withdraw specific deposit
			withdrawDepositID := depositIDs[tt.withdrawDepositIndex]
			deposit, _ := getDeposit(withdrawDepositID)
			currentTime = time.Now().Unix()
			_, _, err := lp.withdrawDeposit(deposit, runtime.ChainHeight(), currentTime)
			uassert.NoError(t, err)

			// Verify reward state count after withdrawal
			rewardManagerAfter, _ := lp.getProjectTierRewardManager(tierID)
			uassert.Equal(t, tt.expectedRewardStateSizeAfter, rewardManagerAfter.Rewards().Size())

			// Verify withdrawn deposit's reward state is removed
			_, err = getDepositRewardState(rewardManagerAfter, withdrawDepositID)
			uassert.Error(t, err, "withdrawn deposit reward state should be removed")

			// Verify other deposits' reward states still exist
			for i, id := range depositIDs {
				if i != tt.withdrawDepositIndex {
					_, err = getDepositRewardState(rewardManagerAfter, id)
					uassert.NoError(t, err, "non-withdrawn deposit reward state should remain")
				}
			}
		})
	}
}

func TestLaunchpadWithdraw_CollectDepositGnsEdgeCases(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	userAddr := testutils.TestAddress("edge_user")
	otherAddr := testutils.TestAddress("edge_other")

	launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())

	t.Run("fail - empty deposit ID", func(t *testing.T) {
		initLaunchpadWithdrawTest(t, userAddr)
		lp := getTestImplementation()

		testing.SetRealm(testing.NewUserRealm(adminAddr))
		gns.Transfer(cross, launchpadAddr, 1000000000)

		testing.SetRealm(testing.NewUserRealm(userAddr))
		testing.SkipHeights(60*60*24*180/5 + 2)

		uassert.AbortsContains(t, "not exist deposit", func() {
			func(cur realm) {
				lp.CollectDepositGns("")
			}(cross)
		})
	})

	t.Run("fail - double collection attempt", func(t *testing.T) {
		initLaunchpadWithdrawTest(t, userAddr)
		lp := getTestImplementation()

		testing.SetRealm(testing.NewUserRealm(adminAddr))
		gns.Transfer(cross, launchpadAddr, 2000000000) // Extra for second attempt
		obl.Transfer(cross, launchpadAddr, 2000000000)

		testing.SetRealm(testing.NewUserRealm(userAddr))
		testing.SkipHeights(60*60*24*180/5 + 2)

		// First collection should succeed
		var firstAmount int64
		var firstErr error
		testing.SetOriginCaller(userAddr)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			firstAmount, firstErr = lp.CollectDepositGns("1")
		}(cross)
		uassert.NoError(t, firstErr)
		uassert.Equal(t, int64(1000000000), firstAmount)

		// Second collection should fail
		testing.SetRealm(testing.NewUserRealm(userAddr))
		uassert.AbortsContains(t, "not exist deposit", func() {
			testing.SetOriginCaller(userAddr)
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
				lp.CollectDepositGns("1")
			}(cross)
		})
	})

	t.Run("fail - collection before tier ends", func(t *testing.T) {
		initLaunchpadWithdrawTest(t, userAddr)
		lp := getTestImplementation()

		testing.SetRealm(testing.NewUserRealm(adminAddr))
		gns.Transfer(cross, launchpadAddr, 1000000000)
		obl.Transfer(cross, launchpadAddr, 1000000000)

		// Don't skip heights - tier hasn't ended yet
		testing.SkipHeights(60*60*24*3/5 + 2)
		testing.SetRealm(testing.NewUserRealm(userAddr))

		uassert.AbortsContains(t, "project lock period is not over yet", func() {
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
				lp.CollectDepositGns("1")
			}(cross)
		})
	})

	t.Run("fail - collection with numeric but invalid deposit ID", func(t *testing.T) {
		initLaunchpadWithdrawTest(t, userAddr)
		lp := getTestImplementation()

		testing.SetRealm(testing.NewUserRealm(adminAddr))
		gns.Transfer(cross, launchpadAddr, 1000000000)

		testing.SetRealm(testing.NewUserRealm(userAddr))
		testing.SkipHeights(60*60*24*180/5 + 2)

		uassert.AbortsContains(t, "not exist deposit", func() {
			func(cur realm) {
				lp.CollectDepositGns("99999")
			}(cross)
		})
	})

	t.Run("fail - collection with special characters in deposit ID", func(t *testing.T) {
		initLaunchpadWithdrawTest(t, userAddr)
		lp := getTestImplementation()

		testing.SetRealm(testing.NewUserRealm(adminAddr))
		gns.Transfer(cross, launchpadAddr, 1000000000)

		testing.SetRealm(testing.NewUserRealm(userAddr))
		testing.SkipHeights(60*60*24*180/5 + 2)

		uassert.AbortsContains(t, "not exist deposit", func() {
			func(cur realm) {
				lp.CollectDepositGns("1; DROP TABLE deposits;--")
			}(cross)
		})
	})

	t.Run("success - collection at exact end time boundary", func(t *testing.T) {
		initLaunchpadWithdrawTest(t, userAddr)
		lp := getTestImplementation()

		testing.SetRealm(testing.NewUserRealm(adminAddr))
		gns.Transfer(cross, launchpadAddr, 1000000000)

		// Get the exact tier end time
		deposit, _ := getDeposit("1")
		project, _ := lp.getProject(deposit.ProjectID())
		projectTier, _ := getProjectTier(project, deposit.Tier())

		// Skip to exactly one block after end time
		blocksToEnd := (projectTier.EndTime() - time.Now().Unix()) / 5
		if blocksToEnd > 0 {
			testing.SkipHeights(blocksToEnd + 1)
		}

		testing.SetRealm(testing.NewUserRealm(userAddr))

		var amount int64
		var err error
		testing.SetOriginCaller(userAddr)
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			amount, err = lp.CollectDepositGns("1")
		}(cross)

		uassert.NoError(t, err)
		uassert.Equal(t, int64(1000000000), amount)
	})

	t.Run("fail - collection by different user than depositor", func(t *testing.T) {
		initLaunchpadWithdrawTest(t, userAddr)
		lp := getTestImplementation()

		testing.SetRealm(testing.NewUserRealm(adminAddr))
		gns.Transfer(cross, launchpadAddr, 1000000000)

		testing.SetRealm(testing.NewUserRealm(otherAddr))
		testing.SkipHeights(60*60*24*180/5 + 2)

		uassert.AbortsContains(t, "invalid owner", func() {
			func(cur realm) {
				lp.CollectDepositGns("1")
			}(cross)
		})
	})
}

func TestLaunchpadWithdraw_CollectDepositGnsMultipleTiers(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())

	tierTests := []struct {
		name         string
		tierDuration int64
		skipHeight   int64
	}{
		{
			name:         "tier 30 collection",
			tierDuration: 30,
			skipHeight:   60*60*24*30/5 + 2,
		},
		{
			name:         "tier 90 collection",
			tierDuration: 90,
			skipHeight:   60*60*24*90/5 + 2,
		},
		{
			name:         "tier 180 collection",
			tierDuration: 180,
			skipHeight:   60*60*24*180/5 + 2,
		},
	}

	for _, tt := range tierTests {
		t.Run(tt.name, func(t *testing.T) {
			userAddr := testutils.TestAddress("tier_user_" + formatInt(tt.tierDuration))
			initLaunchpadWithdrawTestWithTier(t, userAddr, tt.tierDuration)
			lp := getTestImplementation()

			testing.SetRealm(testing.NewUserRealm(adminAddr))
			gns.Transfer(cross, launchpadAddr, 1000000000)

			testing.SetRealm(testing.NewUserRealm(userAddr))
			testing.SkipHeights(tt.skipHeight)

			var amount int64
			var err error
			testing.SetOriginCaller(userAddr)
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
				amount, err = lp.CollectDepositGns("1")
			}(cross)

			uassert.NoError(t, err)
			uassert.Equal(t, int64(1000000000), amount)
		})
	}
}

func TestLaunchpadWithdraw_CollectDepositGnsPartialTimeElapsed(t *testing.T) {
	partialTests := []struct {
		name         string
		tierDuration int64
		skipHeight   int64
		shouldFail   bool
	}{
		{
			name:         "tier 90 - only 30 days elapsed",
			tierDuration: 90,
			skipHeight:   60*60*24*30/5 + 2,
			shouldFail:   true,
		},
		{
			name:         "tier 180 - only 90 days elapsed",
			tierDuration: 180,
			skipHeight:   60*60*24*90/5 + 2,
			shouldFail:   true,
		},
		{
			name:         "tier 180 - only 30 days elapsed",
			tierDuration: 180,
			skipHeight:   60*60*24*30/5 + 2,
			shouldFail:   true,
		},
		{
			name:         "tier 30 - only 29 days elapsed",
			tierDuration: 30,
			skipHeight:   (60 * 60 * 24 * 29 / 5),
			shouldFail:   true,
		},
	}

	for _, tt := range partialTests {
		t.Run(tt.name, func(t *testing.T) {
			userAddr := testutils.TestAddress("partial_user")
			initLaunchpadWithdrawTestWithTier(t, userAddr, tt.tierDuration)
			lp := getTestImplementation()

			launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
			adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())

			testing.SetRealm(testing.NewUserRealm(adminAddr))
			gns.Transfer(cross, launchpadAddr, 1000000000)
			obl.Transfer(cross, launchpadAddr, 1000000000)

			if tt.skipHeight > 0 {
				testing.SkipHeights(tt.skipHeight)
			}

			testing.SetRealm(testing.NewUserRealm(userAddr))

			if tt.shouldFail {
				uassert.AbortsContains(t, "project lock period is not over yet", func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))
						lp.CollectDepositGns("1")
					}(cross)
				})
			}
		})
	}
}

func TestLaunchpadWithdraw_CollectDepositGnsDepositStateTransition(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	userAddr := testutils.TestAddress("state_user")
	launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())

	initLaunchpadWithdrawTest(t, userAddr)
	lp := getTestImplementation()

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, launchpadAddr, 1000000000)

	// Get deposit state before collection
	depositBefore, err := getDeposit("1")
	uassert.NoError(t, err)
	uassert.False(t, depositBefore.IsWithdrawn(), "deposit should not be withdrawn before collection")

	// Skip to end time and collect
	testing.SkipHeights(60*60*24*180/5 + 2)

	testing.SetRealm(testing.NewUserRealm(userAddr))
	testing.SetOriginCaller(userAddr)
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp.CollectDepositGns("1")
	}(cross)

	// Get deposit state after collection
	depositAfter, err := getDeposit("1")
	uassert.NoError(t, err)
	uassert.True(t, depositAfter.IsWithdrawn(), "deposit should be withdrawn after collection")
}

func initLaunchpadWithdrawTest(t *testing.T, depositor address) {
	t.Helper()
	initLaunchpadWithdrawTestWithTier(t, depositor, 30)
}

// initLaunchpadWithdrawTestWithTier initializes the test environment with a specific tier duration.
// tierDuration should be 30, 90, or 180.
func initLaunchpadWithdrawTestWithTier(t *testing.T, depositor address, tierDuration int64) {
	t.Helper()
	testing.SetHeight(123)

	// Reset test store completely
	resetTestStore()

	// Initialize test environment
	lp := getTestImplementation()

	// Setup test project
	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()

	// Setup test project with equal distribution across all tiers
	project, _ := lp.createProject(
		&createProjectParams{
			name:          "Test Project",
			tokenPath:     "gno.land/r/onbloc/obl",
			depositAmount: 1000000,
			tier30Ratio:   34,
			tier90Ratio:   33,
			tier180Ratio:  33,
			recipient:     testutils.TestAddress("project"),
			startTime:     currentTime + 10,
			currentTime:   currentTime,
			currentHeight: currentHeight,
		},
	)
	projects := lp.store.GetProjects()
	projects.Set(project.ID(), project)
	lp.store.SetProjects(projects)

	testing.SkipHeights(10)

	depositAmount := int64(1000000000)

	testing.SetOriginCaller(depositor)
	lp.depositGns(project, tierDuration, depositAmount, depositor)

	govStakerAddr, _ := access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm := testing.NewUserRealm(govStakerAddr)
	testing.SetRealm(govStakerRealm)

	launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	xgns.Mint(cross, launchpadAddr, depositAmount)

	projectTier, _ := getProjectTier(project, tierDuration)
	testing.SetHeight(projectTier.EndTime() + 1)
}
