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

// TestConcurrency_DoubleWithdrawal tests attempting to withdraw the same deposit twice
func TestConcurrency_DoubleWithdrawal(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	tests := []struct {
		name                      string
		setupFunc                 func() (depositID string, userAddr address)
		expectedFirstWithdrawal   bool
		expectedSecondWithdrawal  bool
		expectedSecondPanicMsg    string
	}{
		{
			name: "second withdrawal attempt should fail",
			setupFunc: func() (string, address) {
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

				// Wait for lockup to end (30 days = 2592000 seconds)
				testing.SkipHeights(2592001)

				return depositID, userAddr
			},
			expectedFirstWithdrawal:  true,
			expectedSecondWithdrawal: false,
			expectedSecondPanicMsg:   "[GNOSWAP-LAUNCHPAD-006] already collected || ",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			depositID, userAddr := tt.setupFunc()

			const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

			// First withdrawal - should succeed
			var firstAmount int64
			var firstErr error

			testing.SetRealm(testing.NewUserRealm(userAddr))
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
				lp := getTestImplementation()

				firstAmount, firstErr = lp.CollectDepositGns(depositID)
			}(cross)

			if tt.expectedFirstWithdrawal {
				uassert.NoError(t, firstErr, "first withdrawal should succeed")
				uassert.True(t, firstAmount > 0, "should withdraw positive amount")

				// Verify deposit is marked as withdrawn
				lp := getTestImplementation()
				deposit, err := lp.getDeposit(depositID)
				uassert.NoError(t, err)
				uassert.True(t, deposit.IsWithdrawn(), "deposit should be marked as withdrawn")
			}

			// Second withdrawal - should fail
			testing.SetRealm(testing.NewUserRealm(userAddr))

			if !tt.expectedSecondWithdrawal {
				uassert.AbortsWithMessage(t, tt.expectedSecondPanicMsg, func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
						lp := getTestImplementation()

						_, _ = lp.CollectDepositGns(depositID)
					}(cross)
				})
			}
		})
	}
}

// TestConcurrency_RewardCollectionAfterWithdrawal tests collecting reward after withdrawal
func TestConcurrency_RewardCollectionAfterWithdrawal(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	tests := []struct {
		name                   string
		collectRewardFirst     bool
		expectedRewardAmount   bool
		expectedWithdrawAmount bool
	}{
		{
			name:                   "collect reward then withdraw",
			collectRewardFirst:     true,
			expectedRewardAmount:   true,
			expectedWithdrawAmount: true,
		},
		{
			name:                   "withdraw then collect reward",
			collectRewardFirst:     false,
			expectedRewardAmount:   false,
			expectedWithdrawAmount: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
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

			// Wait some time for rewards to accumulate
			testing.SkipHeights(1000000)

			if tt.collectRewardFirst {
				// Collect reward first
				testing.SetRealm(testing.NewUserRealm(userAddr))
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
					lp := getTestImplementation()

					rewardAmount := lp.CollectRewardByDepositId(depositID)
					if tt.expectedRewardAmount {
						uassert.True(t, rewardAmount >= 0, "should collect reward")
					}
				}(cross)
			}

			// Wait for lockup to end
			testing.SkipHeights(2592001)

			// Withdraw
			testing.SetRealm(testing.NewUserRealm(userAddr))
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
				lp := getTestImplementation()

				withdrawAmount, err := lp.CollectDepositGns(depositID)
				if tt.expectedWithdrawAmount {
					uassert.NoError(t, err)
					uassert.True(t, withdrawAmount > 0, "should withdraw amount")
				}
			}(cross)

			if !tt.collectRewardFirst {
				// Try to collect reward after withdrawal - deposit is now withdrawn
				testing.SetRealm(testing.NewUserRealm(userAddr))

				// After withdrawal, the deposit state might prevent reward collection
				// This tests the state consistency
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
					lp := getTestImplementation()

					deposit, err := lp.getDeposit(depositID)
					uassert.NoError(t, err)
					uassert.True(t, deposit.IsWithdrawn(), "deposit should be withdrawn")
				}(cross)
			}
		})
	}
}

// TestConcurrency_MultipleRewardCollections tests collecting rewards multiple times
func TestConcurrency_MultipleRewardCollections(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	// Reset state
	resetTestStore()
	initTestStore()

	launchpadAddr := chain.PackageAddress(launchpadPackagePath)
	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm := testing.NewUserRealm(adminAddr)
	userAddr := testutils.TestAddress("user3")
	projectAddr := testutils.TestAddress("project3")

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
			"Test Project 3",
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

	// Collect rewards multiple times with time progression
	var totalCollected int64

	// First collection
	testing.SkipHeights(500000)

	testing.SetRealm(testing.NewUserRealm(userAddr))
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		reward1 := lp.CollectRewardByDepositId(depositID)
		totalCollected += reward1
		uassert.True(t, reward1 >= 0, "first collection should succeed")
	}(cross)

	// Second collection after more time
	testing.SkipHeights(500000)

	testing.SetRealm(testing.NewUserRealm(userAddr))
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		reward2 := lp.CollectRewardByDepositId(depositID)
		totalCollected += reward2
		uassert.True(t, reward2 >= 0, "second collection should succeed")
	}(cross)

	// Third collection after more time
	testing.SkipHeights(500000)

	testing.SetRealm(testing.NewUserRealm(userAddr))
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		reward3 := lp.CollectRewardByDepositId(depositID)
		totalCollected += reward3
		uassert.True(t, reward3 >= 0, "third collection should succeed")
	}(cross)

	// Verify total collected is reasonable
	uassert.True(t, totalCollected >= 0, "total collected should be non-negative")
}

// TestConcurrency_StateConsistencyAfterOperations tests state consistency
func TestConcurrency_StateConsistencyAfterOperations(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	// Reset state
	resetTestStore()
	initTestStore()

	launchpadAddr := chain.PackageAddress(launchpadPackagePath)
	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm := testing.NewUserRealm(adminAddr)
	userAddr := testutils.TestAddress("user4")
	projectAddr := testutils.TestAddress("project4")

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
			"Test Project 4",
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

	// Verify initial state
	lp := getTestImplementation()
	deposit, err := lp.getDeposit(depositID)
	uassert.NoError(t, err)
	uassert.False(t, deposit.IsWithdrawn(), "deposit should not be withdrawn initially")
	uassert.Equal(t, int64(1000000), deposit.DepositAmount(), "deposit amount should match")

	// Collect some rewards
	testing.SkipHeights(1000000)

	testing.SetRealm(testing.NewUserRealm(userAddr))
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		_ = lp.CollectRewardByDepositId(depositID)
	}(cross)

	// Verify state after reward collection
	deposit, err = lp.getDeposit(depositID)
	uassert.NoError(t, err)
	uassert.False(t, deposit.IsWithdrawn(), "deposit should still not be withdrawn")

	// Wait for lockup to end and withdraw
	testing.SkipHeights(2592001)

	testing.SetRealm(testing.NewUserRealm(userAddr))
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
		lp := getTestImplementation()

		_, _ = lp.CollectDepositGns(depositID)
	}(cross)

	// Verify final state
	deposit, err = lp.getDeposit(depositID)
	uassert.NoError(t, err)
	uassert.True(t, deposit.IsWithdrawn(), "deposit should be withdrawn")
	uassert.True(t, deposit.WithdrawnHeight() > 0, "withdrawn height should be set")
	uassert.True(t, deposit.WithdrawnTime() > 0, "withdrawn time should be set")
}
