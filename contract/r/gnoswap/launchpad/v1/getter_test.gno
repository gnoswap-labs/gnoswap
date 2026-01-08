package v1

import (
	"chain"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

func TestGetProjectCount(t *testing.T) {
	t.Run("empty store returns zero count", func(t *testing.T) {
		// Setup
		resetTestStore()
		initTestStore()
		lp := getTestImplementation()

		// Execute
		count := lp.GetProjectCount()

		// Verify
		uassert.Equal(t, int64(0), count)
	})

	t.Run("count increases with created projects", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Project 1",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient1",
		})

		count1 := lp.GetProjectCount()
		uassert.Equal(t, int64(1), count1)

		createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Project 2",
			rewardAmount:    2000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient2",
		})

		// Execute
		count2 := lp.GetProjectCount()

		// Verify
		uassert.Equal(t, int64(2), count2)
	})
}

func TestGetProjectIDs(t *testing.T) {
	tests := []struct {
		name          string
		offset        int64
		limit         int64
		expectedCount int64
	}{
		{
			name:          "negative offset returns empty slice",
			offset:        -1,
			limit:         10,
			expectedCount: 0,
		},
		{
			name:          "zero limit returns empty slice",
			offset:        0,
			limit:         0,
			expectedCount: 0,
		},
		{
			name:          "negative limit returns empty slice",
			offset:        0,
			limit:         -1,
			expectedCount: 0,
		},
		{
			name:          "valid pagination with empty store",
			offset:        0,
			limit:         10,
			expectedCount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			resetTestStore()
			initTestStore()
			lp := getTestImplementation()

			// Execute
			result := lp.GetProjectIDs(tt.offset, tt.limit)

			// Verify
			if result == nil {
				result = []string{}
			}
			uassert.Equal(t, tt.expectedCount, int64(len(result)))
		})
	}
}

func TestGetProject(t *testing.T) {
	tests := []struct {
		name             string
		projectID        string
		createProject    bool
		expectedNotNil   bool
		expectedHasError bool
		expectedError    string
	}{
		{
			name:             "get existing project",
			createProject:    true,
			expectedNotNil:   true,
			expectedHasError: false,
		},
		{
			name:             "get non-existent project",
			projectID:        "nonexistent-project-id",
			createProject:    false,
			expectedNotNil:   false,
			expectedHasError: true,
			expectedError:    "project not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			setupTestEnvironment(t, testEnvConfig{})
			lp := getTestImplementation()
			launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
			_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

			projectID := tt.projectID
			if tt.createProject {
				projectID = createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
					name:            "Test Project",
					rewardAmount:    1000000,
					tier30Pct:       25,
					tier90Pct:       50,
					tier180Pct:      25,
					recipientSuffix: "recipient",
				})
			}

			// Execute
			project, err := lp.GetProject(projectID)

			// Verify
			if tt.expectedHasError {
				uassert.Error(t, err)
				uassert.True(t, project == nil)
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.NoError(t, err)
				if tt.expectedNotNil {
					uassert.NotNil(t, project)
					uassert.Equal(t, "Test Project", project.Name())
				}
			}
		})
	}
}

func TestGetProjectName(t *testing.T) {
	tests := []struct {
		name             string
		projectName      string
		getExisting      bool
		expectedHasError bool
		expectedError    string
	}{
		{
			name:             "get existing project name",
			projectName:      "Test Project Name",
			getExisting:      true,
			expectedHasError: false,
		},
		{
			name:             "get non-existent project name",
			projectName:      "",
			getExisting:      false,
			expectedHasError: true,
			expectedError:    "project not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			setupTestEnvironment(t, testEnvConfig{})
			lp := getTestImplementation()
			launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
			_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

			var projectID string
			if tt.getExisting {
				projectID = createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
					name:            tt.projectName,
					rewardAmount:    1000000,
					tier30Pct:       25,
					tier90Pct:       50,
					tier180Pct:      25,
					recipientSuffix: "recipient",
				})
			} else {
				projectID = "nonexistent-project-id"
			}

			// Execute
			name, err := lp.GetProjectName(projectID)

			// Verify
			if tt.expectedHasError {
				uassert.Error(t, err)
				uassert.Equal(t, "", name)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tt.projectName, name)
			}
		})
	}
}

func TestGetProjectTokenPath(t *testing.T) {
	tests := []struct {
		name             string
		tokenPath        string
		getExisting      bool
		expectedHasError bool
	}{
		{
			name:             "get existing project token path",
			tokenPath:        testOblTokenPath,
			getExisting:      true,
			expectedHasError: false,
		},
		{
			name:             "get non-existent project token path",
			tokenPath:        "",
			getExisting:      false,
			expectedHasError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			setupTestEnvironment(t, testEnvConfig{})
			lp := getTestImplementation()
			launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
			_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

			var projectID string
			if tt.getExisting {
				projectID = createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
					name:            "Test Project",
					tokenPath:       tt.tokenPath,
					rewardAmount:    1000000,
					tier30Pct:       25,
					tier90Pct:       50,
					tier180Pct:      25,
					recipientSuffix: "recipient",
				})
			} else {
				projectID = "nonexistent-project-id"
			}

			// Execute
			tokenPath, err := lp.GetProjectTokenPath(projectID)

			// Verify
			if tt.expectedHasError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tt.tokenPath, tokenPath)
			}
		})
	}
}

func TestGetProjectDepositAmount(t *testing.T) {
	tests := []struct {
		name             string
		rewardAmount     int64
		getExisting      bool
		expectedHasError bool
	}{
		{
			name:             "get existing project deposit amount",
			rewardAmount:     1000000,
			getExisting:      true,
			expectedHasError: false,
		},
		{
			name:             "get non-existent project deposit amount",
			rewardAmount:     0,
			getExisting:      false,
			expectedHasError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			setupTestEnvironment(t, testEnvConfig{})
			lp := getTestImplementation()
			launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
			_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

			var projectID string
			if tt.getExisting {
				projectID = createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
					name:            "Test Project",
					rewardAmount:    tt.rewardAmount,
					tier30Pct:       25,
					tier90Pct:       50,
					tier180Pct:      25,
					recipientSuffix: "recipient",
				})
			} else {
				projectID = "nonexistent-project-id"
			}

			// Execute
			depositAmount, err := lp.GetProjectDepositAmount(projectID)

			// Verify
			if tt.expectedHasError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tt.rewardAmount, depositAmount)
			}
		})
	}
}

func TestGetProjectRecipient(t *testing.T) {
	t.Run("get existing project recipient", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		recipientAddr := testutils.TestAddress("test-recipient")
		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "test-recipient",
		})

		// Execute
		recipient, err := lp.GetProjectRecipient(projectID)

		// Verify
		uassert.NoError(t, err)
		uassert.Equal(t, recipientAddr, recipient)
	})

	t.Run("get non-existent project recipient", func(t *testing.T) {
		// Setup
		resetTestStore()
		initTestStore()
		lp := getTestImplementation()

		// Execute
		recipient, err := lp.GetProjectRecipient("nonexistent-project-id")

		// Verify
		uassert.Error(t, err)
		uassert.True(t, recipient == address(""))
	})
}

func TestGetProjectCreatedHeight(t *testing.T) {
	t.Run("get existing project created height", func(t *testing.T) {
		// Setup
		cfg := testEnvConfig{height: 100}
		setupTestEnvironment(t, cfg)
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, cfg)

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		createdHeight, err := lp.GetProjectCreatedHeight(projectID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, createdHeight > 0)
	})
}

func TestGetProjectCreatedAt(t *testing.T) {
	t.Run("get existing project created at", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		createdAt, err := lp.GetProjectCreatedAt(projectID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, createdAt > 0)
	})
}

func TestGetProjectTiersRatios(t *testing.T) {
	t.Run("get existing project tiers ratios", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		tier30Pct := int64(25)
		tier90Pct := int64(50)
		tier180Pct := int64(25)

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:        "Test Project",
			rewardAmount:    1000000,
			tier30Pct:   tier30Pct,
			tier90Pct:   tier90Pct,
			tier180Pct:  tier180Pct,
			recipientSuffix: "recipient",
		})

		// Execute
		ratios, err := lp.GetProjectTiersRatios(projectID)

		// Verify
		uassert.NoError(t, err)
		uassert.NotNil(t, ratios)
		uassert.Equal(t, tier30Pct, ratios[projectTier30])
		uassert.Equal(t, tier90Pct, ratios[projectTier90])
		uassert.Equal(t, tier180Pct, ratios[projectTier180])
	})
}

func TestGetProjectTier(t *testing.T) {
	tests := []struct {
		name             string
		tier             int64
		getExisting      bool
		expectedHasError bool
	}{
		{
			name:             "get existing project tier 30",
			tier:             projectTier30,
			getExisting:      true,
			expectedHasError: false,
		},
		{
			name:             "get existing project tier 90",
			tier:             projectTier90,
			getExisting:      true,
			expectedHasError: false,
		},
		{
			name:             "get non-existent tier",
			tier:             999,
			getExisting:      true,
			expectedHasError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			setupTestEnvironment(t, testEnvConfig{})
			lp := getTestImplementation()
			launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
			_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

			projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
				name:            "Test Project",
				rewardAmount:    1000000,
				tier30Pct:       25,
				tier90Pct:       50,
				tier180Pct:      25,
				recipientSuffix: "recipient",
			})

			// Execute
			tier, err := lp.GetProjectTier(projectID, tt.tier)

			// Verify
			if tt.expectedHasError {
				uassert.Error(t, err)
				uassert.True(t, tier == nil)
			} else {
				uassert.NoError(t, err)
				uassert.NotNil(t, tier)
				uassert.True(t, tier.StartTime() > 0)
			}
		})
	}
}

func TestGetProjectTierTotalDistributeAmount(t *testing.T) {
	t.Run("get project tier total distribute amount", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		totalDistribute, err := lp.GetProjectTierTotalDistributeAmount(projectID, projectTier30)

		// Verify
		uassert.NoError(t, err)
		uassert.Equal(t, int64(250000), totalDistribute) // 25% of 1000000
	})
}

func TestGetProjectTierStartTime(t *testing.T) {
	t.Run("get project tier start time", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		startTime, err := lp.GetProjectTierStartTime(projectID, projectTier30)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, startTime > 0)
	})
}

func TestGetProjectTierEndTime(t *testing.T) {
	t.Run("get project tier end time", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		endTime, err := lp.GetProjectTierEndTime(projectID, projectTier30)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, endTime > 0)
	})
}

func TestGetProjectActiveStatus(t *testing.T) {
	t.Run("get project active status", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		isActive, err := lp.GetProjectActiveStatus(projectID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, isActive)
	})
}

func TestGetDepositCount(t *testing.T) {
	t.Run("empty store returns zero deposit count", func(t *testing.T) {
		// Setup
		resetTestStore()
		initTestStore()
		lp := getTestImplementation()

		// Execute
		count := lp.GetDepositCount()

		// Verify
		uassert.Equal(t, int64(0), count)
	})

	t.Run("deposit count increases with new deposits", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
			userSuffix:    "user1",
			depositAmount: 1000000,
			tier:          30,
		})

		// Execute
		count := lp.GetDepositCount()

		// Verify
		uassert.Equal(t, int64(1), count)
	})
}

func TestGetCurrentDepositId(t *testing.T) {
	t.Run("initial deposit counter is zero", func(t *testing.T) {
		// Setup
		resetTestStore()
		initTestStore()
		lp := getTestImplementation()

		// Execute
		currentID := lp.GetCurrentDepositId()

		// Verify
		uassert.Equal(t, int64(0), currentID)
	})
}

func TestGetDeposit(t *testing.T) {
	tests := []struct {
		name             string
		createDeposit    bool
		expectedHasError bool
		expectedError    string
	}{
		{
			name:             "get existing deposit",
			createDeposit:    true,
			expectedHasError: false,
		},
		{
			name:             "get non-existent deposit",
			createDeposit:    false,
			expectedHasError: true,
			expectedError:    "deposit not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			setupTestEnvironment(t, testEnvConfig{})
			lp := getTestImplementation()
			launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
			_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

			var depositID string
			if tt.createDeposit {
				projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
					name:            "Test Project",
					rewardAmount:    1000000,
					tier30Pct:       25,
					tier90Pct:       50,
					tier180Pct:      25,
					recipientSuffix: "recipient",
				})

				_, depositID = createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
					userSuffix:    "user1",
					depositAmount: 1000000,
					tier:          30,
				})
			} else {
				depositID = "nonexistent-deposit-id"
			}

			// Execute
			deposit, err := lp.GetDeposit(depositID)

			// Verify
			if tt.expectedHasError {
				uassert.Error(t, err)
				uassert.True(t, deposit == nil)
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.NoError(t, err)
				uassert.NotNil(t, deposit)
			}
		})
	}
}

func TestGetDepositProjectID(t *testing.T) {
	t.Run("get deposit project id", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		_, depositID := createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
			userSuffix:    "user1",
			depositAmount: 1000000,
			tier:          30,
		})

		// Execute
		retrievedProjectID, err := lp.GetDepositProjectID(depositID)

		// Verify
		uassert.NoError(t, err)
		uassert.Equal(t, projectID, retrievedProjectID)
	})
}

func TestGetDepositTier(t *testing.T) {
	tests := []struct {
		name             string
		tier             int64
		expectedHasError bool
	}{
		{
			name:             "get deposit tier 30",
			tier:             30,
			expectedHasError: false,
		},
		{
			name:             "get deposit tier 90",
			tier:             90,
			expectedHasError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			setupTestEnvironment(t, testEnvConfig{})
			lp := getTestImplementation()
			launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
			_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

			projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
				name:            "Test Project",
				rewardAmount:    1000000,
				tier30Pct:       25,
				tier90Pct:       50,
				tier180Pct:      25,
				recipientSuffix: "recipient",
			})

			_, depositID := createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
				userSuffix:    "user1",
				depositAmount: 1000000,
				tier:          tt.tier,
			})

			// Execute
			tier, err := lp.GetDepositTier(depositID)

			// Verify
			if tt.expectedHasError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tt.tier, tier)
			}
		})
	}
}

func TestGetDepositAmount(t *testing.T) {
	t.Run("get deposit amount", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		depositAmount := int64(1000000)
		_, depositID := createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
			userSuffix:    "user1",
			depositAmount: depositAmount,
			tier:          30,
		})

		// Execute
		amount, err := lp.GetDepositAmount(depositID)

		// Verify
		uassert.NoError(t, err)
		uassert.Equal(t, depositAmount, amount)
	})
}

func TestGetRewardManager(t *testing.T) {
	tests := []struct {
		name             string
		createProject    bool
		expectedHasError bool
		expectedError    string
	}{
		{
			name:             "get existing reward manager",
			createProject:    true,
			expectedHasError: false,
		},
		{
			name:             "get non-existent reward manager",
			createProject:    false,
			expectedHasError: true,
			expectedError:    "reward manager not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			setupTestEnvironment(t, testEnvConfig{})
			lp := getTestImplementation()
			launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
			_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

			var projectTierID string
			if tt.createProject {
				projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
					name:            "Test Project",
					rewardAmount:    1000000,
					tier30Pct:       25,
					tier90Pct:       50,
					tier180Pct:      25,
					recipientSuffix: "recipient",
				})
				projectTierID = projectID + ":" + formatInt(projectTier30)
			} else {
				projectTierID = "nonexistent-project-tier-id"
			}

			// Execute
			manager, err := lp.GetRewardManager(projectTierID)

			// Verify
			if tt.expectedHasError {
				uassert.Error(t, err)
				uassert.True(t, manager == nil)
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.NoError(t, err)
				uassert.NotNil(t, manager)
			}
		})
	}
}

func TestGetRewardManagerTotalDistributeAmount(t *testing.T) {
	t.Run("get reward manager total distribute amount", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		projectTierID := projectID + ":" + formatInt(projectTier30)

		// Execute
		totalDistribute, err := lp.GetRewardManagerTotalDistributeAmount(projectTierID)

		// Verify
		uassert.NoError(t, err)
		uassert.Equal(t, int64(250000), totalDistribute)
	})
}

func TestGetRewardManagerDistributeStartTime(t *testing.T) {
	t.Run("get reward manager distribute start time", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		projectTierID := projectID + ":" + formatInt(projectTier30)

		// Execute
		startTime, err := lp.GetRewardManagerDistributeStartTime(projectTierID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, startTime > 0)
	})
}

func TestGetRewardManagerDistributeEndTime(t *testing.T) {
	t.Run("get reward manager distribute end time", func(t *testing.T) {
		// Setup
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		projectTierID := projectID + ":" + formatInt(projectTier30)

		// Execute
		endTime, err := lp.GetRewardManagerDistributeEndTime(projectTierID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, endTime > 0)
	})
}

func TestGetRewardState(t *testing.T) {
	tests := []struct {
		name             string
		createDeposit    bool
		expectedHasError bool
		expectedError    string
	}{
		{
			name:             "get existing reward state",
			createDeposit:    true,
			expectedHasError: false,
		},
		{
			name:             "get reward state with non-existent project tier",
			createDeposit:    false,
			expectedHasError: true,
			expectedError:    "reward manager not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			setupTestEnvironment(t, testEnvConfig{})
			lp := getTestImplementation()
			launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
			_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

			var projectTierID, depositID string
			if tt.createDeposit {
				projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
					name:            "Test Project",
					rewardAmount:    1000000,
					tier30Pct:       25,
					tier90Pct:       50,
					tier180Pct:      25,
					recipientSuffix: "recipient",
				})

				_, depositID = createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
					userSuffix:    "user1",
					depositAmount: 1000000,
					tier:          30,
				})

				projectTierID = projectID + ":" + formatInt(30)
			} else {
				projectTierID = "nonexistent-project-tier-id"
				depositID = "nonexistent-deposit-id"
			}

			// Execute
			rewardState, err := lp.GetRewardState(projectTierID, depositID)

			// Verify
			if tt.expectedHasError {
				uassert.Error(t, err)
				uassert.True(t, rewardState == nil)
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.NoError(t, err)
				uassert.NotNil(t, rewardState)
			}
		})
	}
}

func TestGetDepositIDs(t *testing.T) {
	t.Run("get deposit ids pagination", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
			userSuffix:    "user1",
			depositAmount: 1000000,
			tier:          30,
		})

		// Execute
		ids := lp.GetDepositIDs(0, 10)

		// Verify
		uassert.True(t, len(ids) > 0)
	})
}

func TestGetDepositProjectTierID(t *testing.T) {
	t.Run("get deposit project tier id", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		_, depositID := createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
			userSuffix:    "user1",
			depositAmount: 1000000,
			tier:          30,
		})

		// Execute
		projectTierID, err := lp.GetDepositProjectTierID(depositID)

		// Verify
		uassert.NoError(t, err)
		uassert.Equal(t, projectID+":"+formatInt(30), projectTierID)
	})
}

func TestGetDepositCreatedHeight(t *testing.T) {
	t.Run("get deposit created height", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		_, depositID := createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
			userSuffix:    "user1",
			depositAmount: 1000000,
			tier:          30,
		})

		// Execute
		height, err := lp.GetDepositCreatedHeight(depositID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, height > 0)
	})
}

func TestGetDepositCreatedAt(t *testing.T) {
	t.Run("get deposit created at", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		_, depositID := createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
			userSuffix:    "user1",
			depositAmount: 1000000,
			tier:          30,
		})

		// Execute
		createdAt, err := lp.GetDepositCreatedAt(depositID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, createdAt > 0)
	})
}

func TestGetDepositEndTime(t *testing.T) {
	t.Run("get deposit end time", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		_, depositID := createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
			userSuffix:    "user1",
			depositAmount: 1000000,
			tier:          30,
		})

		// Execute
		endTime, err := lp.GetDepositEndTime(depositID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, endTime > 0)
	})
}

func TestGetDepositWithdrawnHeight(t *testing.T) {
	t.Run("get deposit withdrawn height", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		_, depositID := createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
			userSuffix:    "user1",
			depositAmount: 1000000,
			tier:          30,
		})

		// Execute
		height, err := lp.GetDepositWithdrawnHeight(depositID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, height >= 0)
	})
}

func TestGetDepositWithdrawnTime(t *testing.T) {
	t.Run("get deposit withdrawn time", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		_, depositID := createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
			userSuffix:    "user1",
			depositAmount: 1000000,
			tier:          30,
		})

		// Execute
		time, err := lp.GetDepositWithdrawnTime(depositID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, time >= 0)
	})
}

func TestGetProjectTierDistributeAmountPerSecondX128(t *testing.T) {
	t.Run("get project tier distribute amount per second x128", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		amount, err := lp.GetProjectTierDistributeAmountPerSecondX128(projectID, projectTier30)

		// Verify
		uassert.NoError(t, err)
		uassert.NotNil(t, amount)
	})
}

func TestGetProjectTierTotalDepositAmount(t *testing.T) {
	t.Run("get project tier total deposit amount", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		amount, err := lp.GetProjectTierTotalDepositAmount(projectID, projectTier30)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, amount >= 0)
	})
}

func TestGetProjectTierTotalWithdrawAmount(t *testing.T) {
	t.Run("get project tier total withdraw amount", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		amount, err := lp.GetProjectTierTotalWithdrawAmount(projectID, projectTier30)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, amount >= 0)
	})
}

func TestGetProjectTierTotalDepositCount(t *testing.T) {
	t.Run("get project tier total deposit count", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		count, err := lp.GetProjectTierTotalDepositCount(projectID, projectTier30)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, count >= 0)
	})
}

func TestGetProjectTierTotalWithdrawCount(t *testing.T) {
	t.Run("get project tier total withdraw count", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		count, err := lp.GetProjectTierTotalWithdrawCount(projectID, projectTier30)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, count >= 0)
	})
}

func TestGetProjectTierTotalCollectedAmount(t *testing.T) {
	t.Run("get project tier total collected amount", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		amount, err := lp.GetProjectTierTotalCollectedAmount(projectID, projectTier30)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, amount >= 0)
	})
}

func TestGetRewardManagerCount(t *testing.T) {
	t.Run("get reward manager count", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		_ = createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		count := lp.GetRewardManagerCount()

		// Verify
		uassert.True(t, count > 0)
	})
}

func TestGetRewardManagerIDs(t *testing.T) {
	t.Run("get reward manager ids", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		_ = createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		// Execute
		ids := lp.GetRewardManagerIDs(0, 10)

		// Verify
		uassert.True(t, len(ids) > 0)
	})
}

func TestGetRewardManagerDistibuteAmountPerSecondX128(t *testing.T) {
	t.Run("get reward manager distribute amount per second x128", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		projectTierID := projectID + ":" + formatInt(projectTier30)

		// Execute
		amount, err := lp.GetRewardManagerDistibuteAmountPerSecondX128(projectTierID)

		// Verify
		uassert.NoError(t, err)
		uassert.NotNil(t, amount)
	})
}

func TestGetRewardManagerAccumulatedRewardPerDepositX128(t *testing.T) {
	t.Run("get reward manager accumulated reward per deposit x128", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		projectTierID := projectID + ":" + formatInt(projectTier30)

		// Execute
		amount, err := lp.GetRewardManagerAccumulatedRewardPerDepositX128(projectTierID)

		// Verify
		uassert.NoError(t, err)
		uassert.NotNil(t, amount)
	})
}

func TestGetRewardManagerTotalClaimedAmount(t *testing.T) {
	t.Run("get reward manager total claimed amount", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		projectTierID := projectID + ":" + formatInt(projectTier30)

		// Execute
		amount, err := lp.GetRewardManagerTotalClaimedAmount(projectTierID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, amount >= 0)
	})
}

func TestGetRewardManagerAccumulatedDistributeAmount(t *testing.T) {
	t.Run("get reward manager accumulated distribute amount", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		projectTierID := projectID + ":" + formatInt(projectTier30)

		// Execute
		amount, err := lp.GetRewardManagerAccumulatedDistributeAmount(projectTierID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, amount >= 0)
	})
}

func TestGetRewardManagerAccumulatedHeight(t *testing.T) {
	t.Run("get reward manager accumulated height", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		projectTierID := projectID + ":" + formatInt(projectTier30)

		// Execute
		height, err := lp.GetRewardManagerAccumulatedHeight(projectTierID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, height >= 0)
	})
}

func TestGetRewardManagerAccumulatedTime(t *testing.T) {
	t.Run("get reward manager accumulated time", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		projectTierID := projectID + ":" + formatInt(projectTier30)

		// Execute
		time, err := lp.GetRewardManagerAccumulatedTime(projectTierID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, time >= 0)
	})
}

func TestGetRewardManagerRewardClaimableDuration(t *testing.T) {
	t.Run("get reward manager reward claimable duration", func(t *testing.T) {
		setupTestEnvironment(t, testEnvConfig{})
		lp := getTestImplementation()
		launchpadAddr := chain.PackageAddress(testLaunchpadPkgPath)
		_, adminRealm := setupTestEnvironment(t, testEnvConfig{})

		projectID := createTestProject(t, lp, launchpadAddr, adminRealm, testProjectConfig{
			name:            "Test Project",
			rewardAmount:    1000000,
			tier30Pct:       25,
			tier90Pct:       50,
			tier180Pct:      25,
			recipientSuffix: "recipient",
		})

		projectTierID := projectID + ":" + formatInt(projectTier30)

		// Execute
		duration, err := lp.GetRewardManagerRewardClaimableDuration(projectTierID)

		// Verify
		uassert.NoError(t, err)
		uassert.True(t, duration >= 0)
	})
}
