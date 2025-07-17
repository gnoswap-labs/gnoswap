package launchpad

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
)

func TestProject_Getters(t *testing.T) {
	tests := []struct {
		name          string
		id            string
		projectName   string
		tokenPath     string
		depositAmount int64
		recipient     std.Address
		createdTime   int64
		createdHeight int64
		getterFunc    string
		expectedValue interface{}
	}{
		{
			name:          "get project ID",
			id:            "test:123",
			projectName:   "Test Project",
			tokenPath:     "gno.land/r/test/token",
			depositAmount: 1000000,
			recipient:     testutils.TestAddress("recipient"),
			createdTime:   1000,
			createdHeight: 123,
			getterFunc:    "ID",
			expectedValue: "test:123",
		},
		{
			name:          "get project name",
			id:            "test:123",
			projectName:   "Test Project",
			tokenPath:     "gno.land/r/test/token",
			depositAmount: 1000000,
			recipient:     testutils.TestAddress("recipient"),
			createdTime:   1000,
			createdHeight: 123,
			getterFunc:    "Name",
			expectedValue: "Test Project",
		},
		{
			name:          "get project token path",
			id:            "test:123",
			projectName:   "Test Project",
			tokenPath:     "gno.land/r/test/token",
			depositAmount: 1000000,
			recipient:     testutils.TestAddress("recipient"),
			createdTime:   1000,
			createdHeight: 123,
			getterFunc:    "TokenPath",
			expectedValue: "gno.land/r/test/token",
		},
		{
			name:          "get project deposit amount",
			id:            "test:123",
			projectName:   "Test Project",
			tokenPath:     "gno.land/r/test/token",
			depositAmount: 1000000,
			recipient:     testutils.TestAddress("recipient"),
			createdTime:   1000,
			createdHeight: 123,
			getterFunc:    "DepositAmount",
			expectedValue: int64(1000000),
		},
		{
			name:          "get project recipient",
			id:            "test:123",
			projectName:   "Test Project",
			tokenPath:     "gno.land/r/test/token",
			depositAmount: 1000000,
			recipient:     testutils.TestAddress("recipient"),
			createdTime:   1000,
			createdHeight: 123,
			getterFunc:    "Recipient",
			expectedValue: testutils.TestAddress("recipient"),
		},
		{
			name:          "get project created time",
			id:            "test:123",
			projectName:   "Test Project",
			tokenPath:     "gno.land/r/test/token",
			depositAmount: 1000000,
			recipient:     testutils.TestAddress("recipient"),
			createdTime:   1000,
			createdHeight: 123,
			getterFunc:    "CreatedAt",
			expectedValue: int64(1000),
		},
		{
			name:          "get project created height",
			id:            "test:123",
			projectName:   "Test Project",
			tokenPath:     "gno.land/r/test/token",
			depositAmount: 1000000,
			recipient:     testutils.TestAddress("recipient"),
			createdTime:   1000,
			createdHeight: 123,
			getterFunc:    "CreatedHeight",
			expectedValue: int64(123),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				id:            tt.id,
				name:          tt.projectName,
				tokenPath:     tt.tokenPath,
				depositAmount: tt.depositAmount,
				recipient:     tt.recipient,
				conditions:    make(map[string]*ProjectCondition),
				tiers:         make(map[int64]*ProjectTier),
				createdBlockTimeInfo: &BlockTimeInfo{
					blockTime:   tt.createdTime,
					blockHeight: tt.createdHeight,
				},
			}

			// Execute and verify
			var result interface{}
			switch tt.getterFunc {
			case "ID":
				result = project.ID()
			case "Name":
				result = project.Name()
			case "TokenPath":
				result = project.TokenPath()
			case "DepositAmount":
				result = project.DepositAmount()
			case "Recipient":
				result = project.Recipient()
			case "CreatedAt":
				result = project.CreatedAt()
			case "CreatedHeight":
				result = project.CreatedHeight()
			}
			uassert.Equal(t, result, tt.expectedValue)
		})
	}
}

func TestProject_Status(t *testing.T) {
	tests := []struct {
		name             string
		startHeight      int64
		endHeight        int64
		currentHeight    int64
		expectedIsActive bool
		expectedIsEnded  bool
	}{
		{
			name:             "project status inactive and not ended when before start",
			startHeight:      150,
			endHeight:        200,
			currentHeight:    120,
			expectedIsActive: false,
			expectedIsEnded:  false,
		},
		{
			name:             "project status active and not ended during active period",
			startHeight:      150,
			endHeight:        200,
			currentHeight:    175,
			expectedIsActive: true,
			expectedIsEnded:  false,
		},
		{
			name:             "project status inactive and ended after end",
			startHeight:      150,
			endHeight:        200,
			currentHeight:    250,
			expectedIsActive: false,
			expectedIsEnded:  true,
		},
		{
			name:             "project status active at start height",
			startHeight:      150,
			endHeight:        200,
			currentHeight:    150,
			expectedIsActive: true,
			expectedIsEnded:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				tiers: map[int64]*ProjectTier{
					projectTier180: {
						startBlockTimeInfo: &BlockTimeInfo{
							blockHeight: tt.startHeight,
						},
						endBlockTimeInfo: &BlockTimeInfo{
							blockHeight: tt.endHeight,
						},
					},
				},
			}

			// Execute and verify
			isActive := project.IsActive(tt.currentHeight)
			isEnded := project.IsEnded(tt.currentHeight)

			uassert.Equal(t, isActive, tt.expectedIsActive)
			uassert.Equal(t, isEnded, tt.expectedIsEnded)
		})
	}
}

func TestProject_IsOwner(t *testing.T) {
	tests := []struct {
		name           string
		recipient      std.Address
		caller         std.Address
		expectedResult bool
	}{
		{
			name:           "caller is owner",
			recipient:      testutils.TestAddress("owner"),
			caller:         testutils.TestAddress("owner"),
			expectedResult: true,
		},
		{
			name:           "caller is not owner",
			recipient:      testutils.TestAddress("owner"),
			caller:         testutils.TestAddress("other"),
			expectedResult: false,
		},
		{
			name:           "different addresses with same string representation",
			recipient:      testutils.TestAddress("owner"),
			caller:         testutils.TestAddress("owner"),
			expectedResult: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				recipient: tt.recipient,
			}

			// Execute and verify
			result := project.IsOwner(tt.caller)
			uassert.Equal(t, result, tt.expectedResult)
		})
	}
}

func TestProject_RemainingAmount(t *testing.T) {
	tests := []struct {
		name              string
		tiers             map[int64]*ProjectTier
		expectedRemaining int64
	}{
		{
			name: "calculate remaining amount with multiple tiers",
			tiers: map[int64]*ProjectTier{
				30: {
					totalDistributeAmount: 1000,
					totalCollectedAmount:  300,
				},
				90: {
					totalDistributeAmount: 2000,
					totalCollectedAmount:  500,
				},
				180: {
					totalDistributeAmount: 3000,
					totalCollectedAmount:  800,
				},
			},
			expectedRemaining: 4400, // (1000-300) + (2000-500) + (3000-800)
		},
		{
			name: "calculate remaining amount with zero collected",
			tiers: map[int64]*ProjectTier{
				30: {
					totalDistributeAmount: 1000,
					totalCollectedAmount:  0,
				},
				180: {
					totalDistributeAmount: 2000,
					totalCollectedAmount:  0,
				},
			},
			expectedRemaining: 3000,
		},
		{
			name: "calculate remaining amount with fully collected",
			tiers: map[int64]*ProjectTier{
				30: {
					totalDistributeAmount: 1000,
					totalCollectedAmount:  1000,
				},
				180: {
					totalDistributeAmount: 2000,
					totalCollectedAmount:  2000,
				},
			},
			expectedRemaining: 0,
		},
		{
			name:              "calculate remaining amount with no tiers",
			tiers:             map[int64]*ProjectTier{},
			expectedRemaining: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				tiers: tt.tiers,
			}

			// Execute
			result := project.RemainingAmount()
			uassert.Equal(t, result, tt.expectedRemaining)
		})
	}
}

func TestProject_DepositCounts(t *testing.T) {
	tests := []struct {
		name                 string
		tiers                map[int64]*ProjectTier
		expectedTotalCount   int64
		expectedCurrentCount int64
	}{
		{
			name: "calculate deposit counts with multiple tiers",
			tiers: map[int64]*ProjectTier{
				30: {
					totalDepositCount:  10,
					totalWithdrawCount: 2,
				},
				90: {
					totalDepositCount:  20,
					totalWithdrawCount: 5,
				},
				180: {
					totalDepositCount:  15,
					totalWithdrawCount: 3,
				},
			},
			expectedTotalCount:   45, // 10 + 20 + 15
			expectedCurrentCount: 35, // (10-2) + (20-5) + (15-3)
		},
		{
			name: "calculate deposit counts with no withdrawals",
			tiers: map[int64]*ProjectTier{
				30: {
					totalDepositCount:  10,
					totalWithdrawCount: 0,
				},
				180: {
					totalDepositCount:  20,
					totalWithdrawCount: 0,
				},
			},
			expectedTotalCount:   30,
			expectedCurrentCount: 30,
		},
		{
			name:                 "calculate deposit counts with no tiers",
			tiers:                map[int64]*ProjectTier{},
			expectedTotalCount:   0,
			expectedCurrentCount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				tiers: tt.tiers,
			}

			// Execute and verify
			totalCount := project.TotalDepositCount()
			currentCount := project.CurrentDepositCount()

			uassert.Equal(t, totalCount, tt.expectedTotalCount)
			uassert.Equal(t, currentCount, tt.expectedCurrentCount)
		})
	}
}

func TestProject_DepositAmounts(t *testing.T) {
	tests := []struct {
		name                  string
		tiers                 map[int64]*ProjectTier
		expectedTotalAmount   int64
		expectedCurrentAmount int64
	}{
		{
			name: "calculate deposit amounts with multiple tiers",
			tiers: map[int64]*ProjectTier{
				30: {
					totalDepositAmount:  1000000,
					totalWithdrawAmount: 200000,
				},
				90: {
					totalDepositAmount:  2000000,
					totalWithdrawAmount: 500000,
				},
				180: {
					totalDepositAmount:  1500000,
					totalWithdrawAmount: 300000,
				},
			},
			expectedTotalAmount:   4500000, // 1000000 + 2000000 + 1500000
			expectedCurrentAmount: 3500000, // (1000000-200000) + (2000000-500000) + (1500000-300000)
		},
		{
			name: "calculate deposit amounts with no withdrawals",
			tiers: map[int64]*ProjectTier{
				30: {
					totalDepositAmount:  1000000,
					totalWithdrawAmount: 0,
				},
				180: {
					totalDepositAmount:  2000000,
					totalWithdrawAmount: 0,
				},
			},
			expectedTotalAmount:   3000000,
			expectedCurrentAmount: 3000000,
		},
		{
			name:                  "calculate deposit amounts with no tiers",
			tiers:                 map[int64]*ProjectTier{},
			expectedTotalAmount:   0,
			expectedCurrentAmount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				tiers: tt.tiers,
			}

			// Execute and verify
			totalAmount := project.TotalDepositAmount()
			currentAmount := project.CurrentDepositAmount()

			uassert.Equal(t, totalAmount, tt.expectedTotalAmount)
			uassert.Equal(t, currentAmount, tt.expectedCurrentAmount)
		})
	}
}

func TestProject_TotalCollectedAmount(t *testing.T) {
	tests := []struct {
		name                    string
		tiers                   map[int64]*ProjectTier
		expectedCollectedAmount int64
	}{
		{
			name: "calculate total collected amount with multiple tiers",
			tiers: map[int64]*ProjectTier{
				30: {
					totalCollectedAmount: 300000,
				},
				90: {
					totalCollectedAmount: 500000,
				},
				180: {
					totalCollectedAmount: 800000,
				},
			},
			expectedCollectedAmount: 1600000, // 300000 + 500000 + 800000
		},
		{
			name: "calculate total collected amount with zero collected",
			tiers: map[int64]*ProjectTier{
				30: {
					totalCollectedAmount: 0,
				},
				180: {
					totalCollectedAmount: 0,
				},
			},
			expectedCollectedAmount: 0,
		},
		{
			name:                    "calculate total collected amount with no tiers",
			tiers:                   map[int64]*ProjectTier{},
			expectedCollectedAmount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				tiers: tt.tiers,
			}

			// Execute and verify
			result := project.TotalCollectedAmount()
			uassert.Equal(t, result, tt.expectedCollectedAmount)
		})
	}
}

func TestProject_GetTier(t *testing.T) {
	tests := []struct {
		name             string
		tiers            map[int64]*ProjectTier
		duration         int64
		expectedTier     *ProjectTier
		expectedHasError bool
		expectedError    string
	}{
		{
			name: "get existing tier",
			tiers: map[int64]*ProjectTier{
				30: {
					id: "test:30",
				},
				180: {
					id: "test:180",
				},
			},
			duration:         30,
			expectedTier:     &ProjectTier{id: "test:30"},
			expectedHasError: false,
		},
		{
			name: "get non-existing tier",
			tiers: map[int64]*ProjectTier{
				30: {
					id: "test:30",
				},
			},
			duration:         90,
			expectedTier:     nil,
			expectedHasError: true,
			expectedError:    "data not found: tier(90) not found",
		},
		{
			name:             "get tier from empty tiers",
			tiers:            map[int64]*ProjectTier{},
			duration:         30,
			expectedTier:     nil,
			expectedHasError: true,
			expectedError:    "data not found: tier(30) not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				tiers: tt.tiers,
			}

			// Execute
			tier, err := project.getTier(tt.duration)

			// Verify
			if tt.expectedHasError {
				uassert.NotNil(t, err)
				uassert.Equal(t, err.Error(), tt.expectedError)
			} else {
				uassert.Nil(t, err)
				uassert.Equal(t, tier.ID(), tt.expectedTier.ID())
			}
		})
	}
}

func TestProject_StandardTier(t *testing.T) {
	tests := []struct {
		name         string
		tiers        map[int64]*ProjectTier
		expectedTier *ProjectTier
	}{
		{
			name: "get standard tier (180 days)",
			tiers: map[int64]*ProjectTier{
				30: {
					id: "test:30",
				},
				180: {
					id: "test:180",
				},
			},
			expectedTier: &ProjectTier{id: "test:180"},
		},
		{
			name: "no standard tier available",
			tiers: map[int64]*ProjectTier{
				30: {
					id: "test:30",
				},
				90: {
					id: "test:90",
				},
			},
			expectedTier: nil,
		},
		{
			name:         "empty tiers",
			tiers:        map[int64]*ProjectTier{},
			expectedTier: nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				tiers: tt.tiers,
			}

			// Execute
			tier := project.standardTier()

			// Verify
			if tt.expectedTier == nil {
				uassert.Nil(t, tier)
			} else {
				uassert.NotNil(t, tier)
				uassert.Equal(t, tier.ID(), tt.expectedTier.ID())
			}
		})
	}
}

func TestProject_ValidateRefundRemainingAmount(t *testing.T) {
	tests := []struct {
		name             string
		tiers            map[int64]*ProjectTier
		currentHeight    int64
		expectedHasError bool
		expectedError    string
	}{
		{
			name: "validate refund with ended project and remaining amount",
			tiers: map[int64]*ProjectTier{
				180: {
					endBlockTimeInfo: &BlockTimeInfo{
						blockHeight: 200,
					},
					totalDistributeAmount: 1000,
					totalCollectedAmount:  600,
				},
			},
			currentHeight:    250,
			expectedHasError: false,
		},
		{
			name: "validate refund with project not ended",
			tiers: map[int64]*ProjectTier{
				180: {
					endBlockTimeInfo: &BlockTimeInfo{
						blockHeight: 200,
					},
					totalDistributeAmount: 1000,
					totalCollectedAmount:  600,
				},
			},
			currentHeight:    150,
			expectedHasError: true,
			expectedError:    "project not ended yet(current:150, endHeight: 200)",
		},
		{
			name: "validate refund with no remaining amount",
			tiers: map[int64]*ProjectTier{
				180: {
					endBlockTimeInfo: &BlockTimeInfo{
						blockHeight: 200,
					},
					totalDistributeAmount: 1000,
					totalCollectedAmount:  1000,
				},
			},
			currentHeight:    250,
			expectedHasError: true,
			expectedError:    "project has no remaining amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				tiers: tt.tiers,
			}

			// Execute
			err := project.validateRefundRemainingAmount(tt.currentHeight)

			// Verify
			if tt.expectedHasError {
				uassert.NotNil(t, err)
				uassert.Equal(t, err.Error(), tt.expectedError)
			} else {
				uassert.Nil(t, err)
			}
		})
	}
}

func TestProject_AddProjectTier(t *testing.T) {
	tests := []struct {
		name          string
		initialTiers  map[int64]*ProjectTier
		duration      int64
		tier          *ProjectTier
		expectedTiers map[int64]*ProjectTier
	}{
		{
			name:         "add new tier to empty project",
			initialTiers: map[int64]*ProjectTier{},
			duration:     30,
			tier: &ProjectTier{
				id: "test:30",
			},
			expectedTiers: map[int64]*ProjectTier{
				30: {
					id: "test:30",
				},
			},
		},
		{
			name: "add tier to existing tiers",
			initialTiers: map[int64]*ProjectTier{
				30: {
					id: "test:30",
				},
			},
			duration: 90,
			tier: &ProjectTier{
				id: "test:90",
			},
			expectedTiers: map[int64]*ProjectTier{
				30: {
					id: "test:30",
				},
				90: {
					id: "test:90",
				},
			},
		},
		{
			name: "overwrite existing tier",
			initialTiers: map[int64]*ProjectTier{
				30: {
					id: "test:30_old",
				},
			},
			duration: 30,
			tier: &ProjectTier{
				id: "test:30_new",
			},
			expectedTiers: map[int64]*ProjectTier{
				30: {
					id: "test:30_new",
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				tiers: tt.initialTiers,
			}

			// Execute
			project.addProjectTier(tt.duration, tt.tier)

			// Verify
			uassert.Equal(t, len(project.tiers), len(tt.expectedTiers))
			for duration, expectedTier := range tt.expectedTiers {
				actualTier, exists := project.tiers[duration]
				uassert.True(t, exists)
				uassert.Equal(t, actualTier.ID(), expectedTier.ID())
			}
		})
	}
}

func TestProject_AddProjectCondition(t *testing.T) {
	tests := []struct {
		name               string
		initialConditions  map[string]*ProjectCondition
		tokenPath          string
		condition          *ProjectCondition
		expectedConditions map[string]*ProjectCondition
	}{
		{
			name:              "add new condition to empty project",
			initialConditions: map[string]*ProjectCondition{},
			tokenPath:         "gno.land/r/test/token1",
			condition: &ProjectCondition{
				tokenPath:     "gno.land/r/test/token1",
				minimumAmount: 1000,
			},
			expectedConditions: map[string]*ProjectCondition{
				"gno.land/r/test/token1": {
					tokenPath:     "gno.land/r/test/token1",
					minimumAmount: 1000,
				},
			},
		},
		{
			name: "add condition to existing conditions",
			initialConditions: map[string]*ProjectCondition{
				"gno.land/r/test/token1": {
					tokenPath:     "gno.land/r/test/token1",
					minimumAmount: 1000,
				},
			},
			tokenPath: "gno.land/r/test/token2",
			condition: &ProjectCondition{
				tokenPath:     "gno.land/r/test/token2",
				minimumAmount: 2000,
			},
			expectedConditions: map[string]*ProjectCondition{
				"gno.land/r/test/token1": {
					tokenPath:     "gno.land/r/test/token1",
					minimumAmount: 1000,
				},
				"gno.land/r/test/token2": {
					tokenPath:     "gno.land/r/test/token2",
					minimumAmount: 2000,
				},
			},
		},
		{
			name: "overwrite existing condition",
			initialConditions: map[string]*ProjectCondition{
				"gno.land/r/test/token1": {
					tokenPath:     "gno.land/r/test/token1",
					minimumAmount: 1000,
				},
			},
			tokenPath: "gno.land/r/test/token1",
			condition: &ProjectCondition{
				tokenPath:     "gno.land/r/test/token1",
				minimumAmount: 2000,
			},
			expectedConditions: map[string]*ProjectCondition{
				"gno.land/r/test/token1": {
					tokenPath:     "gno.land/r/test/token1",
					minimumAmount: 2000,
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				conditions: tt.initialConditions,
			}

			// Execute
			project.addProjectCondition(tt.tokenPath, tt.condition)

			// Verify
			uassert.Equal(t, len(project.conditions), len(tt.expectedConditions))
			for tokenPath, expectedCondition := range tt.expectedConditions {
				actualCondition, exists := project.conditions[tokenPath]
				uassert.True(t, exists)
				uassert.Equal(t, actualCondition.TokenPath(), expectedCondition.TokenPath())
				uassert.Equal(t, actualCondition.MinimumAmount(), expectedCondition.MinimumAmount())
			}
		})
	}
}

func TestNewProject(t *testing.T) {
	tests := []struct {
		name                  string
		projectName           string
		tokenPath             string
		depositAmount         int64
		recipient             std.Address
		createdBlockTimeInfo  *BlockTimeInfo
		expectedID            string
		expectedName          string
		expectedTokenPath     string
		expectedDepositAmount int64
		expectedRecipient     std.Address
	}{
		{
			name:          "create new project with valid parameters",
			projectName:   "Test Project",
			tokenPath:     "gno.land/r/test/token",
			depositAmount: 1000000,
			recipient:     testutils.TestAddress("recipient"),
			createdBlockTimeInfo: &BlockTimeInfo{
				blockTime:   1000,
				blockHeight: 123,
			},
			expectedID:            "gno.land/r/test/token:123",
			expectedName:          "Test Project",
			expectedTokenPath:     "gno.land/r/test/token",
			expectedDepositAmount: 1000000,
			expectedRecipient:     testutils.TestAddress("recipient"),
		},
		{
			name:          "create new project with zero deposit amount",
			projectName:   "Zero Deposit Project",
			tokenPath:     "gno.land/r/test/token",
			depositAmount: 0,
			recipient:     testutils.TestAddress("recipient"),
			createdBlockTimeInfo: &BlockTimeInfo{
				blockTime:   2000,
				blockHeight: 456,
			},
			expectedID:            "gno.land/r/test/token:456",
			expectedName:          "Zero Deposit Project",
			expectedTokenPath:     "gno.land/r/test/token",
			expectedDepositAmount: 0,
			expectedRecipient:     testutils.TestAddress("recipient"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute
			project := NewProject(
				tt.projectName,
				tt.tokenPath,
				tt.depositAmount,
				tt.recipient,
				tt.createdBlockTimeInfo,
			)

			// Verify
			uassert.Equal(t, project.ID(), tt.expectedID)
			uassert.Equal(t, project.Name(), tt.expectedName)
			uassert.Equal(t, project.TokenPath(), tt.expectedTokenPath)
			uassert.Equal(t, project.DepositAmount(), tt.expectedDepositAmount)
			uassert.Equal(t, project.Recipient(), tt.expectedRecipient)
			uassert.NotNil(t, project.conditions)
			uassert.NotNil(t, project.tiers)
			uassert.Equal(t, project.CreatedBlockTimeInfo(), tt.createdBlockTimeInfo)
		})
	}
}

func TestMakeProjectID(t *testing.T) {
	tests := []struct {
		name          string
		tokenPath     string
		createdHeight int64
		expectedID    string
	}{
		{
			name:          "generate project ID with valid parameters",
			tokenPath:     "gno.land/r/test/token",
			createdHeight: 123,
			expectedID:    "gno.land/r/test/token:123",
		},
		{
			name:          "generate project ID with zero height",
			tokenPath:     "gno.land/r/test/token",
			createdHeight: 0,
			expectedID:    "gno.land/r/test/token:0",
		},
		{
			name:          "generate project ID with empty token path",
			tokenPath:     "",
			createdHeight: 456,
			expectedID:    ":456",
		},
		{
			name:          "generate project ID with large height",
			tokenPath:     "gno.land/r/test/token",
			createdHeight: 999999999,
			expectedID:    "gno.land/r/test/token:999999999",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute
			result := makeProjectID(tt.tokenPath, tt.createdHeight)

			// Verify
			uassert.Equal(t, result, tt.expectedID)
		})
	}
}

func TestProject_TimeMethods(t *testing.T) {
	tests := []struct {
		name                string
		standardTier        *ProjectTier
		expectedStartTime   int64
		expectedEndTime     int64
		expectedStartHeight int64
		expectedEndHeight   int64
	}{
		{
			name: "get time information from standard tier",
			standardTier: &ProjectTier{
				startBlockTimeInfo: &BlockTimeInfo{
					blockTime:   1000,
					blockHeight: 100,
				},
				endBlockTimeInfo: &BlockTimeInfo{
					blockTime:   2000,
					blockHeight: 200,
				},
			},
			expectedStartTime:   1000,
			expectedEndTime:     2000,
			expectedStartHeight: 100,
			expectedEndHeight:   200,
		},
		{
			name: "get time information with zero values",
			standardTier: &ProjectTier{
				startBlockTimeInfo: &BlockTimeInfo{
					blockTime:   0,
					blockHeight: 0,
				},
				endBlockTimeInfo: &BlockTimeInfo{
					blockTime:   0,
					blockHeight: 0,
				},
			},
			expectedStartTime:   0,
			expectedEndTime:     0,
			expectedStartHeight: 0,
			expectedEndHeight:   0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				tiers: map[int64]*ProjectTier{
					projectTier180: tt.standardTier,
				},
			}

			// Execute and verify
			startTime := project.StartTime()
			endTime := project.EndTime()
			startHeight := project.StartHeight()
			endHeight := project.EndHeight()

			uassert.Equal(t, startTime, tt.expectedStartTime)
			uassert.Equal(t, endTime, tt.expectedEndTime)
			uassert.Equal(t, startHeight, tt.expectedStartHeight)
			uassert.Equal(t, endHeight, tt.expectedEndHeight)
		})
	}
}

func TestProject_TiersRatios(t *testing.T) {
	tests := []struct {
		name           string
		tiersRatios    map[int64]int64
		expectedRatios map[int64]int64
	}{
		{
			name: "get tiers ratios with multiple tiers",
			tiersRatios: map[int64]int64{
				30:  10,
				90:  20,
				180: 70,
			},
			expectedRatios: map[int64]int64{
				30:  10,
				90:  20,
				180: 70,
			},
		},
		{
			name:           "get tiers ratios with empty map",
			tiersRatios:    map[int64]int64{},
			expectedRatios: map[int64]int64{},
		},
		{
			name: "get tiers ratios with single tier",
			tiersRatios: map[int64]int64{
				180: 100,
			},
			expectedRatios: map[int64]int64{
				180: 100,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			project := &Project{
				tiersRatios: tt.tiersRatios,
			}

			// Execute
			result := project.TiersRatios()

			// Verify
			uassert.Equal(t, len(result), len(tt.expectedRatios))
			for duration, expectedRatio := range tt.expectedRatios {
				actualRatio, exists := result[duration]
				uassert.True(t, exists)
				uassert.Equal(t, actualRatio, expectedRatio)
			}
		})
	}
}
