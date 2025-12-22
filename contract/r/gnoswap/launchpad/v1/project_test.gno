package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/launchpad"
)

func TestProject_IsProjectActive(t *testing.T) {
	tests := []struct {
		name             string
		startTime        int64
		endTime          int64
		currentTime      int64
		expectedIsActive bool
	}{
		{
			name:             "project is inactive before start",
			startTime:        100,
			endTime:          200,
			currentTime:      50,
			expectedIsActive: false,
		},
		{
			name:             "project is active during active period",
			startTime:        100,
			endTime:          200,
			currentTime:      150,
			expectedIsActive: true,
		},
		{
			name:             "project is inactive after end",
			startTime:        100,
			endTime:          200,
			currentTime:      250,
			expectedIsActive: false,
		},
		{
			name:             "project is active at start time",
			startTime:        100,
			endTime:          200,
			currentTime:      100,
			expectedIsActive: true,
		},
		{
			name:             "project is inactive at end time",
			startTime:        100,
			endTime:          200,
			currentTime:      200,
			expectedIsActive: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			tier := launchpad.NewProjectTier("test_project", 180, 1000000, tt.startTime, tt.endTime)

			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 1000000, testutils.TestAddress("recipient"), 100, 1000)
			tiers := map[int64]*launchpad.ProjectTier{
				projectTier180: tier,
			}
			project.SetTiers(tiers)

			// Execute
			isActive := isProjectActive(project, tt.currentTime)

			// Verify
			uassert.Equal(t, tt.expectedIsActive, isActive)
		})
	}
}

func TestProject_IsProjectEnded(t *testing.T) {
	tests := []struct {
		name            string
		startTime       int64
		endTime         int64
		currentTime     int64
		expectedIsEnded bool
	}{
		{
			name:            "project is not ended before start",
			startTime:       100,
			endTime:         200,
			currentTime:     50,
			expectedIsEnded: false,
		},
		{
			name:            "project is not ended during active period",
			startTime:       100,
			endTime:         200,
			currentTime:     150,
			expectedIsEnded: false,
		},
		{
			name:            "project is ended after end time",
			startTime:       100,
			endTime:         200,
			currentTime:     250,
			expectedIsEnded: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			tier := launchpad.NewProjectTier("test_project", 180, 1000000, tt.startTime, tt.endTime)

			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 1000000, testutils.TestAddress("recipient"), 100, 1000)
			tiers := map[int64]*launchpad.ProjectTier{
				projectTier180: tier,
			}
			project.SetTiers(tiers)

			// Execute
			isEnded := isProjectEnded(project, tt.currentTime)

			// Verify
			uassert.Equal(t, tt.expectedIsEnded, isEnded)
		})
	}
}

func TestProject_IsRecipient(t *testing.T) {
	recipientAddr := testutils.TestAddress("recipient")
	otherAddr := testutils.TestAddress("other")

	tests := []struct {
		name           string
		recipient      address
		caller         address
		expectedResult bool
	}{
		{
			name:           "caller is owner",
			recipient:      recipientAddr,
			caller:         recipientAddr,
			expectedResult: true,
		},
		{
			name:           "caller is not owner",
			recipient:      recipientAddr,
			caller:         otherAddr,
			expectedResult: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 0, tt.recipient, 100, 1000)

			// Execute
			result := project.IsRecipient(tt.caller)

			// Verify
			uassert.Equal(t, tt.expectedResult, result)
		})
	}
}

func TestProject_GetProjectRemainingAmount(t *testing.T) {
	tests := []struct {
		name              string
		tiers             map[int64]*launchpad.ProjectTier
		expectedRemaining int64
	}{
		{
			name: "calculate remaining amount with multiple tiers",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetTotalCollectedAmount(300)
					return tier
				}(),
				90: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 90, 2000, 100, 200)
					tier.SetTotalCollectedAmount(500)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 3000, 100, 200)
					tier.SetTotalCollectedAmount(800)
					return tier
				}(),
			},
			expectedRemaining: 4400, // (1000-300) + (2000-500) + (3000-800)
		},
		{
			name: "calculate remaining amount with zero collected",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetTotalCollectedAmount(0)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 2000, 100, 200)
					tier.SetTotalCollectedAmount(0)
					return tier
				}(),
			},
			expectedRemaining: 3000,
		},
		{
			name: "calculate remaining amount with fully collected",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetTotalCollectedAmount(1000)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 2000, 100, 200)
					tier.SetTotalCollectedAmount(2000)
					return tier
				}(),
			},
			expectedRemaining: 0,
		},
		{
			name:              "calculate remaining amount with no tiers",
			tiers:             map[int64]*launchpad.ProjectTier{},
			expectedRemaining: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
			project.SetTiers(tt.tiers)

			// Execute
			result := getProjectStats(project).RemainingAmount

			// Verify
			uassert.Equal(t, tt.expectedRemaining, result)
		})
	}
}

func TestProject_GetProjectTotalDepositCount(t *testing.T) {
	tests := []struct {
		name               string
		tiers              map[int64]*launchpad.ProjectTier
		expectedTotalCount int64
	}{
		{
			name: "calculate deposit counts with multiple tiers",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetTotalDepositCount(10)
					tier.SetTotalWithdrawCount(2)
					return tier
				}(),
				90: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 90, 2000, 100, 200)
					tier.SetTotalDepositCount(20)
					tier.SetTotalWithdrawCount(5)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 3000, 100, 200)
					tier.SetTotalDepositCount(15)
					tier.SetTotalWithdrawCount(3)
					return tier
				}(),
			},
			expectedTotalCount: 45, // 10 + 20 + 15
		},
		{
			name: "calculate deposit counts with no withdrawals",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetTotalDepositCount(10)
					tier.SetTotalWithdrawCount(0)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 2000, 100, 200)
					tier.SetTotalDepositCount(20)
					tier.SetTotalWithdrawCount(0)
					return tier
				}(),
			},
			expectedTotalCount: 30,
		},
		{
			name:               "calculate deposit counts with no tiers",
			tiers:              map[int64]*launchpad.ProjectTier{},
			expectedTotalCount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
			project.SetTiers(tt.tiers)

			// Execute
			result := getProjectStats(project).TotalDepositCount

			// Verify
			uassert.Equal(t, tt.expectedTotalCount, result)
		})
	}
}

func TestProject_GetProjectCurrentDepositCount(t *testing.T) {
	tests := []struct {
		name                 string
		tiers                map[int64]*launchpad.ProjectTier
		expectedCurrentCount int64
	}{
		{
			name: "calculate current deposit counts with withdrawals",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetTotalDepositCount(10)
					tier.SetTotalWithdrawCount(2)
					return tier
				}(),
				90: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 90, 2000, 100, 200)
					tier.SetTotalDepositCount(20)
					tier.SetTotalWithdrawCount(5)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 3000, 100, 200)
					tier.SetTotalDepositCount(15)
					tier.SetTotalWithdrawCount(3)
					return tier
				}(),
			},
			expectedCurrentCount: 35, // (10-2) + (20-5) + (15-3)
		},
		{
			name: "calculate current deposit counts with no withdrawals",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetTotalDepositCount(10)
					tier.SetTotalWithdrawCount(0)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 2000, 100, 200)
					tier.SetTotalDepositCount(20)
					tier.SetTotalWithdrawCount(0)
					return tier
				}(),
			},
			expectedCurrentCount: 30,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
			project.SetTiers(tt.tiers)

			// Execute
			result := getProjectStats(project).CurrentDepositCount

			// Verify
			uassert.Equal(t, tt.expectedCurrentCount, result)
		})
	}
}

func TestProject_GetProjectTotalDepositAmount(t *testing.T) {
	tests := []struct {
		name                string
		tiers               map[int64]*launchpad.ProjectTier
		expectedTotalAmount int64
	}{
		{
			name: "calculate deposit amounts with multiple tiers",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetTotalDepositAmount(1000000)
					tier.SetTotalWithdrawAmount(200000)
					return tier
				}(),
				90: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 90, 2000, 100, 200)
					tier.SetTotalDepositAmount(2000000)
					tier.SetTotalWithdrawAmount(500000)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 3000, 100, 200)
					tier.SetTotalDepositAmount(1500000)
					tier.SetTotalWithdrawAmount(300000)
					return tier
				}(),
			},
			expectedTotalAmount: 4500000, // 1000000 + 2000000 + 1500000
		},
		{
			name: "calculate deposit amounts with no withdrawals",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetTotalDepositAmount(1000000)
					tier.SetTotalWithdrawAmount(0)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 2000, 100, 200)
					tier.SetTotalDepositAmount(2000000)
					tier.SetTotalWithdrawAmount(0)
					return tier
				}(),
			},
			expectedTotalAmount: 3000000,
		},
		{
			name:                "calculate deposit amounts with no tiers",
			tiers:               map[int64]*launchpad.ProjectTier{},
			expectedTotalAmount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
			project.SetTiers(tt.tiers)

			// Execute
			result := getProjectStats(project).TotalDepositAmount

			// Verify
			uassert.Equal(t, tt.expectedTotalAmount, result)
		})
	}
}

func TestProject_GetProjectCurrentDepositAmount(t *testing.T) {
	tests := []struct {
		name                  string
		tiers                 map[int64]*launchpad.ProjectTier
		expectedCurrentAmount int64
	}{
		{
			name: "calculate current deposit amounts with withdrawals",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetTotalDepositAmount(1000000)
					tier.SetTotalWithdrawAmount(200000)
					return tier
				}(),
				90: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 90, 2000, 100, 200)
					tier.SetTotalDepositAmount(2000000)
					tier.SetTotalWithdrawAmount(500000)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 3000, 100, 200)
					tier.SetTotalDepositAmount(1500000)
					tier.SetTotalWithdrawAmount(300000)
					return tier
				}(),
			},
			expectedCurrentAmount: 3500000, // (1000000-200000) + (2000000-500000) + (1500000-300000)
		},
		{
			name: "calculate current deposit amounts with no withdrawals",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetTotalDepositAmount(1000000)
					tier.SetTotalWithdrawAmount(0)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 2000, 100, 200)
					tier.SetTotalDepositAmount(2000000)
					tier.SetTotalWithdrawAmount(0)
					return tier
				}(),
			},
			expectedCurrentAmount: 3000000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
			project.SetTiers(tt.tiers)

			// Execute
			result := getProjectStats(project).CurrentDepositAmount

			// Verify
			uassert.Equal(t, tt.expectedCurrentAmount, result)
		})
	}
}

func TestProject_GetProjectTotalCollectedAmount(t *testing.T) {
	tests := []struct {
		name                    string
		tiers                   map[int64]*launchpad.ProjectTier
		expectedCollectedAmount int64
	}{
		{
			name: "calculate total collected amount with multiple tiers",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetTotalCollectedAmount(300000)
					return tier
				}(),
				90: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 90, 2000, 100, 200)
					tier.SetTotalCollectedAmount(500000)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 3000, 100, 200)
					tier.SetTotalCollectedAmount(800000)
					return tier
				}(),
			},
			expectedCollectedAmount: 1600000, // 300000 + 500000 + 800000
		},
		{
			name: "calculate total collected amount with zero collected",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetTotalCollectedAmount(0)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 2000, 100, 200)
					tier.SetTotalCollectedAmount(0)
					return tier
				}(),
			},
			expectedCollectedAmount: 0,
		},
		{
			name:                    "calculate total collected amount with no tiers",
			tiers:                   map[int64]*launchpad.ProjectTier{},
			expectedCollectedAmount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
			project.SetTiers(tt.tiers)

			// Execute
			result := getProjectStats(project).TotalCollectedAmount

			// Verify
			uassert.Equal(t, tt.expectedCollectedAmount, result)
		})
	}
}

func TestProject_GetProjectTier(t *testing.T) {
	tests := []struct {
		name             string
		tiers            map[int64]*launchpad.ProjectTier
		duration         int64
		expectedHasError bool
		expectedError    string
	}{
		{
			name: "get existing tier",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetID("test:30")
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 3000, 100, 200)
					tier.SetID("test:180")
					return tier
				}(),
			},
			duration:         30,
			expectedHasError: false,
		},
		{
			name: "get non-existing tier",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetID("test:30")
					return tier
				}(),
			},
			duration:         90,
			expectedHasError: true,
			expectedError:    "tier(%!d(MISSING)) not found",
		},
		{
			name:             "get tier from empty project",
			tiers:            map[int64]*launchpad.ProjectTier{},
			duration:         30,
			expectedHasError: true,
			expectedError:    "tier(%!d(MISSING)) not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
			project.SetTiers(tt.tiers)

			// Execute
			tier, err := getProjectTier(project, tt.duration)

			// Verify
			if tt.expectedHasError {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, "tier")
			} else {
				uassert.NoError(t, err)
				uassert.NotNil(t, tier)
				uassert.Equal(t, tt.tiers[tt.duration].ID(), tier.ID())
			}
		})
	}
}

func TestProject_GetStandardTier(t *testing.T) {
	tests := []struct {
		name          string
		tiers         map[int64]*launchpad.ProjectTier
		expectedPanic bool
	}{
		{
			name: "get standard tier with 180 days tier",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					return tier
				}(),
				180: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 180, 3000, 100, 200)
					tier.SetID("test:180")
					return tier
				}(),
			},
			expectedPanic: false,
		},
		{
			name: "get standard tier without 180 days tier",
			tiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					return tier
				}(),
				90: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 90, 2000, 100, 200)
					return tier
				}(),
			},
			expectedPanic: true,
		},
		{
			name:          "get standard tier from empty project",
			tiers:         map[int64]*launchpad.ProjectTier{},
			expectedPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
			project.SetTiers(tt.tiers)

			// Verify
			if tt.expectedPanic {
				uassert.PanicsContains(t, "[GNOSWAP-LAUNCHPAD-003] requested data not found || tier(180) not found", func() {
					getStandardTier(project)
				})
			} else {
				standardTier := getStandardTier(project)

				uassert.True(t, standardTier != nil, "standard tier should not be nil")
				uassert.Equal(t, "test:180", standardTier.ID())
			}
		})
	}
}

func TestProject_ValidateRefundRemainingAmount(t *testing.T) {
	tests := []struct {
		name                  string
		totalDistributeAmount int64
		totalCollectedAmount  int64
		tierStartTime         int64
		tierEndTime           int64
		currentTime           int64
		expectedHasError      bool
		expectedError         string
	}{
		{
			name:                  "refund validation fails when project not ended",
			totalDistributeAmount: 1000,
			totalCollectedAmount:  500,
			tierStartTime:         100,
			tierEndTime:           200,
			currentTime:           150,
			expectedHasError:      true,
			expectedError:         "project not ended yet",
		},
		{
			name:                  "refund validation fails when no remaining amount",
			totalDistributeAmount: 1000,
			totalCollectedAmount:  1000,
			tierStartTime:         100,
			tierEndTime:           200,
			currentTime:           250,
			expectedHasError:      true,
			expectedError:         "project has no remaining amount",
		},
		{
			name:                  "refund validation succeeds when ended with remaining amount",
			totalDistributeAmount: 1000,
			totalCollectedAmount:  500,
			tierStartTime:         100,
			tierEndTime:           200,
			currentTime:           250,
			expectedHasError:      false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			tier := launchpad.NewProjectTier("test", 180, tt.totalDistributeAmount, tt.tierStartTime, tt.tierEndTime)
			tier.SetTotalCollectedAmount(tt.totalCollectedAmount)

			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
			tiers := map[int64]*launchpad.ProjectTier{
				projectTier180: tier,
			}
			project.SetTiers(tiers)

			// Execute
			err := validateRefundRemainingAmount(project, tt.currentTime)

			// Verify
			if tt.expectedHasError {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestProject_AddProjectTier(t *testing.T) {
	tests := []struct {
		name          string
		initialTiers  map[int64]*launchpad.ProjectTier
		duration      int64
		tier          *launchpad.ProjectTier
		expectedTiers map[int64]*launchpad.ProjectTier
	}{
		{
			name:         "add new tier to empty project",
			initialTiers: map[int64]*launchpad.ProjectTier{},
			duration:     30,
			tier: func() *launchpad.ProjectTier {
				tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
				tier.SetID("test:30")
				return tier
			}(),
			expectedTiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetID("test:30")
					return tier
				}(),
			},
		},
		{
			name: "add tier to existing tiers",
			initialTiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetID("test:30")
					return tier
				}(),
			},
			duration: 90,
			tier: func() *launchpad.ProjectTier {
				tier := launchpad.NewProjectTier("test", 90, 1000, 100, 200)
				tier.SetID("test:90")
				return tier
			}(),
			expectedTiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetID("test:30")
					return tier
				}(),
				90: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 90, 1000, 100, 200)
					tier.SetID("test:90")
					return tier
				}(),
			},
		},
		{
			name: "overwrite existing tier",
			initialTiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetID("test:30_old")
					return tier
				}(),
			},
			duration: 30,
			tier: func() *launchpad.ProjectTier {
				tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
				tier.SetID("test:30_new")
				return tier
			}(),
			expectedTiers: map[int64]*launchpad.ProjectTier{
				30: func() *launchpad.ProjectTier {
					tier := launchpad.NewProjectTier("test", 30, 1000, 100, 200)
					tier.SetID("test:30_new")
					return tier
				}(),
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
			project.SetTiers(tt.initialTiers)

			// Execute
			addProjectTier(project, tt.duration, tt.tier)

			// Verify
			tiers := project.Tiers()
			uassert.Equal(t, len(tiers), len(tt.expectedTiers))

			for duration, expectedTier := range tt.expectedTiers {
				actualTier, exists := tiers[duration]
				uassert.Equal(t, exists, true)
				uassert.Equal(t, actualTier.ID(), expectedTier.ID())
			}
		})
	}
}

func TestProject_CheckProjectConditions(t *testing.T) {
	tests := []struct {
		name             string
		conditions       map[string]*launchpad.ProjectCondition
		balanceFunc      func(tokenPath string, caller address) int64
		expectedHasError bool
		expectedError    string
	}{
		{
			name: "check conditions passes with sufficient balance",
			conditions: map[string]*launchpad.ProjectCondition{
				"gno.land/r/demo/gns": func() *launchpad.ProjectCondition {
					condition := launchpad.NewProjectCondition("gno.land/r/demo/gns", 1000)
					return condition
				}(),
			},
			balanceFunc: func(tokenPath string, caller address) int64 {
				return 1500 // More than required
			},
			expectedHasError: false,
		},
		{
			name: "check conditions fails with insufficient balance",
			conditions: map[string]*launchpad.ProjectCondition{
				"gno.land/r/demo/gns": func() *launchpad.ProjectCondition {
					condition := launchpad.NewProjectCondition("gno.land/r/demo/gns", 1000)
					return condition
				}(),
			},
			balanceFunc: func(tokenPath string, caller address) int64 {
				return 500 // Less than required
			},
			expectedHasError: true,
			expectedError:    "input amount",
		},
		{
			name: "check conditions with multiple tokens",
			conditions: map[string]*launchpad.ProjectCondition{
				"gno.land/r/demo/gns": func() *launchpad.ProjectCondition {
					return launchpad.NewProjectCondition("gno.land/r/demo/gns", 1000)
				}(),
				"gno.land/r/demo/usdc": func() *launchpad.ProjectCondition {
					return launchpad.NewProjectCondition("gno.land/r/demo/usdc", 500)
				}(),
			},
			balanceFunc: func(tokenPath string, caller address) int64 {
				if tokenPath == "gno.land/r/demo/gns" {
					return 1500
				}
				return 600
			},
			expectedHasError: false,
		},
		{
			name: "skip zero conditions",
			conditions: map[string]*launchpad.ProjectCondition{
				"gno.land/r/demo/xgns": func() *launchpad.ProjectCondition {
					return launchpad.NewProjectCondition("gno.land/r/demo/xgns", 0)
				}(),
			},
			balanceFunc: func(tokenPath string, caller address) int64 {
				return 0 // Zero balance is okay for zero condition
			},
			expectedHasError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := launchpad.NewProject("test_project", "gno.land/r/test/token", 0, testutils.TestAddress("recipient"), 100, 1000)
			project.SetConditions(tt.conditions)

			caller := testutils.TestAddress("caller")

			// Execute
			err := checkProjectConditions(project, caller, tt.balanceFunc)

			// Verify
			if tt.expectedHasError {
				uassert.Error(t, err)
				if tt.expectedError != "" {
					uassert.ErrorContains(t, err, tt.expectedError)
				}
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}
