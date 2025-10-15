package launchpad

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/v1/gov/xgns"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestCollectDepositGns(t *testing.T) {
	t.Skip("skip: This test affects the tests below, so all tests must be run individually")
	userAddr := testutils.TestAddress("user")
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
			name:             "collect deposit gns successfully",
			depositID:        "1",
			callerAddress:    userAddr,
			expectedHasAbort: false,
			expectedAmount:   1000000000,
		},
		{
			name:                 "collect deposit gns failed by invalid deposit id",
			depositID:            "invalid_deposit",
			callerAddress:        userAddr,
			expectedHasAbort:     true,
			expectedAbortMessage: "[GNOSWAP-LAUNCHPAD-020] not exist deposit || (invalid_deposit)",
		},
		{
			name:                 "collect deposit gns failed by invalid owner",
			depositID:            "1",
			callerAddress:        otherAddr,
			expectedHasAbort:     true,
			expectedAbortMessage: "[GNOSWAP-LAUNCHPAD-026] invalid owner",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadWithdrawTest(t)
			
			testing.SetRealm(testing.NewUserRealm(adminAddr))
			gns.Transfer(cross, launchpadAddr, 1000000000)

			testing.SetOriginCaller(tt.callerAddress)
			testing.SkipHeights(60*60*24*180/5 + 2)

			collectDepositFn := func() {
				CollectDepositGns(cross, tt.depositID)
			}

			if tt.expectedHasAbort {
				uassert.AbortsContains(t, tt.expectedAbortMessage, collectDepositFn)
				return
			}

			amount, err := CollectDepositGns(cross, tt.depositID)
			testing.SkipHeights(-(60*60*24*180/5 + 2))
			uassert.NoError(t, err)
			uassert.Equal(t, tt.expectedAmount, amount)
		})
	}
}

func TestWithdrawDeposit(t *testing.T) {
	const currentDepositID = "1"

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
			initLaunchpadWithdrawTest(t)
			testing.SkipHeights(tt.skipHeight)
			deposit, _ := getDeposit(tt.depositID)

			currentTime := time.Now().Unix()
			_, amount, err := withdrawDeposit(deposit, runtime.ChainHeight(), currentTime)

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

func TestCollectDepositGns_TokensRemainLocked(t *testing.T) {
	userAddr := testutils.TestAddress("user")
	launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())

	initLaunchpadWithdrawTest(t)

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, launchpadAddr, 1000000000)

	// Set caller as user and skip to withdrawal time
	testing.SetOriginCaller(userAddr)
	testing.SkipHeights(60*60*24*180/5 + 2)

	userBalanceBefore := gns.BalanceOf(userAddr)
	launchpadBalanceBefore := gns.BalanceOf(launchpadAddr)

	// withdrawal here.
	// this should unstake and return GNS
	amount, err := CollectDepositGns(cross, "1")
	uassert.NoError(t, err)
	uassert.Equal(t, int64(1000000000), amount)

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
func TestCollectDepositGns_FullBalanceRestoration(t *testing.T) {
	// init test environment
	userAddr := testutils.TestAddress("user")
	launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())

	testing.SetHeight(123)
	deposits = avl.NewTree()
	depositCounter = NewCounter()
	projects = avl.NewTree()
	projectTierRewardManagers = avl.NewTree()

	// Setup test project
	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()

	project, _ := createProject(
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
	projects.Set(project.ID(), project)

	testing.SkipHeights(10)

	// Give user initial GNS balance
	initialUserBalance := int64(5000000000) // 5000 GNS
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, userAddr, initialUserBalance)

	// Record initial balance
	userBalanceBeforeDeposit := gns.BalanceOf(userAddr)
	uassert.Equal(t, initialUserBalance, userBalanceBeforeDeposit, "Initial balance should match transferred amount")

	// User approves launchpad to spend GNS
	depositAmount := int64(1000000000) // 1000 GNS
	testing.SetRealm(testing.NewUserRealm(userAddr))
	gns.Approve(cross, launchpadAddr, depositAmount)

	// User deposits GNS
	testing.SetOriginCaller(userAddr)
	depositID := DepositGns(cross, project.ID()+":30", depositAmount, "")

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
	projectTier, _ := project.getTier(30)
	testing.SetHeight(projectTier.EndTime() + 1)
	testing.SkipHeights(60*60*24*180/5 + 2)

	// Perform withdrawal
	testing.SetOriginCaller(userAddr)
	withdrawnAmount, err := CollectDepositGns(cross, depositID)
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

func initLaunchpadWithdrawTest(t *testing.T) {
	testing.SetHeight(123)

	// Initialize test environment
	deposits = avl.NewTree()
	depositCounter = NewCounter()
	projects = avl.NewTree()
	projectTierRewardManagers = avl.NewTree()

	// Setup test project
	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()

	// Setup test project
	project, _ := createProject(
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
	projects.Set(project.ID(), project)

	testing.SkipHeights(10)

	depositAmount := int64(1000000000)

	depositor := testutils.TestAddress("user")
	testing.SetOriginCaller(depositor)
	depositGns(project.ID(), 30, depositAmount, depositor)

	govStakerAddr, _ := access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm := testing.NewUserRealm(govStakerAddr)
	testing.SetRealm(govStakerRealm)

	launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	xgns.Mint(cross, launchpadAddr, depositAmount)

	projectTier, _ := project.getTier(30)
	testing.SetHeight(projectTier.EndTime() + 1)
}
