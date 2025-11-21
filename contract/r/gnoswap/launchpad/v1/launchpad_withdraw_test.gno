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
	_ "gno.land/r/gnoswap/launchpad"

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

func TestLaunchpadWithdraw_WithdrawDeposit(t *testing.T) {
	const currentDepositID = "1"
	userAddr := testutils.TestAddress("user2")

	tests := []struct {
		name                 string
		depositID            string
		expectedHasError     bool
		expectedErrorMessage string
		expectedAmount       int64
		skipHeight           int64
	}{
		{
			name:             "withdraw deposit successfully",
			depositID:        currentDepositID,
			expectedHasError: false,
			expectedAmount:   1000000000,
			skipHeight:       60*60*24*180/5 + 2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadWithdrawTest(t, userAddr)
			lp := getTestImplementation()
			testing.SkipHeights(tt.skipHeight)
			deposit, _ := getDeposit(tt.depositID)

			currentTime := time.Now().Unix()
			_, amount, err := lp.withdrawDeposit(deposit, runtime.ChainHeight(), currentTime)

			if tt.expectedHasError {
				uassert.Equal(t, tt.expectedErrorMessage, err.Error())
				return
			}

			testing.SkipHeights(-tt.skipHeight)
			uassert.NoError(t, err)
			uassert.Equal(t, tt.expectedAmount, amount)
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

func initLaunchpadWithdrawTest(t *testing.T, depositor address) {
	testing.SetHeight(123)

	// Reset test store completely
	resetTestStore()

	// Initialize test environment
	lp := getTestImplementation()

	// Setup test project
	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()

	// Setup test project
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

	depositAmount := int64(1000000000)

	testing.SetOriginCaller(depositor)
	lp.depositGns(project.ID(), 30, depositAmount, depositor)

	govStakerAddr, _ := access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm := testing.NewUserRealm(govStakerAddr)
	testing.SetRealm(govStakerRealm)

	launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	xgns.Mint(cross, launchpadAddr, depositAmount)

	projectTier, _ := getProjectTier(project, 30)
	testing.SetHeight(projectTier.EndTime() + 1)
}
