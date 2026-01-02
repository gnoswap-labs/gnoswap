package v1

import (
	"chain/runtime"
	"strings"
	"testing"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	u256 "gno.land/p/gnoswap/uint256"

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
			startTime:            time.Now().Unix() - projectMinimumStartDelayTime, // 7 days
			callerAddress:        adminAddr,
			expectedHasAbort:     true,
			expectedAbortMessage: "[GNOSWAP-LAUNCHPAD-007] invalid input data || start time(1233963090) must be greater than now(1235172690)",
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
			startTime:            time.Now().Unix() + projectMinimumStartDelayTime - 1, // 7 days
			callerAddress:        adminAddr,
			expectedHasAbort:     true,
			expectedAbortMessage: "[GNOSWAP-LAUNCHPAD-007] invalid input data || start time(1235172689) must be greater than now(1235172690)",
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
			standardTier := getStandardTier(project)
			uassert.Equal(t, standardTier.StartTime(), tt.startTime)
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
				startTime:        int64(time.Now().Unix() + projectMinimumStartDelayTime), // 7 days
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
				startTime:        int64(time.Now().Unix() + projectMinimumStartDelayTime),
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
				startTime:        int64(time.Now().Unix() + projectMinimumStartDelayTime),
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
				startTime:        int64(time.Now().Unix() + projectMinimumStartDelayTime),
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
				startTime:        int64(time.Now().Unix() + projectMinimumStartDelayTime),
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
				startTime:             int64(time.Now().Unix() + projectMinimumStartDelayTime - 1), // 7 days - 1 second
				minimumStartDelayTime: projectMinimumStartDelayTime,
			},
			expectedHasError:     true,
			expectedErrorMessage: "must be greater than now",
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
				startTime:             int64(time.Now().Unix() + projectMinimumStartDelayTime - 1), // 7 days - 1 second
				minimumStartDelayTime: projectMinimumStartDelayTime,
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
				uassert.ErrorContains(t, err, tt.expectedErrorMessage)
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
				startTime:        int64(time.Now().Unix() + projectMinimumStartDelayTime), // 7 days
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
				startTime:        int64(time.Now().Unix() + projectMinimumStartDelayTime), // 7 days
			},
			expectedHasError:     true,
			expectedErrorMessage: "[GNOSWAP-LAUNCHPAD-008] cannot create same project in same block || project(gno.land/r/onbloc/obl:123) already exists",
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
	minimumStartDelayTime := projectMinimumStartDelayTime

	tests := []struct {
		name          string
		startTime     int64
		expectedError error
	}{
		{
			name:          "start time is valid",
			startTime:     int64(time.Now().Unix() + minimumStartDelayTime),
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
			startTime:     int64(time.Now().Unix() + minimumStartDelayTime - 1),
			expectedError: errInvalidInput,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			params := &createProjectParams{
				startTime: test.startTime,
			}

			err := params.validateStartTime(int64(time.Now().Unix()), minimumStartDelayTime)

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
	project := launchpad.NewProject(projectID, "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
	project.SetID(projectID)
	projects.Set(projectID, project)
	setTestProjects(projects)
}

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
			name:                  "valid refund - project ended with remaining amount",
			tierStartTime:         1000,
			tierEndTime:           2000,
			totalDistributeAmount: 100_000_000,
			totalCollectedAmount:  50_000_000,
			recipient:             testAddr,
			currentTime:           2001,
			expectedHasError:      false,
		},
		{
			name:                  "valid refund - project ended without remaining amount",
			tierStartTime:         1000,
			tierEndTime:           2000,
			totalDistributeAmount: 100_000_000,
			totalCollectedAmount:  100_000_000,
			recipient:             testAddr,
			currentTime:           2001,
			expectedHasError:      true,
			expectedError:         "project has no remaining amount",
		},
		{
			name:                  "error when recipient is invalid",
			tierStartTime:         1000,
			tierEndTime:           2000,
			totalDistributeAmount: 100_000_000,
			totalCollectedAmount:  50_000_000,
			recipient:             address("invalid"),
			currentTime:           2001,
			expectedHasError:      true,
			expectedError:         "invalid recipient address",
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
		{
			name:                  "collected amount equals distribute amount",
			tierStartTime:         1000,
			tierEndTime:           2000,
			totalDistributeAmount: MAX_INT64,
			totalCollectedAmount:  MAX_INT64,
			recipient:             testAddr,
			currentTime:           2001,
			expectedHasError:      true,
			expectedError:         "project has no remaining amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create a project with tier
			tier := launchpad.NewProjectTier("test", 180, tt.totalDistributeAmount, tt.tierStartTime, tt.tierEndTime)
			tier.SetID("test:180")
			tier.SetTotalCollectedAmount(tt.totalCollectedAmount)

			project := launchpad.NewProject("test:100", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
			project.SetID("test:100")

			tiers := make(map[int64]*launchpad.ProjectTier)
			tiers[projectTier180] = tier
			project.SetTiers(tiers)

			err := validateRefundProject(project, tt.recipient, tt.currentTime)

			if tt.expectedHasError {
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.NoError(t, err)
			}
		})
	}

	t.Run("panic on addition overflow - multiple tiers with large remaining amounts", func(t *testing.T) {
		// Create multiple tiers with large remaining amounts that will overflow when summed
		tier30 := launchpad.NewProjectTier("test", 30, MAX_INT64/2+1, 1000, 2000)
		tier30.SetID("test:30")
		tier30.SetTotalCollectedAmount(0)

		tier90 := launchpad.NewProjectTier("test", 90, MAX_INT64/2+1, 1000, 2000)
		tier90.SetID("test:90")
		tier90.SetTotalCollectedAmount(0)

		project := launchpad.NewProject("test:100", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
		project.SetID("test:100")

		tiers := make(map[int64]*launchpad.ProjectTier)
		tiers[projectTier30] = tier30
		tiers[projectTier90] = tier90
		project.SetTiers(tiers)

		// getProjectRemainingAmount will panic when summing large remaining amounts
		uassert.PanicsContains(t, "int64 addition overflow", func() {
			getProjectRemainingAmount(project)
		})
	})

	t.Run("panic on subtraction underflow - extreme values", func(t *testing.T) {
		// Create a tier where subtraction causes underflow
		// totalDistributeAmount - totalCollectedAmount underflows
		tier := launchpad.NewProjectTier("test", 180, MIN_INT64/2, 1000, 2000)
		tier.SetID("test:180")
		tier.SetTotalCollectedAmount(MAX_INT64)

		project := launchpad.NewProject("test:100", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
		project.SetID("test:100")

		tiers := make(map[int64]*launchpad.ProjectTier)
		tiers[projectTier180] = tier
		project.SetTiers(tiers)

		// getProjectRemainingAmount will panic due to subtraction underflow
		uassert.PanicsContains(t, "int64 subtraction underflow", func() {
			getProjectRemainingAmount(project)
		})
	})
}

// TestLaunchpadProject_calculateClaimableRewardsForActiveDeposits tests that claimable rewards
// are correctly calculated for active deposits.
func TestLaunchpadProject_calculateClaimableRewardsForActiveDeposits(t *testing.T) {
	t.Run("calculate claimable rewards with active deposits", func(t *testing.T) {
		// Create reward manager with accumulated rewards
		rm := newRewardManager(100_000, 1000, 2000, 100, 1000)
		rm.SetAccumulatedRewardPerDepositX128(q128.Clone()) // 1.0 reward per deposit

		// Add reward state for deposit with priceDebt = 0.5
		// So claimable = (1.0 - 0.5) * 100,000 = 50,000
		rewardState := newRewardState(
			u256.Zero().Div(q128.Clone(), u256.NewUint(2)), // priceDebt = 0.5
			100_000, // deposit amount
			1000,    // start time
			2000,    // end time
			1100,    // claimable time
		)
		rm.Rewards().Set("deposit1", rewardState)

		// Calculate claimable rewards
		claimableRewards := calculateClaimableRewardsForActiveDeposits(rm)

		// Expected: (1.0 - 0.5) * 100,000 = 50,000
		uassert.True(t, claimableRewards > 0, "claimable rewards should be positive")
		uassert.Equal(t, int64(50_000), claimableRewards)
	})

	t.Run("no active deposits returns zero", func(t *testing.T) {
		rm := newRewardManager(100_000, 1000, 2000, 100, 1000)
		rm.SetAccumulatedRewardPerDepositX128(q128.Clone())

		// No reward states added
		claimableRewards := calculateClaimableRewardsForActiveDeposits(rm)

		uassert.Equal(t, int64(0), claimableRewards)
	})

	t.Run("multiple deposits with different claimable rewards", func(t *testing.T) {
		rm := newRewardManager(100_000, 1000, 2000, 100, 1000)
		rm.SetAccumulatedRewardPerDepositX128(q128.Clone()) // 1.0 reward per deposit

		// Deposit 1: priceDebt = 0.5, amount = 100,000 -> claimable = 50,000
		rewardState1 := newRewardState(
			u256.Zero().Div(q128.Clone(), u256.NewUint(2)), // priceDebt = 0.5
			100_000, 1000, 2000, 1100,
		)
		rm.Rewards().Set("deposit1", rewardState1)

		// Deposit 2: priceDebt = 0.25, amount = 200,000 -> claimable = 150,000
		rewardState2 := newRewardState(
			u256.Zero().Div(q128.Clone(), u256.NewUint(4)), // priceDebt = 0.25
			200_000, 1000, 2000, 1100,
		)
		rm.Rewards().Set("deposit2", rewardState2)

		claimableRewards := calculateClaimableRewardsForActiveDeposits(rm)

		// Expected: 50,000 + 150,000 = 200,000
		uassert.Equal(t, int64(200_000), claimableRewards)
	})
}

// TestLaunchpadProject_calculateTierClaimableRewards tests that tier claimable rewards
// are correctly calculated.
func TestLaunchpadProject_calculateTierClaimableRewards(t *testing.T) {
	t.Run("calculate tier claimable rewards", func(t *testing.T) {
		initLaunchpadProjectTest(t)
		lp := getTestImplementation()

		projectID := "gno.land/r/onbloc/obl:123"
		tierID := projectID + ":30"

		// Create tier
		tier := launchpad.NewProjectTier(projectID, 30, 100_000, 1000, 2000)
		tier.SetID(tierID)

		// Setup reward manager with claimable rewards
		projectTierRewardManagers := lp.store.GetProjectTierRewardManagers()
		rm := newRewardManager(100_000, 1000, 2000, 100, 1000)
		rm.SetAccumulatedRewardPerDepositX128(q128.Clone())

		rewardState := newRewardState(
			u256.Zero().Div(q128.Clone(), u256.NewUint(2)),
			100_000, 1000, 2000, 1100,
		)
		rm.Rewards().Set("deposit1", rewardState)
		projectTierRewardManagers.Set(tierID, rm)
		lp.store.SetProjectTierRewardManagers(projectTierRewardManagers)

		// Calculate claimable rewards
		claimableRewards, err := lp.calculateTierClaimableRewards(tier)
		uassert.NoError(t, err)
		uassert.Equal(t, int64(50_000), claimableRewards)
	})
}

// TestLaunchpadProject_TransferLeftFromProjectWithPendingWithdrawals tests that
// TransferLeftFromProjectByAdmin works correctly when users have pending withdrawals.
// The refundable amount should exclude claimable rewards for remaining depositors.
func TestLaunchpadProject_TransferLeftFromProjectWithPendingWithdrawals(t *testing.T) {
	tests := []struct {
		name                   string
		totalDistributeAmount  int64
		depositAmount          int64
		accumulatedRewardRatio int64 // 1 = full reward (Q128), 2 = half reward (Q128/2)
		priceDebtRatio         int64 // divisor for Q128 to get priceDebt
		expectedClaimable      int64
		expectedRefundable     int64
		expectError            bool
		expectedBalanceChange  int64
		expectedErrorContains  string
	}{
		{
			name:                   "refund with one pending deposit - half rewards claimable",
			totalDistributeAmount:  1_000_000,
			depositAmount:          100_000,
			accumulatedRewardRatio: 1, // 1.0 accumulated reward per deposit
			priceDebtRatio:         2, // priceDebt = 0.5
			expectedClaimable:      50_000,
			expectedRefundable:     950_000, // 1_000_000 - 50_000
			expectedBalanceChange:  950_000,
			expectError:            false,
		},
		{
			name:                   "refund with one pending deposit - quarter rewards claimable",
			totalDistributeAmount:  1_000_000,
			depositAmount:          100_000,
			accumulatedRewardRatio: 1, // 1.0 accumulated reward per deposit
			priceDebtRatio:         4, // priceDebt = 0.25
			expectedClaimable:      75_000,
			expectedRefundable:     925_000, // 1_000_000 - 75_000
			expectedBalanceChange:  925_000,
			expectError:            false,
		},
		{
			name:                   "refund with one pending deposit - nearly full rewards claimable",
			totalDistributeAmount:  1_000_000,
			depositAmount:          100_000,
			accumulatedRewardRatio: 1,       // 1.0 accumulated reward per deposit
			priceDebtRatio:         1000000, // priceDebt (very small due to rounding)
			expectedClaimable:      99_999,  // 100_000 - 1 (rounding)
			expectedRefundable:     900_001, // 1_000_000 - 99_999
			expectedBalanceChange:  900_001,
			expectError:            false,
		},
		{
			name:                   "refund with zero claimable - priceDebt equals accumulated",
			totalDistributeAmount:  1_000_000,
			depositAmount:          100_000,
			accumulatedRewardRatio: 1, // 1.0 accumulated reward per deposit
			priceDebtRatio:         1, // priceDebt = 1.0 (same as accumulated)
			expectedClaimable:      0,
			expectedRefundable:     1_000_000, // full refund since no claimable
			expectedBalanceChange:  1_000_000,
			expectError:            false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadProjectTest(t)
			lp := getTestImplementation()

			adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
			launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

			recipient := testutils.TestAddress("recipient")
			projectID := "gno.land/r/onbloc/obl:123"
			tierID := projectID + ":180"

			// Create project with single tier (180 days for simplicity)
			tier := launchpad.NewProjectTier(projectID, 180, tt.totalDistributeAmount, 1000, 2000)
			tier.SetID(tierID)
			tier.SetTotalDepositCount(1)    // One active depositor
			tier.SetTotalWithdrawCount(0)   // No withdrawals yet
			tier.SetTotalCollectedAmount(0) // No rewards collected yet

			project := launchpad.NewProject(projectID, "gno.land/r/onbloc/obl", 0, recipient, 100, 1000)
			project.SetID(projectID)

			tiers := make(map[int64]*launchpad.ProjectTier)
			tiers[projectTier180] = tier
			project.SetTiers(tiers)

			projects := lp.store.GetProjects()
			projects.Set(projectID, project)
			lp.store.SetProjects(projects)

			// Setup reward manager with pending claimable rewards
			projectTierRewardManagers := lp.store.GetProjectTierRewardManagers()
			rm := newRewardManager(tt.totalDistributeAmount, 1000, 2000, 100, 1000)

			// Set accumulated reward: Q128 / accumulatedRewardRatio
			accumulatedReward := u256.Zero().Div(q128.Clone(), u256.NewUint(uint64(tt.accumulatedRewardRatio)))
			rm.SetAccumulatedRewardPerDepositX128(accumulatedReward)

			// Set price debt: Q128 / priceDebtRatio
			priceDebt := u256.Zero().Div(q128.Clone(), u256.NewUint(uint64(tt.priceDebtRatio)))
			rewardState := newRewardState(priceDebt, tt.depositAmount, 1000, 2000, 1100)
			rm.Rewards().Set("deposit1", rewardState)

			projectTierRewardManagers.Set(tierID, rm)
			lp.store.SetProjectTierRewardManagers(projectTierRewardManagers)

			// Transfer OBL tokens from admin to launchpad for refund
			adminRealm := testing.NewUserRealm(adminAddr)
			testing.SetRealm(adminRealm)
			obl.Transfer(cross, launchpadAddr, tt.totalDistributeAmount)

			// Execute transfer
			currentTime := int64(2001) // After tier end
			beforeOblBalance := obl.BalanceOf(recipient)
			refundedAmount, err := lp.transferLeftFromProject(project, recipient, currentTime)
			afterOblBalance := obl.BalanceOf(recipient)
			balanceChange := afterOblBalance - beforeOblBalance

			if tt.expectError {
				uassert.Error(t, err)
				if tt.expectedErrorContains != "" {
					uassert.ErrorContains(t, err, tt.expectedErrorContains)
				}
				return
			}

			uassert.NoError(t, err)

			// Verify claimable amount calculation
			claimable := calculateClaimableRewardsForActiveDeposits(rm)
			uassert.Equal(t, tt.expectedClaimable, claimable)

			// Verify refundable amount
			uassert.Equal(t, tt.expectedRefundable, refundedAmount)
			uassert.Equal(t, tt.expectedBalanceChange, balanceChange)
		})
	}
}

// TestLaunchpadProject_TransferLeftFromProjectWithMultiplePendingDeposits tests
// TransferLeftFromProjectByAdmin with multiple users having pending withdrawals.
func TestLaunchpadProject_TransferLeftFromProjectWithMultiplePendingDeposits(t *testing.T) {
	tests := []struct {
		name                  string
		totalDistributeAmount int64
		deposits              []struct {
			amount         int64
			priceDebtRatio int64
		}
		expectedTotalClaimable int64
		expectedRefundable     int64
	}{
		{
			name:                  "two deposits with different claimable amounts",
			totalDistributeAmount: 1_000_000,
			deposits: []struct {
				amount         int64
				priceDebtRatio int64
			}{
				{amount: 100_000, priceDebtRatio: 2}, // claimable = 50_000
				{amount: 200_000, priceDebtRatio: 4}, // claimable = 150_000
			},
			expectedTotalClaimable: 200_000, // 50_000 + 150_000
			expectedRefundable:     800_000, // 1_000_000 - 200_000
		},
		{
			name:                  "three deposits with varying claimable",
			totalDistributeAmount: 1_000_000,
			deposits: []struct {
				amount         int64
				priceDebtRatio int64
			}{
				{amount: 50_000, priceDebtRatio: 2},  // claimable = 25_000
				{amount: 100_000, priceDebtRatio: 4}, // claimable = 75_000
				{amount: 150_000, priceDebtRatio: 1}, // claimable = 0 (priceDebt == accumulated)
			},
			expectedTotalClaimable: 100_000, // 25_000 + 75_000 + 0
			expectedRefundable:     900_000, // 1_000_000 - 100_000
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadProjectTest(t)
			lp := getTestImplementation()

			adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
			launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

			recipient := testutils.TestAddress("recipient")
			projectID := "gno.land/r/onbloc/obl:123"
			tierID := projectID + ":180"

			// Create project with tier
			tier := launchpad.NewProjectTier(projectID, 180, tt.totalDistributeAmount, 1000, 2000)
			tier.SetID(tierID)
			tier.SetTotalDepositCount(int64(len(tt.deposits)))
			tier.SetTotalWithdrawCount(0)
			tier.SetTotalCollectedAmount(0)

			project := launchpad.NewProject(projectID, "gno.land/r/onbloc/obl", 0, recipient, 100, 1000)
			project.SetID(projectID)

			tiers := make(map[int64]*launchpad.ProjectTier)
			tiers[projectTier180] = tier
			project.SetTiers(tiers)

			projects := lp.store.GetProjects()
			projects.Set(projectID, project)
			lp.store.SetProjects(projects)

			// Setup reward manager with multiple deposits
			projectTierRewardManagers := lp.store.GetProjectTierRewardManagers()
			rm := newRewardManager(tt.totalDistributeAmount, 1000, 2000, 100, 1000)
			rm.SetAccumulatedRewardPerDepositX128(q128.Clone()) // 1.0 accumulated

			for i, dep := range tt.deposits {
				priceDebt := u256.Zero().Div(q128.Clone(), u256.NewUint(uint64(dep.priceDebtRatio)))
				rewardState := newRewardState(priceDebt, dep.amount, 1000, 2000, 1100)
				rm.Rewards().Set("deposit"+formatInt(int64(i)), rewardState)
			}

			projectTierRewardManagers.Set(tierID, rm)
			lp.store.SetProjectTierRewardManagers(projectTierRewardManagers)

			// Transfer OBL tokens from admin to launchpad for refund
			adminRealm := testing.NewUserRealm(adminAddr)
			testing.SetRealm(adminRealm)
			obl.Transfer(cross, launchpadAddr, tt.totalDistributeAmount)

			// Execute transfer
			currentTime := int64(2001)
			refundedAmount, err := lp.transferLeftFromProject(project, recipient, currentTime)

			uassert.NoError(t, err)

			// Verify total claimable
			totalClaimable := calculateClaimableRewardsForActiveDeposits(rm)
			uassert.Equal(t, tt.expectedTotalClaimable, totalClaimable)

			// Verify refundable amount
			uassert.Equal(t, tt.expectedRefundable, refundedAmount)
		})
	}
}

// TestLaunchpadProject_TransferLeftFromProjectNoDepositors tests that
// TransferLeftFromProjectByAdmin returns full remaining amount when no depositors exist.
func TestLaunchpadProject_TransferLeftFromProjectNoDepositors(t *testing.T) {
	tests := []struct {
		name                  string
		totalDistributeAmount int64
		totalCollectedAmount  int64
		expectedRefundable    int64
		expectError           bool
		expectedErrorContains string
	}{
		{
			name:                  "no depositors - full refund",
			totalDistributeAmount: 1_000_000,
			totalCollectedAmount:  0,
			expectedRefundable:    1_000_000,
		},
		{
			name:                  "no depositors - no remaining amount",
			totalDistributeAmount: 1_000_000,
			totalCollectedAmount:  1_000_000,
			expectError:           true,
			expectedErrorContains: "project has no remaining amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadProjectTest(t)
			lp := getTestImplementation()

			adminAddr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
			launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

			recipient := testutils.TestAddress("recipient")
			projectID := "gno.land/r/onbloc/obl:123"
			tierID := projectID + ":180"

			// Create project with tier - no depositors
			tier := launchpad.NewProjectTier(projectID, 180, tt.totalDistributeAmount, 1000, 2000)
			tier.SetID(tierID)
			tier.SetTotalDepositCount(0)  // No depositors
			tier.SetTotalWithdrawCount(0) // No withdrawals
			tier.SetTotalCollectedAmount(tt.totalCollectedAmount)

			project := launchpad.NewProject(projectID, "gno.land/r/onbloc/obl", 0, recipient, 100, 1000)
			project.SetID(projectID)

			tiers := make(map[int64]*launchpad.ProjectTier)
			tiers[projectTier180] = tier
			project.SetTiers(tiers)

			projects := lp.store.GetProjects()
			projects.Set(projectID, project)
			lp.store.SetProjects(projects)

			// Setup empty reward manager
			projectTierRewardManagers := lp.store.GetProjectTierRewardManagers()
			rm := newRewardManager(tt.totalDistributeAmount, 1000, 2000, 100, 1000)
			rm.SetAccumulatedRewardPerDepositX128(q128.Clone())
			// No reward states added

			projectTierRewardManagers.Set(tierID, rm)
			lp.store.SetProjectTierRewardManagers(projectTierRewardManagers)

			// Transfer OBL tokens from admin to launchpad for refund
			adminRealm := testing.NewUserRealm(adminAddr)
			testing.SetRealm(adminRealm)
			obl.Transfer(cross, launchpadAddr, tt.totalDistributeAmount)

			// Execute transfer
			currentTime := int64(2001)
			refundedAmount, err := lp.transferLeftFromProject(project, recipient, currentTime)

			if tt.expectError {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, tt.expectedErrorContains)
				return
			}

			uassert.NoError(t, err)
			uassert.Equal(t, tt.expectedRefundable, refundedAmount)
		})
	}
}
