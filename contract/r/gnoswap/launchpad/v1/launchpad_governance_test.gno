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

// TestGovernance_UnStakeGovernance tests the unStakeGovernance function
func TestGovernance_UnStakeGovernance(t *testing.T) {
	tests := []struct {
		name             string
		recipient        address
		withdrawalAmount int64
		expectedPanic    bool
	}{
		{
			name:             "valid unstake",
			recipient:        testutils.TestAddress("recipient1"),
			withdrawalAmount: 1000000,
			expectedPanic:    false,
		},
		{
			name:             "zero amount unstake",
			recipient:        testutils.TestAddress("recipient2"),
			withdrawalAmount: 0,
			expectedPanic:    false, // Should handle gracefully
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset state
			resetTestStore()

			if tt.expectedPanic {
				uassert.AbortsWithMessage(t, "", func() {
					unStakeGovernance(tt.recipient, tt.withdrawalAmount)
				})
			} else {
				// Should not panic
				unStakeGovernance(tt.recipient, tt.withdrawalAmount)
			}
		})
	}
}

// TestGovernance_DepositWithStaking tests that deposits complete successfully with staking
func TestGovernance_DepositWithStaking(t *testing.T) {
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

	// Setup user and deposit
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, userAddr, 2000000)

	testing.SetRealm(testing.NewUserRealm(userAddr))
	gns.Approve(cross, launchpadAddr, 2000000)

	var depositID string
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		// Should not panic - staking happens internally
		depositID = lp.DepositGns(projectID+":30", 1000000, "")
	}(cross)

	// Verify deposit was created
	lp := getTestImplementation()
	deposit, err := lp.getDeposit(depositID)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(1000000), deposit.DepositAmount())
}

// TestGovernance_WithdrawWithUnstaking tests that withdrawals complete successfully with unstaking
func TestGovernance_WithdrawWithUnstaking(t *testing.T) {
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

	// Setup user and deposit
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

	// Wait for lockup to end
	testing.SkipHeights(2592001)

	// Withdraw - unstaking happens internally
	testing.SetRealm(testing.NewUserRealm(userAddr))
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		amount, err := lp.CollectDepositGns(depositID)
		uassert.NoError(t, err)
		uassert.Equal(t, int64(1000000), amount)
	}(cross)

	// Verify deposit is withdrawn
	lp := getTestImplementation()
	deposit, err := lp.getDeposit(depositID)
	uassert.NoError(t, err)
	uassert.True(t, deposit.IsWithdrawn())
}

// TestGovernance_MultipleDepositsAndWithdrawals tests multiple operations
func TestGovernance_MultipleDepositsAndWithdrawals(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	// Reset state
	resetTestStore()
	initTestStore()

	launchpadAddr := chain.PackageAddress(launchpadPackagePath)
	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm := testing.NewUserRealm(adminAddr)
	user1Addr := testutils.TestAddress("user1")
	user2Addr := testutils.TestAddress("user2")
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

	// Setup users
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, user1Addr, 2000000)
	gns.Transfer(cross, user2Addr, 2000000)

	// User 1 deposits
	testing.SetRealm(testing.NewUserRealm(user1Addr))
	gns.Approve(cross, launchpadAddr, 2000000)

	var deposit1ID string
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		deposit1ID = lp.DepositGns(projectID+":30", 1000000, "")
	}(cross)

	// User 2 deposits
	testing.SetRealm(testing.NewUserRealm(user2Addr))
	gns.Approve(cross, launchpadAddr, 2000000)

	var deposit2ID string
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		deposit2ID = lp.DepositGns(projectID+":30", 1500000, "")
	}(cross)

	// Both deposits should exist
	lp := getTestImplementation()
	deposit1, err1 := lp.getDeposit(deposit1ID)
	deposit2, err2 := lp.getDeposit(deposit2ID)
	uassert.NoError(t, err1)
	uassert.NoError(t, err2)
	uassert.Equal(t, int64(1000000), deposit1.DepositAmount())
	uassert.Equal(t, int64(1500000), deposit2.DepositAmount())

	// Wait for lockup to end
	testing.SkipHeights(2592001)

	// User 1 withdraws
	testing.SetRealm(testing.NewUserRealm(user1Addr))
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		amount, err := lp.CollectDepositGns(deposit1ID)
		uassert.NoError(t, err)
		uassert.Equal(t, int64(1000000), amount)
	}(cross)

	// User 2 withdraws
	testing.SetRealm(testing.NewUserRealm(user2Addr))
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		amount, err := lp.CollectDepositGns(deposit2ID)
		uassert.NoError(t, err)
		uassert.Equal(t, int64(1500000), amount)
	}(cross)

	// Both deposits should be withdrawn
	deposit1, _ = lp.getDeposit(deposit1ID)
	deposit2, _ = lp.getDeposit(deposit2ID)
	uassert.True(t, deposit1.IsWithdrawn())
	uassert.True(t, deposit2.IsWithdrawn())
}
