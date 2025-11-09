package v1

import (
	"strings"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/onbloc/json"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestJsonBuilder_projectStatsBuilder(t *testing.T) {
	tests := []struct {
		name                   string
		totalDepositAmount     int64
		totalWithdrawAmount    int64
		totalDepositCount      int64
		totalWithdrawCount     int64
		totalCollectedAmount   int64
		expectedTotalDeposit   string
		expectedActualDeposit  string
		expectedTotalPart      string
		expectedActualPart     string
		expectedTotalCollected string
	}{
		{
			name:                   "project stats with basic values",
			totalDepositAmount:     1000,
			totalWithdrawAmount:    200,
			totalDepositCount:      10,
			totalWithdrawCount:     2,
			totalCollectedAmount:   500,
			expectedTotalDeposit:   "1000",
			expectedActualDeposit:  "800",
			expectedTotalPart:      "10",
			expectedActualPart:     "8",
			expectedTotalCollected: "500",
		},
		{
			name:                   "project stats with zero values",
			totalDepositAmount:     0,
			totalWithdrawAmount:    0,
			totalDepositCount:      0,
			totalWithdrawCount:     0,
			totalCollectedAmount:   0,
			expectedTotalDeposit:   "0",
			expectedActualDeposit:  "0",
			expectedTotalPart:      "0",
			expectedActualPart:     "0",
			expectedTotalCollected: "0",
		},
		{
			name:                   "project stats with all withdrawn",
			totalDepositAmount:     1000,
			totalWithdrawAmount:    1000,
			totalDepositCount:      5,
			totalWithdrawCount:     5,
			totalCollectedAmount:   1000,
			expectedTotalDeposit:   "1000",
			expectedActualDeposit:  "0",
			expectedTotalPart:      "5",
			expectedActualPart:     "0",
			expectedTotalCollected: "1000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup tier with test values
			tier := &ProjectTier{
				totalDepositAmount:   tt.totalDepositAmount,
				totalWithdrawAmount:  tt.totalWithdrawAmount,
				totalDepositCount:    tt.totalDepositCount,
				totalWithdrawCount:   tt.totalWithdrawCount,
				totalCollectedAmount: tt.totalCollectedAmount,
			}

			project := &Project{
				tiers: map[int64]*ProjectTier{
					projectTier180: tier,
				},
			}

			// Execute
			builder := json.Builder()
			projectStatsBuilder(builder, project)
			result := marshal(builder.Node())

			// Verify
			uassert.True(t, strings.Contains(result, `"totalDeposit":"`+tt.expectedTotalDeposit+`"`))
			uassert.True(t, strings.Contains(result, `"actualDeposit":"`+tt.expectedActualDeposit+`"`))
			uassert.True(t, strings.Contains(result, `"totalParticipant":"`+tt.expectedTotalPart+`"`))
			uassert.True(t, strings.Contains(result, `"actualParticipant":"`+tt.expectedActualPart+`"`))
			uassert.True(t, strings.Contains(result, `"totalCollected":"`+tt.expectedTotalCollected+`"`))
		})
	}
}

func TestJsonBuilder_refundInfoBuilder(t *testing.T) {
	tests := []struct {
		name                  string
		totalDistributeAmount int64
		totalCollectedAmount  int64
		expectedRefundAmount  string
	}{
		{
			name:                  "refund info with remaining amount",
			totalDistributeAmount: 1000,
			totalCollectedAmount:  600,
			expectedRefundAmount:  "400",
		},
		{
			name:                  "refund info with no remaining",
			totalDistributeAmount: 1000,
			totalCollectedAmount:  1000,
			expectedRefundAmount:  "0",
		},
		{
			name:                  "refund info with zero values",
			totalDistributeAmount: 0,
			totalCollectedAmount:  0,
			expectedRefundAmount:  "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			tier := &ProjectTier{
				totalDistributeAmount: tt.totalDistributeAmount,
				totalCollectedAmount:  tt.totalCollectedAmount,
			}

			project := &Project{
				tiers: map[int64]*ProjectTier{
					projectTier180: tier,
				},
			}

			// Execute
			builder := json.Builder()
			refundInfoBuilder(builder, project)
			result := marshal(builder.Node())

			// Verify
			uassert.True(t, strings.Contains(result, `"refundedAmount":"`+tt.expectedRefundAmount+`"`))
		})
	}
}

func TestJsonBuilder_tierBuilder(t *testing.T) {
	tests := []struct {
		name                  string
		prefix                string
		tierId                string
		totalDistributeAmount int64
		startTime             int64
		endTime               int64
		totalDepositAmount    int64
		totalWithdrawAmount   int64
		totalDepositCount     int64
		totalWithdrawCount    int64
		totalCollectedAmount  int64
	}{
		{
			name:                  "tier builder with basic values",
			prefix:                "tier30",
			tierId:                "test:30",
			totalDistributeAmount: 1000,
			startTime:             1000,
			endTime:               2000,
			totalDepositAmount:    500,
			totalWithdrawAmount:   100,
			totalDepositCount:     10,
			totalWithdrawCount:    2,
			totalCollectedAmount:  300,
		},
		{
			name:                  "tier builder with empty prefix",
			prefix:                "",
			tierId:                "test:180",
			totalDistributeAmount: 5000,
			startTime:             0,
			endTime:               10000,
			totalDepositAmount:    2000,
			totalWithdrawAmount:   500,
			totalDepositCount:     20,
			totalWithdrawCount:    5,
			totalCollectedAmount:  1500,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			tier := &ProjectTier{
				id:                            tt.tierId,
				totalDistributeAmount:         tt.totalDistributeAmount,
				distributeAmountPerSecondX128: u256.NewUintFromInt64(100),
				startTime:                     tt.startTime,
				endTime:                       tt.endTime,
				totalDepositAmount:            tt.totalDepositAmount,
				totalWithdrawAmount:           tt.totalWithdrawAmount,
				totalDepositCount:             tt.totalDepositCount,
				totalWithdrawCount:            tt.totalWithdrawCount,
				totalCollectedAmount:          tt.totalCollectedAmount,
			}

			// Execute
			builder := json.Builder()
			tierBuilder(builder, tt.prefix, tier)
			result := marshal(builder.Node())

			// Verify key fields exist
			uassert.True(t, strings.Contains(result, tt.prefix+"Id"))
			uassert.True(t, strings.Contains(result, tt.tierId))
			uassert.True(t, strings.Contains(result, tt.prefix+"TierAmount"))
			uassert.True(t, strings.Contains(result, tt.prefix+"Started"))
			uassert.True(t, strings.Contains(result, tt.prefix+"Ended"))
		})
	}
}

func TestJsonBuilder_projectBuilder(t *testing.T) {
	testAddr := testutils.TestAddress("recipient")

	tests := []struct {
		name              string
		projectName       string
		tokenPath         string
		depositAmount     int64
		recipient         address
		conditionTokens   []string
		conditionAmounts  []int64
		createdAt         int64
		tierStartTime     int64
		tierEndTime       int64
		expectedHasFields bool
	}{
		{
			name:             "project builder with basic info",
			projectName:      "Test Project",
			tokenPath:        "gno.land/r/demo/token",
			depositAmount:    1000000,
			recipient:        testAddr,
			conditionTokens:  []string{"gno.land/r/demo/gns"},
			conditionAmounts: []int64{1000},
			createdAt:        1000,
			tierStartTime:    2000,
			tierEndTime:      3000,
			expectedHasFields: true,
		},
		{
			name:             "project builder with multiple conditions",
			projectName:      "Multi Condition",
			tokenPath:        "gno.land/r/demo/token2",
			depositAmount:    5000000,
			recipient:        testAddr,
			conditionTokens:  []string{"gno.land/r/demo/gns", "gno.land/r/demo/usdc"},
			conditionAmounts: []int64{1000, 2000},
			createdAt:        500,
			tierStartTime:    1500,
			tierEndTime:      2500,
			expectedHasFields: true,
		},
		{
			name:              "project builder with no conditions",
			projectName:       "No Conditions",
			tokenPath:         "gno.land/r/demo/token3",
			depositAmount:     100000,
			recipient:         testAddr,
			conditionTokens:   []string{},
			conditionAmounts:  []int64{},
			createdAt:         100,
			tierStartTime:     200,
			tierEndTime:       300,
			expectedHasFields: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			tier := &ProjectTier{
				startTime: tt.tierStartTime,
				endTime:   tt.tierEndTime,
			}

			project := &Project{
				name:          tt.projectName,
				tokenPath:     tt.tokenPath,
				depositAmount: tt.depositAmount,
				recipient:     tt.recipient,
				conditions:    make(map[string]*ProjectCondition),
				tiers: map[int64]*ProjectTier{
					projectTier180: tier,
				},
				createdAt: tt.createdAt,
			}

			// Add conditions
			for i, token := range tt.conditionTokens {
				project.conditions[token] = &ProjectCondition{
					tokenPath:     token,
					minimumAmount: tt.conditionAmounts[i],
				}
			}

			// Execute
			builder := json.Builder()
			projectBuilder(builder, project)
			result := marshal(builder.Node())

			// Verify
			if tt.expectedHasFields {
				uassert.True(t, strings.Contains(result, `"name":"`+tt.projectName+`"`))
				uassert.True(t, strings.Contains(result, `"tokenPath":"`+tt.tokenPath+`"`))
				uassert.True(t, strings.Contains(result, `"recipient":`))
				uassert.True(t, strings.Contains(result, `"createdTime"`))
				uassert.True(t, strings.Contains(result, `"startedTime"`))
				uassert.True(t, strings.Contains(result, `"endedTime"`))
				uassert.True(t, strings.Contains(result, `"refundedAmount"`))
			}
		})
	}
}

func TestJsonBuilder_depositBuilder(t *testing.T) {
	testAddr := testutils.TestAddress("depositor")

	tests := []struct {
		name           string
		depositId      string
		projectId      string
		tier           int64
		depositor      address
		depositAmount  int64
		createdHeight  int64
		createdAt      int64
		expectedHasAll bool
	}{
		{
			name:           "deposit builder with basic values",
			depositId:      "deposit1",
			projectId:      "project1",
			tier:           30,
			depositor:      testAddr,
			depositAmount:  1000000,
			createdHeight:  100,
			createdAt:      1000,
			expectedHasAll: true,
		},
		{
			name:           "deposit builder with zero values",
			depositId:      "deposit0",
			projectId:      "project0",
			tier:           0,
			depositor:      testAddr,
			depositAmount:  0,
			createdHeight:  0,
			createdAt:      0,
			expectedHasAll: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			deposit := &Deposit{
				id:            tt.depositId,
				projectID:     tt.projectId,
				tier:          tt.tier,
				depositor:     tt.depositor,
				depositAmount: tt.depositAmount,
				createdHeight: tt.createdHeight,
				createdAt:     tt.createdAt,
			}

			// Execute
			builder := json.Builder()
			depositBuilder(builder, deposit)
			result := marshal(builder.Node())

			// Verify
			if tt.expectedHasAll {
				uassert.True(t, strings.Contains(result, `"depositId":"`+tt.depositId+`"`))
				uassert.True(t, strings.Contains(result, `"projectId":"`+tt.projectId+`"`))
				uassert.True(t, strings.Contains(result, `"depositor":`))
				uassert.True(t, strings.Contains(result, `"amount"`))
				uassert.True(t, strings.Contains(result, `"depositHeight"`))
				uassert.True(t, strings.Contains(result, `"depositTime"`))
			}
		})
	}
}

func TestJsonBuilder_metaBuilder(t *testing.T) {
	tests := []struct {
		name              string
		expectedHasHeight bool
		expectedHasNow    bool
	}{
		{
			name:              "meta builder returns height and now",
			expectedHasHeight: true,
			expectedHasNow:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute
			builder := metaBuilder()
			result := marshal(builder.Node())

			// Verify
			if tt.expectedHasHeight {
				uassert.True(t, strings.Contains(result, `"height"`))
			}
			if tt.expectedHasNow {
				uassert.True(t, strings.Contains(result, `"now"`))
			}
		})
	}
}

func TestJsonBuilder_marshal(t *testing.T) {
	tests := []struct {
		name           string
		setupBuilder   func() *json.NodeBuilder
		expectedSubstr string
	}{
		{
			name: "marshal simple json",
			setupBuilder: func() *json.NodeBuilder {
				return json.Builder().WriteString("key", "value")
			},
			expectedSubstr: `"key":"value"`,
		},
		{
			name: "marshal empty json",
			setupBuilder: func() *json.NodeBuilder {
				return json.Builder()
			},
			expectedSubstr: `{`,
		},
		{
			name: "marshal json with multiple fields",
			setupBuilder: func() *json.NodeBuilder {
				return json.Builder().
					WriteString("field1", "value1").
					WriteString("field2", "value2")
			},
			expectedSubstr: `"field1"`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			builder := tt.setupBuilder()

			// Execute
			result := marshal(builder.Node())

			// Verify
			uassert.True(t, strings.Contains(result, tt.expectedSubstr))
		})
	}
}
