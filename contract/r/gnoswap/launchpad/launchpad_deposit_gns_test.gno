package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/halt"

	"gno.land/r/onbloc/obl"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestDepositGns(t *testing.T) {
	tests := []struct {
		name                 string
		setupFunc            func() (string, std.Address)
		targetProjectTierID  string
		depositAmount        int64
		referrer             string
		expectedPanic        bool
		expectedPanicMessage string
		expectedDepositID    bool
		validateFunc         func(t *testing.T, depositID string)
	}{
		{
			name: "successful deposit with valid project and tier",
			setupFunc: func() (string, std.Address) {
				userAddr := testutils.TestAddress("user1")
				projectAddr := testutils.TestAddress("project1")
				adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
				launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

				// Reset state
				projects = avl.NewTree()
				projectTierRewardManagers = avl.NewTree()
				deposits = avl.NewTree()
				depositCounter = NewCounter()

				// Set initial block height
				testing.SetHeight(123)

				// Create project as admin
				testing.SetRealm(std.NewUserRealm(adminAddr))
				startTime := time.Now().Unix() + 3600 // 1 hour from now

				// Approve token for project creation
				obl.Approve(cross, launchpadAddr, 10000)

				// Create project using public CreateProject function
				projectID := CreateProject(
					cross,
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

				// Skip blocks to activate the project
				testing.SkipHeights(3600)

				// Setup user with GNS tokens
				testing.SetRealm(std.NewUserRealm(adminAddr))
				gns.Transfer(cross, userAddr, 2000000) // Enough for deposit

				// User approves launchpad to spend GNS
				testing.SetRealm(std.NewUserRealm(userAddr))
				gns.Approve(cross, launchpadAddr, 2000000)

				return projectID + ":30", userAddr
			},
			targetProjectTierID: "",
			depositAmount:       1000000, // Minimum deposit amount
			referrer:            "",
			expectedPanic:       false,
			expectedDepositID:   true,
			validateFunc: func(t *testing.T, depositID string) {
				// Verify deposit was created
				deposit, err := getDeposit(depositID)
				uassert.NoError(t, err)
				uassert.Equal(t, int64(1000000), deposit.DepositAmount())
				uassert.Equal(t, int64(30), deposit.Tier())

				// Verify deposit exists in deposits tree
				_, exists := deposits.Get(depositID)
				uassert.True(t, exists)
			},
		},
		{
			name: "successful deposit with referrer",
			setupFunc: func() (string, std.Address) {
				userAddr := testutils.TestAddress("user2")
				projectAddr := testutils.TestAddress("project2")

				// Reset state
				projects = avl.NewTree()
				projectTierRewardManagers = avl.NewTree()
				deposits = avl.NewTree()
				depositCounter = NewCounter()

				adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
				launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

				// Set initial block height
				testing.SetHeight(123)

				// Create project as admin
				testing.SetRealm(std.NewUserRealm(adminAddr))
				startTime := time.Now().Unix() + 3600 // 1 hour from now

				// Approve token for project creation
				obl.Approve(cross, launchpadAddr, 10000)

				// Create project using public CreateProject function
				projectID := CreateProject(
					cross,
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

				// Skip blocks to activate the project
				testing.SkipHeights(3600)

				// Setup user with GNS tokens
				testing.SetRealm(std.NewUserRealm(adminAddr))
				gns.Transfer(cross, userAddr, 3000000) // Enough for deposit

				// User approves launchpad to spend GNS
				testing.SetRealm(std.NewUserRealm(userAddr))
				gns.Approve(cross, launchpadAddr, 3000000)

				return projectID + ":90", userAddr
			},
			targetProjectTierID: "",
			depositAmount:       2000000,
			referrer:            "g1referrer",
			expectedPanic:       false,
			expectedDepositID:   true,
			validateFunc: func(t *testing.T, depositID string) {
				// Verify deposit was created
				deposit, err := getDeposit(depositID)
				uassert.NoError(t, err)
				uassert.Equal(t, int64(2000000), deposit.DepositAmount())
				uassert.Equal(t, int64(90), deposit.Tier())
			},
		},
		{
			name: "deposit with 180 day tier",
			setupFunc: func() (string, std.Address) {
				userAddr := testutils.TestAddress("user3")
				projectAddr := testutils.TestAddress("project3")
				adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
				launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

				// Reset state
				projects = avl.NewTree()
				projectTierRewardManagers = avl.NewTree()
				deposits = avl.NewTree()
				depositCounter = NewCounter()

				// Set initial block height
				testing.SetHeight(123)

				// Create project as admin
				testing.SetRealm(std.NewUserRealm(adminAddr))
				startTime := time.Now().Unix() + 3600 // 1 hour from now

				// Approve token for project creation
				obl.Approve(cross, launchpadAddr, 10000)

				// Create project using public CreateProject function
				projectID := CreateProject(
					cross,
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

				// Skip blocks to activate the project
				testing.SkipHeights(3600)

				// Setup user with GNS tokens
				testing.SetRealm(std.NewUserRealm(adminAddr))
				gns.Transfer(cross, userAddr, 4000000) // Enough for deposit

				// User approves launchpad to spend GNS
				testing.SetRealm(std.NewUserRealm(userAddr))
				gns.Approve(cross, launchpadAddr, 4000000)

				return projectID + ":180", userAddr
			},
			targetProjectTierID: "",
			depositAmount:       3000000,
			referrer:            "",
			expectedPanic:       false,
			expectedDepositID:   true,
			validateFunc: func(t *testing.T, depositID string) {
				// Verify deposit was created
				deposit, err := getDeposit(depositID)
				uassert.NoError(t, err)
				uassert.Equal(t, int64(3000000), deposit.DepositAmount())
				uassert.Equal(t, int64(180), deposit.Tier())
			},
		},
		{
			name: "fail with zero amount",
			setupFunc: func() (string, std.Address) {
				// Unhalt the system
				adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
				testing.SetRealm(std.NewUserRealm(adminAddr))
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
			setupFunc: func() (string, std.Address) {
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
			setupFunc: func() (string, std.Address) {
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
			setupFunc: func() (string, std.Address) {
				userAddr := testutils.TestAddress("user8")

				// Reset state
				projects = avl.NewTree()

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
			setupFunc: func() (string, std.Address) {
				userAddr := testutils.TestAddress("user9")
				projectAddr := testutils.TestAddress("project9")
				adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
				launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

				// Reset state
				projects = avl.NewTree()
				projectTierRewardManagers = avl.NewTree()
				deposits = avl.NewTree()
				depositCounter = NewCounter()

				// Set initial block height
				testing.SetHeight(123)

				// Create project as admin
				testing.SetRealm(std.NewUserRealm(adminAddr))
				startTime := time.Now().Unix() + 3600 // 1 hour from now

				// Approve token for project creation
				obl.Approve(cross, launchpadAddr, 10000)

				// Create project using public CreateProject function
				projectID := CreateProject(
					cross,
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

				// Skip blocks to activate the project
				testing.SkipHeights(3600)

				// Setup user with GNS tokens
				testing.SetRealm(std.NewUserRealm(adminAddr))
				gns.Transfer(cross, userAddr, 2000000)

				// User approves launchpad to spend GNS
				testing.SetRealm(std.NewUserRealm(userAddr))
				gns.Approve(cross, launchpadAddr, 2000000)

				return projectID + ":60", userAddr // Invalid tier
			},
			targetProjectTierID:  "",
			depositAmount:        1000000,
			referrer:             "",
			expectedPanic:        true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-009] invalid pool || pool type(60) is not available",
		},
		{
			name: "fail when project is inactive",
			setupFunc: func() (string, std.Address) {
				userAddr := testutils.TestAddress("user10")
				projectAddr := testutils.TestAddress("project10")
				adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
				launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

				// Reset state
				projects = avl.NewTree()
				projectTierRewardManagers = avl.NewTree()
				deposits = avl.NewTree()
				depositCounter = NewCounter()

				// Set initial block height
				testing.SetHeight(123)

				// Create project as admin
				testing.SetRealm(std.NewUserRealm(adminAddr))
				futureTime := time.Now().Unix() + 86400 // 1 day in future

				// Approve token for project creation
				obl.Approve(cross, launchpadAddr, 10000)

				// Create project using public CreateProject function with future start time
				projectID := CreateProject(
					cross,
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

				// DON'T skip blocks - keep project inactive

				// Setup user with GNS tokens
				testing.SetRealm(std.NewUserRealm(adminAddr))
				gns.Transfer(cross, userAddr, 2000000)

				// User approves launchpad to spend GNS
				testing.SetRealm(std.NewUserRealm(userAddr))
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
			setupFunc: func() (string, std.Address) {
				contractAddr := testutils.TestAddress("contract")
				projectAddr := testutils.TestAddress("project12")
				adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
				launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

				// Reset state
				projects = avl.NewTree()
				projectTierRewardManagers = avl.NewTree()
				deposits = avl.NewTree()
				depositCounter = NewCounter()

				// Set initial block height
				testing.SetHeight(123)

				// Create project as admin
				testing.SetRealm(std.NewUserRealm(adminAddr))
				startTime := time.Now().Unix() + 3600 // 1 hour from now

				// Approve token for project creation
				obl.Approve(cross, launchpadAddr, 10000)

				// Create project using public CreateProject function
				projectID := CreateProject(
					cross,
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

				// Skip blocks to activate the project
				testing.SkipHeights(3600)

				// Setup contract with GNS tokens
				testing.SetRealm(std.NewUserRealm(adminAddr))
				gns.Transfer(cross, contractAddr, 2000000) // Enough for deposit

				// Contract approves launchpad to spend GNS
				testing.SetRealm(std.NewCodeRealm("gno.land/r/test/contract"))
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
			// Save original state
			origProjects := projects
			origProjectTierRewardManagers := projectTierRewardManagers
			origDeposits := deposits
			// Save halt state manually - we'll check and restore it
			origHalted := false

			defer func() {
				projects = origProjects
				projectTierRewardManagers = origProjectTierRewardManagers
				deposits = origDeposits
				// Restore halt state if needed
				if origHalted {
					adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
					testing.SetRealm(std.NewUserRealm(adminAddr))
					halt.SetHaltLevel(cross, halt.HaltLevelComplete)
				}
			}()

			projectTierID, userAddr := tt.setupFunc()
			if tt.targetProjectTierID == "" {
				tt.targetProjectTierID = projectTierID
			}

			// For contract test case, check if it's a contract call
			if tt.name == "fail when called from contract" {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/test/contract"))
			} else {
				testing.SetRealm(std.NewUserRealm(userAddr))
			}
			if tt.expectedPanic {
				uassert.AbortsWithMessage(t, tt.expectedPanicMessage, func() {
					DepositGns(cross, tt.targetProjectTierID, tt.depositAmount, tt.referrer)
				})
			} else {
				depositID := DepositGns(cross, tt.targetProjectTierID, tt.depositAmount, tt.referrer)

				if tt.expectedDepositID {
					uassert.NotEmpty(t, depositID)

					if tt.validateFunc != nil {
						tt.validateFunc(t, depositID)
					}
				}
			}
		})
	}
}
