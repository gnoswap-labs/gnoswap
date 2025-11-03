package v1

import (
	"chain/runtime"
	"strings"
	"testing"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/launchpad"
	"gno.land/r/onbloc/obl"

	_ "gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/foo"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestLaunchpadProject_CreateProjectShouldFail(t *testing.T) {
	adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
	launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	oblPath := "gno.land/r/onbloc/obl"
	tests := []struct {
		name                 string
		projectName          string
		tokenPath            string
		recipient            address
		depositAmount        int64
		conditionTokens      string
		conditionAmounts     string
		tier30Ratio          int64
		tier90Ratio          int64
		tier180Ratio         int64
		startTime            int64
		callerAddress        address
		averageBlockTimeMs   int64
		expectedProjectID    string
		expectedStartHeight  int64
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:                 "create project failed by start time is in the past",
			projectName:          "Obl Protocol",
			tokenPath:            oblPath,
			recipient:            testutils.TestAddress("projectAddr"),
			depositAmount:        1_000_000_000,
			conditionTokens:      "gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar",
			conditionAmounts:     "1000*PAD*2000",
			tier30Ratio:          10,
			tier90Ratio:          20,
			tier180Ratio:         70,
			startTime:            time.Now().Unix() - 3600, // 1 hour
			callerAddress:        adminAddr,
			expectedHasAbort:     true,
			expectedAbortMessage: "[GNOSWAP-LAUNCHPAD-007] invalid input data || start time(1234564290) must be greater than now(1234571490)",
		},
		{
			name:                 "create project failed by start time is less than minimum start delay time",
			projectName:          "Obl Protocol",
			tokenPath:            oblPath,
			recipient:            testutils.TestAddress("projectAddr"),
			depositAmount:        1_000_000_000,
			conditionTokens:      "gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar",
			conditionAmounts:     "1000*PAD*2000",
			tier30Ratio:          10,
			tier90Ratio:          20,
			tier180Ratio:         70,
			startTime:            time.Now().Unix() + 3600 - 1, // 1 hour
			callerAddress:        adminAddr,
			expectedHasAbort:     true,
			expectedAbortMessage: "[GNOSWAP-LAUNCHPAD-007] invalid input data || start time(1234571489) must be greater than now(1234571490)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadProjectTest(t)
			initLaunchpadProjectTestAvgBlockTime(t, tt.averageBlockTimeMs)
			testing.SetOriginCaller(tt.callerAddress)

			obl.Approve(cross, launchpadAddr, int64(tt.depositAmount))

			createProjectFn := func() {
				launchpad.CreateProject(
					cross,
					tt.projectName,
					tt.tokenPath,
					tt.recipient,
					tt.depositAmount,
					tt.conditionTokens,
					tt.conditionAmounts,
					tt.tier30Ratio,
					tt.tier90Ratio,
					tt.tier180Ratio,
					tt.startTime,
				)
			}

			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMessage, createProjectFn)
				return
			}

			createProjectFn()

			lp := getTestImplementation()
			project, err := lp.getProject(tt.expectedProjectID)
			uassert.NoError(t, err)

			uassert.Equal(t, project.ID(), tt.expectedProjectID)
			uassert.Equal(t, project.StartTime(), tt.startTime)
		})
	}
}

func TestLaunchpadProject_CreateProjectInternal(t *testing.T) {
	launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	projectAddr := testutils.TestAddress("projectAddr")
	oblPath := "gno.land/r/onbloc/obl"
	tests := []struct {
		name                 string
		params               *createProjectParams
		expectedProjectID    string
		expectedHasError     bool
		expectedErrorMessage string
	}{
		{
			name: "create project successfully",
			params: &createProjectParams{
				name:             "Obl Protocol",
				tokenPath:        oblPath,
				recipient:        projectAddr,
				depositAmount:    1_000_000_000,
				conditionTokens:  "gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar",
				conditionAmounts: "1000*PAD*2000",
				tier30Ratio:      int64(10),
				tier90Ratio:      int64(20),
				tier180Ratio:     int64(70),
				currentTime:      int64(time.Now().Unix()),
				currentHeight:    runtime.ChainHeight(),
				startTime:        int64(time.Now().Unix() + 3600), // 1 hour
			},
			expectedProjectID:    "gno.land/r/onbloc/obl:123",
			expectedHasError:     false,
			expectedErrorMessage: "",
		},
		{
			name: "create project successfully by 30:40:30 ratio",
			params: &createProjectParams{
				name:             "Obl Protocol",
				tokenPath:        oblPath,
				recipient:        projectAddr,
				depositAmount:    1_000_000_000,
				conditionTokens:  "gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar",
				conditionAmounts: "1000*PAD*2000",
				tier30Ratio:      int64(30),
				tier90Ratio:      int64(40),
				tier180Ratio:     int64(30),
				currentTime:      int64(time.Now().Unix()),
				currentHeight:    runtime.ChainHeight(),
				startTime:        int64(time.Now().Unix() + 3600),
			},
			expectedProjectID:    "gno.land/r/onbloc/obl:123",
			expectedHasError:     false,
			expectedErrorMessage: "",
		},
		{
			name: "create project failed by invalid ratio sum (less than 100%)",
			params: &createProjectParams{
				name:             "Invalid Ratio",
				tokenPath:        oblPath,
				recipient:        projectAddr,
				depositAmount:    1_000_000_000,
				conditionTokens:  "gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar",
				conditionAmounts: "1000*PAD*2000",
				tier30Ratio:      int64(10),
				tier90Ratio:      int64(20),
				tier180Ratio:     int64(60),
				currentTime:      int64(time.Now().Unix()),
				currentHeight:    runtime.ChainHeight(),
				startTime:        int64(time.Now().Unix() + 3600),
			},
			expectedHasError:     true,
			expectedErrorMessage: "[GNOSWAP-LAUNCHPAD-007] invalid input data || invalid ratio, sum of all tiers(30:10, 90:20, 180:60) should be 100",
		},
		{
			name: "create project failed by project name is empty",
			params: &createProjectParams{
				name:             "",
				tokenPath:        oblPath,
				recipient:        projectAddr,
				depositAmount:    1_000_000_000,
				conditionTokens:  "gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar",
				conditionAmounts: "1000*PAD*2000",
				tier30Ratio:      int64(10),
				tier90Ratio:      int64(20),
				tier180Ratio:     int64(70),
				currentTime:      int64(time.Now().Unix()),
				currentHeight:    runtime.ChainHeight(),
				startTime:        int64(time.Now().Unix() + 3600),
			},
			expectedHasError:     true,
			expectedErrorMessage: "[GNOSWAP-LAUNCHPAD-007] invalid input data || project name cannot be empty",
		},
		{
			name: "create project failed by project owner address is invalid",
			params: &createProjectParams{
				name:             "TTT",
				tokenPath:        oblPath,
				recipient:        address("abcdef"),
				depositAmount:    1_000_000_000,
				conditionTokens:  "gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar",
				conditionAmounts: "1000*PAD*2000",
				tier30Ratio:      int64(10),
				tier90Ratio:      int64(20),
				tier180Ratio:     int64(70),
				currentTime:      int64(time.Now().Unix()),
				currentHeight:    runtime.ChainHeight(),
				startTime:        int64(time.Now().Unix() + 3600),
			},
			expectedHasError:     true,
			expectedErrorMessage: "[GNOSWAP-LAUNCHPAD-002] invalid address || recipient address(abcdef)",
		},
		{
			name: "create project failed by invalid start time",
			params: &createProjectParams{
				name:                  "Obl Protocol",
				tokenPath:             oblPath,
				recipient:             projectAddr,
				depositAmount:         1_000_000_000,
				conditionTokens:       "gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar",
				conditionAmounts:      "1000*PAD*2000",
				tier30Ratio:           int64(10),
				tier90Ratio:           int64(20),
				tier180Ratio:          int64(70),
				currentTime:           int64(time.Now().Unix()),
				currentHeight:         runtime.ChainHeight(),
				startTime:             int64(time.Now().Unix() + 3600 - 1), // 1 hour - 1 second
				minimumStartDelayTime: 3600,
			},
			expectedHasError:     true,
			expectedErrorMessage: "[GNOSWAP-LAUNCHPAD-007] invalid input data || start time(1234571489) must be greater than now(1234571490)",
		},
		{
			name: "create project failed by invalid token path",
			params: &createProjectParams{
				name:                  "Obl Protocol",
				tokenPath:             "gno.land/r/test/token",
				recipient:             projectAddr,
				depositAmount:         1_000_000_000,
				conditionTokens:       "gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar",
				conditionAmounts:      "1000*PAD*2000",
				tier30Ratio:           int64(10),
				tier90Ratio:           int64(20),
				tier180Ratio:          int64(70),
				currentTime:           int64(time.Now().Unix()),
				currentHeight:         runtime.ChainHeight(),
				startTime:             int64(time.Now().Unix() + 3600 - 1), // 1 hour - 1 second
				minimumStartDelayTime: 3600,
			},
			expectedHasError:     true,
			expectedErrorMessage: "[GNOSWAP-LAUNCHPAD-007] invalid input data || tokenPath(gno.land/r/test/token) not registered",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadProjectTest(t)
			lp := getTestImplementation()
			testing.SetOriginCaller(projectAddr)

			obl.Approve(cross, launchpadAddr, int64(tt.params.depositAmount))

			projectId, err := lp.createProject(tt.params)

			if tt.expectedHasError {
				uassert.Equal(t, err.Error(), tt.expectedErrorMessage)
				return
			}

			uassert.Equal(t, projectId.ID(), tt.expectedProjectID)
		})
	}
}

func TestLaunchpadProject_CreateProjectPrivateMultiple(t *testing.T) {
	launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	projectAddr := testutils.TestAddress("projectAddr")
	oblPath := "gno.land/r/onbloc/obl"
	tests := []struct {
		name                 string
		setupProjectIds      []string
		params               *createProjectParams
		expectedProjectID    string
		expectedHasError     bool
		expectedErrorMessage string
	}{
		{
			name: "create project successfully",
			setupProjectIds: []string{
				"gno.land/r/onbloc/obl:1",
			},
			params: &createProjectParams{
				name:             "Obl Protocol",
				tokenPath:        oblPath,
				recipient:        projectAddr,
				depositAmount:    1_000_000_000,
				conditionTokens:  "gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar",
				conditionAmounts: "1000*PAD*2000",
				tier30Ratio:      int64(10),
				tier90Ratio:      int64(20),
				tier180Ratio:     int64(70),
				currentTime:      int64(time.Now().Unix()),
				currentHeight:    runtime.ChainHeight(),
				startTime:        int64(time.Now().Unix() + 3600), // 1 hour
			},
			expectedProjectID:    "gno.land/r/onbloc/obl:123",
			expectedHasError:     false,
			expectedErrorMessage: "",
		},
		{
			name: "create project failed by duplicate project id",
			setupProjectIds: []string{
				"gno.land/r/onbloc/obl:123",
			},
			params: &createProjectParams{
				name:             "Obl Protocol",
				tokenPath:        oblPath,
				recipient:        projectAddr,
				depositAmount:    1_000_000_000,
				conditionTokens:  "gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar",
				conditionAmounts: "1000*PAD*2000",
				tier30Ratio:      int64(10),
				tier90Ratio:      int64(20),
				tier180Ratio:     int64(70),
				currentTime:      int64(time.Now().Unix()),
				currentHeight:    runtime.ChainHeight(),
				startTime:        int64(time.Now().Unix() + 3600), // 1 hour
			},
			expectedHasError:     true,
			expectedErrorMessage: "[GNOSWAP-LAUNCHPAD-008] can not create same project in same block || project(gno.land/r/onbloc/obl:123) already exists",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadProjectTest(t)
			lp := getTestImplementation()
			for _, projectID := range tt.setupProjectIds {
				setupLaunchpadProjectTestEmptyProject(t, projectID)
			}

			obl.Approve(cross, launchpadAddr, int64(tt.params.depositAmount))

			projectId, err := lp.createProject(tt.params)

			if tt.expectedHasError {
				uassert.Equal(t, err.Error(), tt.expectedErrorMessage)
				return
			}

			uassert.Equal(t, projectId.ID(), tt.expectedProjectID)
		})
	}
}

func TestLaunchpadProject_CreateProjectParamsValidatName(t *testing.T) {
	tests := []struct {
		name          string
		projectName   string
		expectedError error
	}{
		{
			name:          "project name is valid",
			projectName:   "Obl Protocol",
			expectedError: nil,
		},
		{
			name:          "project name is empty",
			projectName:   "",
			expectedError: errInvalidInput,
		},
		{
			name:          "project name is too long",
			projectName:   strings.Repeat("a", 101), // 101 characters
			expectedError: errInvalidInput,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			params := &createProjectParams{
				name: test.projectName,
			}

			err := params.validateName()

			if test.expectedError == nil {
				uassert.NoError(t, err)
			} else {
				uassert.ErrorContains(t, err, test.expectedError.Error())
			}
		})
	}
}

func TestLaunchpadProject_CreateProjectParamsValidateTokenPath(t *testing.T) {
	tests := []struct {
		name          string
		tokenPath     string
		expectedError error
	}{
		{
			name:          "token path is valid",
			tokenPath:     "gno.land/r/onbloc/obl",
			expectedError: nil,
		},
		{
			name:          "token path is empty",
			tokenPath:     "",
			expectedError: errInvalidInput,
		},
		{
			name:          "token path is not registered",
			tokenPath:     "gno.land/r/test/non-registered",
			expectedError: errInvalidInput,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			params := &createProjectParams{
				tokenPath: test.tokenPath,
			}

			err := params.validateTokenPath()

			if test.expectedError == nil {
				uassert.NoError(t, err)
			} else {
				uassert.ErrorContains(t, err, test.expectedError.Error())
			}
		})
	}
}

func TestLaunchpadProject_CreateProjectParamsValidateRecipient(t *testing.T) {
	tests := []struct {
		name          string
		recipient     address
		expectedError error
	}{
		{
			name:          "recipient is valid",
			recipient:     testutils.TestAddress("projectAddr"),
			expectedError: nil,
		},
		{
			name:          "recipient is invalid",
			recipient:     address("invalid"),
			expectedError: errInvalidAddress,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			params := &createProjectParams{
				recipient: test.recipient,
			}

			err := params.validateRecipient()

			if test.expectedError == nil {
				uassert.NoError(t, err)
			} else {
				uassert.ErrorContains(t, err, test.expectedError.Error())
			}
		})
	}
}

func TestLaunchpadProject_CreateProjectParamsValidateDepositAmount(t *testing.T) {
	tests := []struct {
		name          string
		depositAmount int64
		expectedError error
	}{
		{
			name:          "deposit amount is valid",
			depositAmount: 1_000_000_000,
			expectedError: nil,
		},
		{
			name:          "deposit amount is zero",
			depositAmount: 0,
			expectedError: errInvalidInput,
		},
		{
			name:          "deposit amount is negative",
			depositAmount: -1,
			expectedError: errInvalidInput,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			params := &createProjectParams{
				depositAmount: test.depositAmount,
			}

			err := params.validateDepositAmount()

			if test.expectedError == nil {
				uassert.NoError(t, err)
			} else {
				uassert.ErrorContains(t, err, test.expectedError.Error())
			}
		})
	}
}

func TestLaunchpadProject_CreateProjectParamsValidateRatio(t *testing.T) {
	tests := []struct {
		name          string
		tier30Ratio   int64
		tier90Ratio   int64
		tier180Ratio  int64
		expectedError error
	}{
		{
			name:          "ratio is valid by sum is 100",
			tier30Ratio:   10,
			tier90Ratio:   20,
			tier180Ratio:  70,
			expectedError: nil,
		},
		{
			name:          "ratio is invalid by sum is not 100",
			tier30Ratio:   10,
			tier90Ratio:   20,
			tier180Ratio:  60,
			expectedError: errInvalidInput,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			params := &createProjectParams{
				tier30Ratio:  test.tier30Ratio,
				tier90Ratio:  test.tier90Ratio,
				tier180Ratio: test.tier180Ratio,
			}

			err := params.validateRatio()

			if test.expectedError == nil {
				uassert.NoError(t, err)
			} else {
				uassert.ErrorContains(t, err, test.expectedError.Error())
			}
		})
	}
}

func TestLaunchpadProject_CreateProjectParamsValidateStartTime(t *testing.T) {
	projectMinimumStartDelayTime := int64(60 * 60) // 1 hour

	tests := []struct {
		name          string
		startTime     int64
		expectedError error
	}{
		{
			name:          "start time is valid",
			startTime:     int64(time.Now().Unix() + projectMinimumStartDelayTime),
			expectedError: nil,
		},
		{
			name:          "start time is invalid by in the past",
			startTime:     int64(time.Now().Unix() - 10),
			expectedError: errInvalidInput,
		},
		{
			name:          "start time is invalid by equal to now",
			startTime:     int64(time.Now().Unix()),
			expectedError: errInvalidInput,
		},
		{
			name:          "start time is invalid by less than minimum start delay time",
			startTime:     int64(time.Now().Unix() + projectMinimumStartDelayTime - 1),
			expectedError: errInvalidInput,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			params := &createProjectParams{
				startTime: test.startTime,
			}

			err := params.validateStartTime(int64(time.Now().Unix()), projectMinimumStartDelayTime)

			if test.expectedError == nil {
				uassert.NoError(t, err)
			} else {
				uassert.ErrorContains(t, err, test.expectedError.Error())
			}
		})
	}
}

func TestLaunchpadProject_CreateProjectParamsValidateConditions(t *testing.T) {
	tests := []struct {
		name             string
		conditionTokens  string
		conditionAmounts string
		expectedError    error
	}{
		{
			name:             "conditions are valid",
			conditionTokens:  "gno.land/r/onbloc/obl*PAD*gno.land/r/onbloc/bar",
			conditionAmounts: "1000*PAD*2000",
			expectedError:    nil,
		},
		{
			name:             "conditions are invalid by not registered token path",
			conditionTokens:  "gno.land/r/onbloc/obl*PAD*gno.land/r/test/token",
			conditionAmounts: "1000*PAD*2000",
			expectedError:    errInvalidInput,
		},
		{
			name:             "conditions are invalid by zero amount",
			conditionTokens:  "gno.land/r/onbloc/obl",
			conditionAmounts: "0",
			expectedError:    errInvalidInput,
		},
		{
			name:             "conditions are invalid by condition count mismatch",
			conditionTokens:  "gno.land/r/onbloc/obl*PAD*gno.land/r/onbloc/bar",
			conditionAmounts: "1000*PAD*2000*PAD*3000",
			expectedError:    errInvalidInput,
		},
		{
			name:             "conditions are invalid by duplicated token path",
			conditionTokens:  "gno.land/r/onbloc/obl*PAD*gno.land/r/onbloc/bar*PAD*gno.land/r/onbloc/obl",
			conditionAmounts: "1000*PAD*2000*PAD*3000",
			expectedError:    errInvalidInput,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			params := &createProjectParams{
				conditionTokens:  test.conditionTokens,
				conditionAmounts: test.conditionAmounts,
			}

			err := params.validateConditions()

			if test.expectedError == nil {
				uassert.NoError(t, err)
			} else {
				uassert.ErrorContains(t, err, test.expectedError.Error())
			}
		})
	}
}

// define test methods for launchpad project
func initLaunchpadProjectTest(t *testing.T) {
	testing.SetHeight(123)
	resetTestStore()
	setTestProjects(new(avl.Tree))
	setTestProjectTierRewardManagers(new(avl.Tree))
}

func initLaunchpadProjectTestAvgBlockTime(t *testing.T, avgBlockTimeMs int64) {
	emissionAddr, _ := access.GetAddress(prbac.ROLE_EMISSION.String())
	testing.SetOriginCaller(emissionAddr)

	adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
	testing.SetOriginCaller(adminAddr)
}

func setupLaunchpadProjectTestEmptyProject(t *testing.T, projectID string) {
	projects := getTestProjects()
	project := &Project{id: projectID}
	projects.Set(projectID, project)
	setTestProjects(projects)
}

// TestLaunchpadProject_isGovernanceToken tests isGovernanceToken private function
func TestLaunchpadProject_isGovernanceToken(t *testing.T) {
	tests := []struct {
		name           string
		tokenPath      string
		expectedResult bool
	}{
		{
			name:           "returns true for governance token",
			tokenPath:      GOV_XGNS_PATH,
			expectedResult: true,
		},
		{
			name:           "returns true for xgns token path",
			tokenPath:      "gno.land/r/gnoswap/gov/xgns",
			expectedResult: true,
		},
		{
			name:           "returns false for gns token",
			tokenPath:      GNS_PATH,
			expectedResult: false,
		},
		{
			name:           "returns false for other token",
			tokenPath:      "gno.land/r/demo/token",
			expectedResult: false,
		},
		{
			name:           "returns false for empty string",
			tokenPath:      "",
			expectedResult: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isGovernanceToken(tt.tokenPath)
			uassert.Equal(t, result, tt.expectedResult)
		})
	}
}

// TestLaunchpadProject_validateRefundProject tests validateRefundProject private function
func TestLaunchpadProject_validateRefundProject(t *testing.T) {
	testAddr := testutils.TestAddress("recipient")

	tests := []struct {
		name                  string
		tierStartTime         int64
		tierEndTime           int64
		totalDistributeAmount int64
		totalCollectedAmount  int64
		recipient             address
		currentTime           int64
		expectedHasError      bool
		expectedError         string
	}{
		{
			name:                  "valid refund - project ended and has remaining amount",
			tierStartTime:         1000,
			tierEndTime:           2000,
			totalDistributeAmount: 100_000_000,
			totalCollectedAmount:  50_000_000,
			recipient:             testAddr,
			currentTime:           2001,
			expectedHasError:      false,
		},
		{
			name:                  "error when project has no remaining amount",
			tierStartTime:         1000,
			tierEndTime:           2000,
			totalDistributeAmount: 100_000_000,
			totalCollectedAmount:  100_000_000,
			recipient:             testAddr,
			currentTime:           2001,
			expectedHasError:      true,
			expectedError:         "no remaining amount",
		},
		{
			name:                  "error when project not ended yet",
			tierStartTime:         1000,
			tierEndTime:           2000,
			totalDistributeAmount: 100_000_000,
			totalCollectedAmount:  50_000_000,
			recipient:             testAddr,
			currentTime:           1500,
			expectedHasError:      true,
			expectedError:         "project not ended yet",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create a project with tier
			tier := &ProjectTier{
				id:                    "test:180",
				totalDistributeAmount: tt.totalDistributeAmount,
				totalCollectedAmount:  tt.totalCollectedAmount,
				startTime:             tt.tierStartTime,
				endTime:               tt.tierEndTime,
			}

			project := &Project{
				id:    "test:100",
				tiers: make(map[int64]*ProjectTier),
			}
			project.tiers[projectTier180] = tier

			err := validateRefundProject(project, tt.recipient, tt.currentTime)

			if tt.expectedHasError {
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}
