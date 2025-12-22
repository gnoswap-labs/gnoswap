package v1

import (
	"chain"
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/halt"
	"gno.land/r/onbloc/obl"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/xgns"

	_ "gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	_ "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

func TestLaunchpadDeposit_DepositGns(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	launchpadAddr := chain.PackageAddress(launchpadPackagePath)
	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm := testing.NewUserRealm(adminAddr)

	tests := []struct {
		name                 string
		setupFunc            func(lp *launchpadV1) (string, address)
		targetProjectTierID  string
		depositAmount        int64
		referrer             string
		expectedPanic        bool
		expectedPanicMessage string
		expectedDepositID    bool
		validateFunc         func(t *testing.T, lp *launchpadV1, depositID string)
	}{
		{
			name: "successful deposit with valid project and tier",
			setupFunc: func(lp *launchpadV1) (string, address) {
				userAddr := testutils.TestAddress("user1")
				projectAddr := testutils.TestAddress("project1")

				// Reset state
				resetTestStore()

				// Set initial block height
				ctx := testing.GetContext()
				ctx.Height = 123
				ctx.Time = time.Unix(1234567890, 0)
				testing.SetContext(ctx)

				// Create project as admin
				testing.SetOriginCaller(launchpadAddr)
				testing.SetRealm(adminRealm)
				startTime := time.Now().Unix() + 3600 // 1 hour from now

				obl.Approve(cross, launchpadAddr, 10000)

				// Create project using public CreateProject function
				var projectID string
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))

					// Approve token for project creation
					projectID = lp.CreateProject(
						"Test Project",
						"gno.land/r/onbloc/obl",
						projectAddr,
						10000,
						"", // no conditions
						"",
						30,
						30,
						40,
						startTime,
					)
				}(cross)

				// Skip blocks to activate the project
				testing.SkipHeights(3600)

				// Setup user with GNS tokens
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, userAddr, 2000000) // Enough for deposit

				// User approves launchpad to spend GNS
				testing.SetRealm(testing.NewUserRealm(userAddr))
				gns.Approve(cross, launchpadAddr, 2000000)

				return projectID + ":30", userAddr
			},
			targetProjectTierID: "",
			depositAmount:       1000000, // Minimum deposit amount
			referrer:            "",
			expectedPanic:       false,
			expectedDepositID:   true,
			validateFunc: func(t *testing.T, lp *launchpadV1, depositID string) {
				// Verify deposit was created
				deposit, err := lp.getDeposit(depositID)
				uassert.NoError(t, err)
				uassert.Equal(t, int64(1000000), deposit.DepositAmount())
				uassert.Equal(t, int64(30), deposit.Tier())

				// Verify deposit exists in deposits tree
				deposits := lp.store.GetDeposits()
				_, exists := deposits.Get(depositID)
				uassert.True(t, exists)
			},
		},
		{
			name: "successful deposit with referrer",
			setupFunc: func(lp *launchpadV1) (string, address) {
				userAddr := testutils.TestAddress("user2")
				projectAddr := testutils.TestAddress("project2")

				// Set initial block height
				ctx := testing.GetContext()
				ctx.Height = 123
				ctx.Time = time.Unix(1234567890, 0)
				testing.SetContext(ctx)

				// Create project as admin
				testing.SetRealm(adminRealm)
				startTime := time.Now().Unix() + 3600 // 1 hour from now

				// Approve token for project creation
				testing.SetRealm(adminRealm)
				obl.Approve(cross, launchpadAddr, 10000)

				// Create project using public CreateProject function
				var projectID string

				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
					projectID = lp.CreateProject(
						"Test Project 2",
						"gno.land/r/onbloc/obl",
						projectAddr,
						10000,
						"", // no conditions
						"",
						30,
						30,
						40,
						startTime,
					)
				}(cross)

				// Skip blocks to activate the project
				testing.SkipHeights(3600)

				// Setup user with GNS tokens
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, userAddr, 3000000) // Enough for deposit

				// User approves launchpad to spend GNS
				testing.SetRealm(testing.NewUserRealm(userAddr))
				gns.Approve(cross, launchpadAddr, 3000000)

				return projectID + ":90", userAddr
			},
			targetProjectTierID: "",
			depositAmount:       2000000,
			referrer:            "g1referrer",
			expectedPanic:       false,
			expectedDepositID:   true,
			validateFunc: func(t *testing.T, lp *launchpadV1, depositID string) {
				// Verify deposit was created
				deposit, err := getDeposit(depositID)
				uassert.NoError(t, err)
				uassert.Equal(t, int64(2000000), deposit.DepositAmount())
				uassert.Equal(t, int64(90), deposit.Tier())
			},
		},
		{
			name: "deposit with 180 day tier",
			setupFunc: func(lp *launchpadV1) (string, address) {
				userAddr := testutils.TestAddress("user3")
				projectAddr := testutils.TestAddress("project3")

				// Set initial block height
				ctx := testing.GetContext()
				ctx.Height = 123
				ctx.Time = time.Unix(1234567890, 0)
				testing.SetContext(ctx)

				// Create project as admin
				testing.SetRealm(adminRealm)
				startTime := time.Now().Unix() + 3600 // 1 hour from now

				// Approve token for project creation
				obl.Approve(cross, launchpadAddr, 10000)

				// Create project using public CreateProject function
				var projectID string

				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
					projectID = lp.CreateProject(
						"Test Project 3",
						"gno.land/r/onbloc/obl",
						projectAddr,
						10000,
						"", // no conditions
						"",
						30,
						30,
						40,
						startTime,
					)
				}(cross)

				// Skip blocks to activate the project
				testing.SkipHeights(3600)

				// Setup user with GNS tokens
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, userAddr, 4000000) // Enough for deposit

				// User approves launchpad to spend GNS
				testing.SetRealm(testing.NewUserRealm(userAddr))
				gns.Approve(cross, launchpadAddr, 4000000)

				return projectID + ":180", userAddr
			},
			targetProjectTierID: "",
			depositAmount:       3000000,
			referrer:            "",
			expectedPanic:       false,
			expectedDepositID:   true,
			validateFunc: func(t *testing.T, lp *launchpadV1, depositID string) {
				// Verify deposit was created
				deposit, err := getDeposit(depositID)
				uassert.NoError(t, err)
				uassert.Equal(t, int64(3000000), deposit.DepositAmount())
				uassert.Equal(t, int64(180), deposit.Tier())
			},
		},
		{
			name: "fail with zero amount",
			setupFunc: func(lp *launchpadV1) (string, address) {
				// Unhalt the system
				testing.SetRealm(adminRealm)
				halt.SetHaltLevel(cross, halt.HaltLevelNone)

				userAddr := testutils.TestAddress("user5")

				// Return a valid project tier ID format
				return "gno.land/r/onbloc/obl:123:30", userAddr
			},
			targetProjectTierID:  "gno.land/r/onbloc/obl:123:30",
			depositAmount:        0,
			referrer:             "",
			expectedPanic:        true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-017] invalid amount || amount(0) should greater than minimum deposit amount(1000000)",
		},
		{
			name: "fail with negative amount",
			setupFunc: func(lp *launchpadV1) (string, address) {
				userAddr := testutils.TestAddress("user6")

				// No need to set up project since validation fails early
				return "gno.land/r/onbloc/obl:123:30", userAddr
			},
			targetProjectTierID:  "gno.land/r/onbloc/obl:123:30",
			depositAmount:        -1000000,
			referrer:             "",
			expectedPanic:        true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-017] invalid amount || amount(-1000000) should greater than minimum deposit amount(1000000)",
		},
		{
			name: "fail with invalid project tier ID format",
			setupFunc: func(lp *launchpadV1) (string, address) {
				userAddr := testutils.TestAddress("user7")

				return "invalid_format", userAddr
			},
			targetProjectTierID:  "invalid_format",
			depositAmount:        1000000,
			referrer:             "",
			expectedPanic:        true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-016] invalid data || (invalid_format)",
		},
		{
			name: "fail with non-existent project",
			setupFunc: func(lp *launchpadV1) (string, address) {
				userAddr := testutils.TestAddress("user8")

				// Reset state
				resetTestStore()

				return "non_existent_project:30", userAddr
			},
			targetProjectTierID:  "non_existent_project:30",
			depositAmount:        1000000,
			referrer:             "",
			expectedPanic:        true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-016] invalid data || (non_existent_project:30)",
		},
		{
			name: "fail with invalid tier duration",
			setupFunc: func(lp *launchpadV1) (string, address) {
				userAddr := testutils.TestAddress("user9")
				projectAddr := testutils.TestAddress("project9")

				// Reset state
				resetTestStore()

				// Set initial block height
				ctx := testing.GetContext()
				ctx.Height = 123
				ctx.Time = time.Unix(1234567890, 0)
				testing.SetContext(ctx)

				// Create project as admin
				testing.SetRealm(adminRealm)
				startTime := time.Now().Unix() + 3600 // 1 hour from now

				// Approve token for project creation
				obl.Approve(cross, launchpadAddr, 10000)

				// Create project using public CreateProject function
				var projectID string
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))

					projectID = lp.CreateProject(
						"Test Project 9",
						"gno.land/r/onbloc/obl",
						projectAddr,
						10000,
						"", // no conditions
						"",
						30,
						30,
						40,
						startTime,
					)
				}(cross)

				// Skip blocks to activate the project
				testing.SkipHeights(3600)

				// Setup user with GNS tokens
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, userAddr, 2000000)

				// User approves launchpad to spend GNS
				testing.SetRealm(testing.NewUserRealm(userAddr))
				gns.Approve(cross, launchpadAddr, 2000000)

				return projectID + ":60", userAddr // Invalid tier
			},
			targetProjectTierID:  "",
			depositAmount:        1000000,
			referrer:             "",
			expectedPanic:        true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-009] invalid tier || pool type(60) is not available",
		},
		{
			name: "fail when project is inactive",
			setupFunc: func(lp *launchpadV1) (string, address) {
				userAddr := testutils.TestAddress("user10")
				projectAddr := testutils.TestAddress("project10")

				// Reset state
				resetTestStore()

				// Set initial block height
				ctx := testing.GetContext()
				ctx.Height = 123
				ctx.Time = time.Unix(1234567890, 0)
				testing.SetContext(ctx)

				// Create project as admin
				testing.SetRealm(adminRealm)
				futureTime := time.Now().Unix() + 86400 // 1 day in future

				// Approve token for project creation
				obl.Approve(cross, launchpadAddr, 10000)

				// Create project using public CreateProject function with future start time
				var projectID string
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
					projectID = lp.CreateProject(
						"Future Project",
						"gno.land/r/onbloc/obl",
						projectAddr,
						10000,
						"", // no conditions
						"",
						30,
						30,
						40,
						futureTime, // Project starts in the future
					)
				}(cross)

				// DON'T skip blocks - keep project inactive

				// Setup user with GNS tokens
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, userAddr, 2000000)

				// User approves launchpad to spend GNS
				testing.SetRealm(testing.NewUserRealm(userAddr))
				gns.Approve(cross, launchpadAddr, 2000000)

				return projectID + ":30", userAddr
			},
			targetProjectTierID:  "",
			depositAmount:        1000000,
			referrer:             "",
			expectedPanic:        true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-005] project is inactive || gno.land/r/onbloc/obl:123",
		},
		{
			name: "fail when called from contract",
			setupFunc: func(lp *launchpadV1) (string, address) {
				contractAddr := testutils.TestAddress("contract")
				projectAddr := testutils.TestAddress("project12")

				// Reset state
				resetTestStore()

				// Set initial block height
				ctx := testing.GetContext()
				ctx.Height = 123
				ctx.Time = time.Unix(1234567890, 0)
				testing.SetContext(ctx)

				// Create project as admin
				testing.SetRealm(adminRealm)
				startTime := time.Now().Unix() + 3600 // 1 hour from now

				// Approve token for project creation
				obl.Approve(cross, launchpadAddr, 10000)

				// Create project using public CreateProject function
				var projectID string
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))

					projectID = lp.CreateProject(
						"Test Project 12",
						"gno.land/r/onbloc/obl",
						projectAddr,
						10000,
						"", // no conditions
						"",
						30,
						30,
						40,
						startTime,
					)
				}(cross)

				// Skip blocks to activate the project
				testing.SkipHeights(3600)

				// Setup contract with GNS tokens
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, contractAddr, 2000000) // Enough for deposit

				// Contract approves launchpad to spend GNS
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/test/contract"))
				gns.Approve(cross, launchpadAddr, 2000000)

				return projectID + ":30", contractAddr
			},
			targetProjectTierID:  "",
			depositAmount:        1000000,
			referrer:             "",
			expectedPanic:        true,
			expectedPanicMessage: "caller is not user",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset test store for each test
			initTestStore()

			testing.SetRealm(adminRealm)
			lp := getTestImplementation()
			projectTierID, userAddr := tt.setupFunc(lp)
			if tt.targetProjectTierID == "" {
				tt.targetProjectTierID = projectTierID
			}

			// For contract test case, check if it's a contract call
			if tt.name == "fail when called from contract" {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/test/contract"))
			} else {
				testing.SetRealm(testing.NewUserRealm(userAddr))
			}

			if tt.expectedPanic {
				uassert.AbortsWithMessage(t, tt.expectedPanicMessage, func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
						lp.DepositGns(tt.targetProjectTierID, tt.depositAmount, tt.referrer)
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
					depositID := lp.DepositGns(tt.targetProjectTierID, tt.depositAmount, tt.referrer)

					if tt.expectedDepositID {
						uassert.NotEmpty(t, depositID)

						if tt.validateFunc != nil {
							tt.validateFunc(t, lp, depositID)
						}
					}
				}(cross)
			}
		})
	}
}

func TestLaunchpadDeposit_depositGns(t *testing.T) {
	userAddr := testutils.TestAddress("user")

	tests := []struct {
		name                 string
		projectID            string
		tierDuration         int64
		depositAmount        int64
		callerAddress        address
		expectedHasError     bool
		expectedErrorMessage string
	}{
		{
			name:             "deposit gns successfully",
			projectID:        "gno.land/r/onbloc/obl:123",
			tierDuration:     30,
			depositAmount:    1000,
			callerAddress:    userAddr,
			expectedHasError: false,
		},
		{
			name:                 "deposit gns failed by invalid project id",
			projectID:            "invalid",
			tierDuration:         30,
			depositAmount:        1000,
			callerAddress:        userAddr,
			expectedHasError:     true,
			expectedErrorMessage: "[GNOSWAP-LAUNCHPAD-003] requested data not found || project(invalid) not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadDepositTest(t)
			lp := getTestImplementation()
			testing.SetOriginCaller(tt.callerAddress)

			project, err := lp.getProject(tt.projectID)
			if tt.expectedHasError && err != nil {
				uassert.Equal(t, tt.expectedErrorMessage, err.Error())
				return
			}

			_, _, _, _, err = lp.depositGns(project, tt.projectID, tt.tierDuration, tt.depositAmount, tt.callerAddress)

			if tt.expectedHasError {
				uassert.Equal(t, tt.expectedErrorMessage, err.Error())
				return
			}

			uassert.NoError(t, err)
		})
	}
}

func TestLaunchpadDeposit_stakeGovernance(t *testing.T) {
	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	launchpadAddr := access.MustGetAddress(prbac.ROLE_LAUNCHPAD.String())
	projectRecipient := testutils.TestAddress("project")

	tests := []struct {
		name                 string
		recipient            address
		depositAmount        int64
		callerAddress        address
		userAddress          address
		expectedError        bool
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:                 "stake governance successfully",
			recipient:            projectRecipient,
			depositAmount:        1000000,
			callerAddress:        launchpadAddr,
			userAddress:          adminAddr,
			expectedError:        false,
			expectedHasAbort:     false,
			expectedAbortMessage: "",
		},
		{
			name:                 "stake governance failed by caller is not launchpad",
			recipient:            projectRecipient,
			depositAmount:        1000000,
			callerAddress:        adminAddr,
			userAddress:          adminAddr,
			expectedError:        false,
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 is not launchpad",
		},
	}

	// caller is launchpad, user is admin
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadDepositTest(t)
			lp := getTestImplementation()

			testing.SetOriginCaller(tt.userAddress)
			gns.Approve(cross, tt.callerAddress, tt.depositAmount)

			testing.SetOriginCaller(tt.callerAddress)

			var err error

			stakeGovernanceFn := func() {
				err = lp.stakeGovernance(tt.recipient, tt.depositAmount, tt.callerAddress, tt.userAddress)
			}

			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMessage, stakeGovernanceFn)
				return
			}

			stakeGovernanceFn()

			if tt.expectedError {
				uassert.Error(t, err)
				return
			}

			uassert.NoError(t, err)
		})
	}
}

func initLaunchpadDepositTest(t *testing.T) {
	testing.SetHeight(123)

	// Reset test store completely
	resetTestStore()

	// Initialize test environment
	lp := getTestImplementation()

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
}

// TestLaunchpadDeposit_xGNSMintedOnce verifies that xGNS is minted exactly once
// during deposit (not twice as was the bug before the fix).
// This test ensures the fix for the double-minting issue is working correctly.
func TestLaunchpadDeposit_xGNSMintedOnce(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	launchpadAddr := chain.PackageAddress(launchpadPackagePath)
	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm := testing.NewUserRealm(adminAddr)

	t.Run("xGNS should be minted exactly once per deposit", func(t *testing.T) {
		// Reset test store
		initTestStore()

		userAddr := testutils.TestAddress("xgns_test_user")
		projectAddr := testutils.TestAddress("xgns_test_project")

		// Set initial block height
		ctx := testing.GetContext()
		ctx.Height = 123
		ctx.Time = time.Unix(1234567890, 0)
		testing.SetContext(ctx)

		// Create project as admin
		testing.SetOriginCaller(launchpadAddr)
		testing.SetRealm(adminRealm)
		startTime := time.Now().Unix() + 3600 // 1 hour from now

		obl.Approve(cross, launchpadAddr, 10000)

		lp := getTestImplementation()

		// Create project
		var projectID string
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			projectID = lp.CreateProject(
				"xGNS Test Project",
				"gno.land/r/onbloc/obl",
				projectAddr,
				10000,
				"", // no conditions
				"",
				30,
				30,
				40,
				startTime,
			)
		}(cross)

		// Skip blocks to activate the project
		testing.SkipHeights(3600)

		// Setup user with GNS tokens
		testing.SetRealm(adminRealm)
		depositAmount := int64(1000000)
		gns.Transfer(cross, userAddr, depositAmount*2)

		// User approves launchpad to spend GNS
		testing.SetRealm(testing.NewUserRealm(userAddr))
		gns.Approve(cross, launchpadAddr, depositAmount*2)

		// Record xGNS state before deposit
		testing.SetRealm(testing.NewUserRealm(launchpadAddr))
		initialLaunchpadXGNSBalance := xgns.BalanceOf(launchpadAddr)
		initialXGNSTotalSupply := xgns.TotalSupply()

		// Perform deposit
		testing.SetRealm(testing.NewUserRealm(userAddr))
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			lp.DepositGns(projectID+":30", depositAmount, "")
		}(cross)

		// Record xGNS state after deposit
		testing.SetRealm(testing.NewUserRealm(launchpadAddr))
		finalLaunchpadXGNSBalance := xgns.BalanceOf(launchpadAddr)
		finalXGNSTotalSupply := xgns.TotalSupply()

		// Verify xGNS was minted exactly once (not twice)
		// The launchpad balance should increase by exactly depositAmount
		actualBalanceIncrease := finalLaunchpadXGNSBalance - initialLaunchpadXGNSBalance
		uassert.Equal(t, depositAmount, actualBalanceIncrease,
			"xGNS balance should increase by exactly depositAmount (single mint)")

		// Total supply should also increase by exactly depositAmount
		actualSupplyIncrease := finalXGNSTotalSupply - initialXGNSTotalSupply
		uassert.Equal(t, depositAmount, actualSupplyIncrease,
			"xGNS total supply should increase by exactly depositAmount (single mint)")

		// If double-minting was occurring, these values would be 2*depositAmount
		uassert.True(t, actualBalanceIncrease != depositAmount*2,
			"xGNS should NOT be minted twice")
	})

	t.Run("multiple deposits should each mint xGNS once", func(t *testing.T) {
		// Reset test store
		initTestStore()

		userAddr := testutils.TestAddress("xgns_multi_user")
		projectAddr := testutils.TestAddress("xgns_multi_project")

		// Set initial block height
		ctx := testing.GetContext()
		ctx.Height = 123
		ctx.Time = time.Unix(1234567890, 0)
		testing.SetContext(ctx)

		// Create project as admin
		testing.SetOriginCaller(launchpadAddr)
		testing.SetRealm(adminRealm)
		startTime := time.Now().Unix() + 3600

		obl.Approve(cross, launchpadAddr, 10000)

		lp := getTestImplementation()

		// Create project
		var projectID string
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			projectID = lp.CreateProject(
				"xGNS Multi Test Project",
				"gno.land/r/onbloc/obl",
				projectAddr,
				10000,
				"",
				"",
				30,
				30,
				40,
				startTime,
			)
		}(cross)

		// Skip blocks to activate the project
		testing.SkipHeights(3600)

		// Setup user with enough GNS tokens for multiple deposits
		testing.SetRealm(adminRealm)
		deposit1Amount := int64(1000000)
		deposit2Amount := int64(2000000)
		totalDepositAmount := deposit1Amount + deposit2Amount
		gns.Transfer(cross, userAddr, totalDepositAmount*2)

		// User approves launchpad
		testing.SetRealm(testing.NewUserRealm(userAddr))
		gns.Approve(cross, launchpadAddr, totalDepositAmount*2)

		// Record initial xGNS state
		testing.SetRealm(testing.NewUserRealm(launchpadAddr))
		initialXGNSTotalSupply := xgns.TotalSupply()

		// First deposit
		testing.SetRealm(testing.NewUserRealm(userAddr))
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			lp.DepositGns(projectID+":30", deposit1Amount, "")
		}(cross)

		// Check after first deposit
		testing.SetRealm(testing.NewUserRealm(launchpadAddr))
		afterFirstDepositSupply := xgns.TotalSupply()
		firstDepositIncrease := afterFirstDepositSupply - initialXGNSTotalSupply
		uassert.Equal(t, deposit1Amount, firstDepositIncrease,
			"First deposit should mint exactly deposit1Amount of xGNS")

		// Second deposit
		testing.SetRealm(testing.NewUserRealm(userAddr))
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			lp.DepositGns(projectID+":90", deposit2Amount, "")
		}(cross)

		// Check after second deposit
		testing.SetRealm(testing.NewUserRealm(launchpadAddr))
		finalXGNSTotalSupply := xgns.TotalSupply()
		totalIncrease := finalXGNSTotalSupply - initialXGNSTotalSupply

		// Total xGNS minted should equal total deposits (not 2x)
		uassert.Equal(t, totalDepositAmount, totalIncrease,
			"Total xGNS minted should equal sum of all deposits")
	})
}

// TestDepositGns_RewardDistributionOrder verifies that the reward distribution
// order is correct: update reward-per-deposit before adding new deposit.
// This prevents:
// 1. Dilution of existing depositor rewards
// 2. New depositors claiming rewards from periods they didn't participate in
func TestDepositGns_RewardDistributionOrder(t *testing.T) {
	const launchpadPackagePath = "gno.land/r/gnoswap/launchpad"

	launchpadAddr := chain.PackageAddress(launchpadPackagePath)
	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm := testing.NewUserRealm(adminAddr)

	t.Run("existing depositor should not have rewards diluted by new deposit", func(t *testing.T) {
		// Reset state
		resetTestStore()
		lp := getTestImplementation()

		// Set initial block height
		ctx := testing.GetContext()
		ctx.Height = 123
		ctx.Time = time.Unix(1234567890, 0)
		testing.SetContext(ctx)

		user1Addr := testutils.TestAddress("user1")
		user2Addr := testutils.TestAddress("user2")
		projectAddr := testutils.TestAddress("projectRD")

		// Create project as admin
		testing.SetRealm(adminRealm)
		startTime := time.Now().Unix() + 3600 // 1 hour from now

		obl.Approve(cross, launchpadAddr, 1000000)

		var projectID string
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			projectID = lp.CreateProject(
				"Reward Distribution Test Project",
				"gno.land/r/onbloc/obl",
				projectAddr,
				1000000, // total reward amount
				"",
				"",
				100, // all to tier 30
				0,
				0,
				startTime,
			)
		}(cross)

		// Skip blocks to activate the project
		testing.SkipHeights(3600)

		// Setup user1 with GNS tokens
		testing.SetRealm(adminRealm)
		gns.Transfer(cross, user1Addr, 10000000)

		// User1 deposits first
		testing.SetRealm(testing.NewUserRealm(user1Addr))
		gns.Approve(cross, launchpadAddr, 10000000)

		var deposit1ID string
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			deposit1ID = lp.DepositGns(projectID+":30", 1000000, "")
		}(cross)

		// Get reward state for user1 right after deposit
		deposit1, err := lp.getDeposit(deposit1ID)
		uassert.NoError(t, err)
		uassert.Equal(t, int64(1000000), deposit1.DepositAmount())

		project, err := lp.getProject(projectID)
		uassert.NoError(t, err)

		tier30, err := getProjectTier(project, 30)
		uassert.NoError(t, err)

		rewardManager1, err := lp.getProjectTierRewardManager(tier30.ID())
		uassert.NoError(t, err)

		// Record initial accumulated reward per deposit for user1
		user1InitialDebt, err := getDepositRewardState(rewardManager1, deposit1ID)
		uassert.NoError(t, err)

		// Skip time to accumulate some rewards (e.g., 10 seconds)
		testing.SkipHeights(10)

		// Setup user2 with GNS tokens
		testing.SetRealm(adminRealm)
		gns.Transfer(cross, user2Addr, 10000000)

		// User2 deposits same amount
		testing.SetRealm(testing.NewUserRealm(user2Addr))
		gns.Approve(cross, launchpadAddr, 10000000)

		var deposit2ID string
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			deposit2ID = lp.DepositGns(projectID+":30", 1000000, "")
		}(cross)

		// Verify deposit2 was created
		deposit2, err := lp.getDeposit(deposit2ID)
		uassert.NoError(t, err)
		uassert.Equal(t, int64(1000000), deposit2.DepositAmount())

		// Get updated reward manager
		rewardManager2, err := lp.getProjectTierRewardManager(tier30.ID())
		uassert.NoError(t, err)

		// Get reward state for user2
		user2Debt, err := getDepositRewardState(rewardManager2, deposit2ID)
		uassert.NoError(t, err)

		uassert.True(t, user2Debt.PriceDebtX128().Gt(user1InitialDebt.PriceDebtX128()),
			"User2's price debt should be greater than User1's initial debt")
	})

	t.Run("new depositor should not claim rewards from period before deposit", func(t *testing.T) {
		// Reset state
		resetTestStore()
		lp := getTestImplementation()

		// Set initial block height
		ctx := testing.GetContext()
		ctx.Height = 123
		ctx.Time = time.Unix(1234567890, 0)
		testing.SetContext(ctx)

		user1Addr := testutils.TestAddress("userA")
		user2Addr := testutils.TestAddress("userB")
		projectAddr := testutils.TestAddress("projectRD2")

		// Create project as admin
		testing.SetRealm(adminRealm)
		startTime := time.Now().Unix() + 3600

		obl.Approve(cross, launchpadAddr, 1000000)

		var projectID string
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			projectID = lp.CreateProject(
				"No Prior Claim Test",
				"gno.land/r/onbloc/obl",
				projectAddr,
				1000000,
				"",
				"",
				100,
				0,
				0,
				startTime,
			)
		}(cross)

		// Activate project
		testing.SkipHeights(3600)

		// User1 deposits
		testing.SetRealm(adminRealm)
		gns.Transfer(cross, user1Addr, 10000000)

		testing.SetRealm(testing.NewUserRealm(user1Addr))
		gns.Approve(cross, launchpadAddr, 10000000)

		var deposit1ID string
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			deposit1ID = lp.DepositGns(projectID+":30", 1000000, "")
		}(cross)

		// Skip significant time to accumulate rewards
		testing.SkipHeights(100)

		// User2 deposits
		testing.SetRealm(adminRealm)
		gns.Transfer(cross, user2Addr, 10000000)

		testing.SetRealm(testing.NewUserRealm(user2Addr))
		gns.Approve(cross, launchpadAddr, 10000000)

		var deposit2ID string
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(launchpadPackagePath))
			deposit2ID = lp.DepositGns(projectID+":30", 1000000, "")
		}(cross)

		// Get project and tier
		project, err := lp.getProject(projectID)
		uassert.NoError(t, err)

		tier30, err := getProjectTier(project, 30)
		uassert.NoError(t, err)

		rewardManager, err := lp.getProjectTierRewardManager(tier30.ID())
		uassert.NoError(t, err)

		// Get reward states
		user1State, err := getDepositRewardState(rewardManager, deposit1ID)
		uassert.NoError(t, err)

		user2State, err := getDepositRewardState(rewardManager, deposit2ID)
		uassert.NoError(t, err)

		// Calculate claimable rewards for both users at this point
		accumulatedReward := rewardManager.AccumulatedRewardPerDepositX128()

		user1Claimable := calculateClaimableReward(user1State, accumulatedReward)
		user2Claimable := calculateClaimableReward(user2State, accumulatedReward)

		uassert.True(t, user1Claimable >= 0,
			"User1 should have non-negative claimable rewards")

		uassert.Equal(t, int64(0), user2Claimable,
			"User2 should have 0 claimable rewards immediately after deposit")
	})
}
