package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/onbloc/obl"
)

func setupTest(t *testing.T) {
	projects = make(map[string]Project)
	projectTiersWithoutDeposit = make(map[string]bool)
}

func createTestAddress(t *testing.T) std.Address {
	addr := testutils.TestAddress("test")
	return addr
}

func TestValidateProjectInput(t *testing.T) {
	now := uint64(time.Now().Unix())
	testCases := []struct {
		name        string
		input       ProjectInput
		shouldError bool
	}{
		{
			name: "Valid input",
			input: ProjectInput{
				Name:          "Test Project",
				TokenPath:     "test/token",
				Recipient:     createTestAddress(t),
				DepositAmount: 1000,
				Tier30Ratio:   30,
				Tier90Ratio:   30,
				Tier180Ratio:  40,
				StartTime:     now + 3600, // 1 hour in future
			},
			shouldError: false,
		},
		{
			name: "Invalid tier ratios",
			input: ProjectInput{
				Name:          "Test Project",
				TokenPath:     "test/token",
				Recipient:     createTestAddress(t),
				DepositAmount: 1000,
				Tier30Ratio:   30,
				Tier90Ratio:   30,
				Tier180Ratio:  30, // Sum != 100
				StartTime:     now + 3600,
			},
			shouldError: true,
		},
		{
			name: "Start time in past",
			input: ProjectInput{
				Name:          "Test Project",
				TokenPath:     "test/token",
				Recipient:     createTestAddress(t),
				DepositAmount: 1000,
				Tier30Ratio:   30,
				Tier90Ratio:   30,
				Tier180Ratio:  40,
				StartTime:     now - 3600, // 1 hour in past
			},
			shouldError: true,
		},
		{
			name: "Zero deposit amount",
			input: ProjectInput{
				Name:          "Test Project",
				TokenPath:     "test/token",
				Recipient:     createTestAddress(t),
				DepositAmount: 0,
				Tier30Ratio:   30,
				Tier90Ratio:   30,
				Tier180Ratio:  40,
				StartTime:     now + 3600,
			},
			shouldError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			err := validateProjectInput(tc.input, now)
			if tc.shouldError && err == nil {
				t.Errorf("Expected error but got none")
			}
			if !tc.shouldError && err != nil {
				t.Errorf("Unexpected error: %v", err)
			}
		})
	}
}

func TestCreateProject(t *testing.T) {
	projectAddr := testutils.TestAddress("projectAddr")
	fooBarWithpad := "gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar"
	tests := []struct {
		name          string
		projectName   string
		tokenPath     string
		projectOwner  std.Address
		totalAmount   uint64
		conditions    string
		ratios        string
		tier30Ratio   uint64
		tier90Ratio   uint64
		tier180Ratio  uint64
		startTime     uint64
		expectedId    string
		expectedError string
		duplicateTest bool
	}{
		{
			name:          "normal project creation",
			projectName:   "Obl Protocol",
			tokenPath:     oblPath,
			projectOwner:  projectAddr,
			totalAmount:   uint64(1_000_000_000),
			conditions:    fooBarWithpad,
			ratios:        "1*PAD*2",
			tier30Ratio:   uint64(10),
			tier90Ratio:   uint64(20),
			tier180Ratio:  uint64(70),
			startTime:     uint64(time.Now().Unix() + 10),
			expectedId:    "gno.land/r/onbloc/obl:124",
			expectedError: "",
		},
		{
			name:          "invalid ratio sum (less than 100%)",
			projectName:   "Invalid Ratio",
			tokenPath:     oblPath,
			projectOwner:  projectAddr,
			totalAmount:   uint64(1_000_000_000),
			conditions:    fooBarWithpad,
			ratios:        "1*PAD*2",
			tier30Ratio:   uint64(10),
			tier90Ratio:   uint64(20),
			tier180Ratio:  uint64(60),
			startTime:     uint64(time.Now().Unix() + 10),
			expectedError: "[GNOSWAP-LAUNCHPAD-007] invalid input data || invalid ratio, sum of all tiers(30:10, 90:20, 180:60) should be 100",
		},
		{
			name:          "project name is empty",
			projectName:   "",
			tokenPath:     oblPath,
			projectOwner:  projectAddr,
			totalAmount:   uint64(1_000_000_000),
			conditions:    fooBarWithpad,
			ratios:        "1*PAD*2",
			tier30Ratio:   uint64(10),
			tier90Ratio:   uint64(20),
			tier180Ratio:  uint64(70),
			startTime:     uint64(time.Now().Unix() + 10),
			expectedError: "[GNOSWAP-LAUNCHPAD-007] invalid input data || invalid project name",
		},
		{
			name:          "project owner address is invalid",
			projectName:   "TTT",
			tokenPath:     oblPath,
			projectOwner:  "abcdef",
			totalAmount:   uint64(1_000_000_000),
			conditions:    fooBarWithpad,
			ratios:        "1*PAD*2",
			tier30Ratio:   uint64(10),
			tier90Ratio:   uint64(20),
			tier180Ratio:  uint64(70),
			startTime:     uint64(time.Now().Unix() + 10),
			expectedError: "[GNOSWAP-LAUNCHPAD-002] invalid address || (abcdef)",
		},
		{
			name:          "invalid start time",
			projectName:   "Obl Protocol",
			tokenPath:     oblPath,
			projectOwner:  projectAddr,
			totalAmount:   uint64(1_000_000_000),
			conditions:    fooBarWithpad,
			ratios:        "1*PAD*2",
			tier30Ratio:   uint64(10),
			tier90Ratio:   uint64(20),
			tier180Ratio:  uint64(70),
			startTime:     uint64(time.Now().Unix()),
			expectedId:    "gno.land/r/onbloc/obl:124",
			expectedError: "[GNOSWAP-LAUNCHPAD-007] invalid input data || invalid start time(1234567890), cannot start project in past(now:1234567902)",
		},
		{
			name:          "invalid token path",
			projectName:   "Obl Protocol",
			tokenPath:     "gno.land/r/test/token",
			projectOwner:  projectAddr,
			totalAmount:   uint64(1_000_000_000),
			conditions:    fooBarWithpad,
			ratios:        "1*PAD*2",
			tier30Ratio:   uint64(10),
			tier90Ratio:   uint64(20),
			tier180Ratio:  uint64(70),
			startTime:     uint64(time.Now().Unix() + 50),
			expectedId:    "gno.land/r/onbloc/obl:124",
			expectedError: "[GNOSWAP-LAUNCHPAD-007] invalid input data || token(gno.land/r/test/token) is not registered to grc20reg",
		},
		{
			name:          "duplicate project test - origin",
			projectName:   "Obl Protocol",
			tokenPath:     oblPath,
			projectOwner:  projectAddr,
			totalAmount:   uint64(1_000_000_000),
			conditions:    fooBarWithpad,
			ratios:        "1*PAD*2",
			tier30Ratio:   uint64(10),
			tier90Ratio:   uint64(20),
			tier180Ratio:  uint64(70),
			startTime:     uint64(time.Now().Unix() + 50),
			expectedId:    "gno.land/r/onbloc/obl:130",
			expectedError: "",
			duplicateTest: true,
		},
		{
			name:          "duplicate project test - duplicate",
			projectName:   "Obl Protocol",
			tokenPath:     oblPath,
			projectOwner:  projectAddr,
			totalAmount:   uint64(1_000_000_000),
			conditions:    fooBarWithpad,
			ratios:        "1*PAD*2",
			tier30Ratio:   uint64(10),
			tier90Ratio:   uint64(20),
			tier180Ratio:  uint64(70),
			startTime:     uint64(time.Now().Unix() + 50),
			expectedId:    "gno.land/r/onbloc/obl:130",
			expectedError: "[GNOSWAP-LAUNCHPAD-008] can not create same project in same block || project(gno.land/r/onbloc/obl:130) already exists",
			duplicateTest: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			std.TestSetRealm(adminRealm)
			obl.Approve(a2u(consts.LAUNCHPAD_ADDR), tt.totalAmount)
			if !tt.duplicateTest {
				std.TestSkipHeights(1)
			}

			defer func() {
				if r := recover(); r != nil {
					if tt.expectedError == "" {
						t.Errorf("unexpected error: %v", r)
					} else {
						uassert.Equal(t, r.(string), tt.expectedError)
					}
				}
			}()

			projectId := CreateProject(
				tt.projectName,
				tt.tokenPath,
				tt.projectOwner,
				tt.totalAmount,
				tt.conditions,
				tt.ratios,
				tt.tier30Ratio,
				tt.tier90Ratio,
				tt.tier180Ratio,
				tt.startTime,
			)

			if tt.expectedError == "" {
				uassert.Equal(t, projectId, tt.expectedId)
			}
			if !tt.duplicateTest {
				std.TestSkipHeights(1)
			}
		})
	}
}

func TestCreateProject_TierAndBalance(t *testing.T) {
	projectAddr := testutils.TestAddress("projectAddr")
	fooBarWithpad := "gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar"
	tests := []struct {
		name          string
		projectName   string
		tokenPath     string
		projectOwner  std.Address
		totalAmount   uint64
		conditions    string
		ratios        string
		tier30Ratio   uint64
		tier90Ratio   uint64
		tier180Ratio  uint64
		startTime     uint64
		expectedId    string
		expectedError string
	}{
		{
			name:          "normal project creation",
			projectName:   "Obl Protocol",
			tokenPath:     oblPath,
			projectOwner:  projectAddr,
			totalAmount:   uint64(1_000_000_000),
			conditions:    fooBarWithpad,
			ratios:        "1*PAD*2",
			tier30Ratio:   uint64(10),
			tier90Ratio:   uint64(20),
			tier180Ratio:  uint64(70),
			startTime:     uint64(time.Now().Unix() + 10),
			expectedId:    "gno.land/r/onbloc/obl:124",
			expectedError: "[GNOSWAP-LAUNCHPAD-008] can not create same project in same block || project(gno.land/r/onbloc/obl:124) already exists",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			std.TestSetRealm(adminRealm)
			obl.Approve(a2u(consts.LAUNCHPAD_ADDR), tt.totalAmount)
			std.TestSkipHeights(1)

			defer func() {
				if r := recover(); r != nil {
					if tt.expectedError == "" {
						t.Errorf("unexpected error: %v", r)
					} else {
						uassert.Equal(t, r.(string), tt.expectedError)
					}
				}
			}()

			projectId := CreateProject(
				tt.projectName,
				tt.tokenPath,
				tt.projectOwner,
				tt.totalAmount,
				tt.conditions,
				tt.ratios,
				tt.tier30Ratio,
				tt.tier90Ratio,
				tt.tier180Ratio,
				tt.startTime,
			)

			if tt.expectedError == "" {
				uassert.Equal(t, projectId, tt.expectedId)
			}
			std.TestSkipHeights(1)
		})
	}
}

func TestMakeConditions(t *testing.T) {
	tests := []struct {
		name             string
		conditionsToken  string
		conditionsAmount string
		wantLen          int
		wantPanic        bool
		wantAmounts      map[string]uint64
	}{
		{
			name:             "normal multiple input",
			conditionsToken:  "token1*PAD*token2*PAD*token3",
			conditionsAmount: "100*PAD*200*PAD*300",
			wantLen:          3,
			wantPanic:        false,
			wantAmounts: map[string]uint64{
				"token1": 100,
				"token2": 200,
				"token3": 300,
			},
		},
		{
			name:             "empty input",
			conditionsToken:  "",
			conditionsAmount: "",
			wantLen:          0,
			wantPanic:        false,
			wantAmounts:      nil,
		},
		{
			name:             "single condition",
			conditionsToken:  "token1",
			conditionsAmount: "100",
			wantLen:          1,
			wantPanic:        false,
			wantAmounts: map[string]uint64{
				"token1": 100,
			},
		},
		{
			name:             "invalid amount format",
			conditionsToken:  "token1",
			conditionsAmount: "invalid",
			wantLen:          0,
			wantPanic:        true,
			wantAmounts:      nil,
		},
		{
			name:             "token and amount count mismatch",
			conditionsToken:  "token1*PAD*token2",
			conditionsAmount: "100",
			wantLen:          0,
			wantPanic:        true,
			wantAmounts:      nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if (r != nil) != tt.wantPanic {
					t.Errorf("makeConditions() panic = %v, wantPanic = %v", r != nil, tt.wantPanic)
				}
			}()

			got := makeConditions(tt.conditionsToken, tt.conditionsAmount)

			if !tt.wantPanic {
				if tt.wantAmounts == nil {
					if got != nil {
						t.Errorf("makeConditions() = %v, want nil", got)
					}
					return
				}

				count := 0
				for range got {
					count++
				}
				uassert.Equal(t, count, tt.wantLen)

				for token, wantAmount := range tt.wantAmounts {
					condition, exists := got[token]
					uassert.True(t, exists)
					uassert.Equal(t, condition.minAmount, wantAmount)
				}
			}
		})
	}
}

func TestCalculateLeftReward(t *testing.T) {
	tests := []struct {
		name        string
		project     Project
		want        uint64
		description string
	}{
		{
			name: "all tiers have remaining rewards",
			project: Project{
				tiers: map[uint64]Tier{
					30: {
						tierAmount:       1000,
						calculatedAmount: 400,
					},
					90: {
						tierAmount:       2000,
						calculatedAmount: 800,
					},
					180: {
						tierAmount:       3000,
						calculatedAmount: 1200,
					},
				},
			},
			want:        3600, // (1000-400) + (2000-800) + (3000-1200)
			description: "Should sum up all remaining rewards from each tier",
		},
		{
			name: "some tiers fully claimed",
			project: Project{
				tiers: map[uint64]Tier{
					30: {
						tierAmount:       1000,
						calculatedAmount: 1000,
					},
					90: {
						tierAmount:       2000,
						calculatedAmount: 800,
					},
					180: {
						tierAmount:       3000,
						calculatedAmount: 3000,
					},
				},
			},
			want:        1200, // (1000-1000) + (2000-800) + (3000-3000)
			description: "Should handle fully claimed tiers correctly",
		},
		{
			name: "all tiers fully claimed",
			project: Project{
				tiers: map[uint64]Tier{
					30: {
						tierAmount:       1000,
						calculatedAmount: 1000,
					},
					90: {
						tierAmount:       2000,
						calculatedAmount: 2000,
					},
					180: {
						tierAmount:       3000,
						calculatedAmount: 3000,
					},
				},
			},
			want:        0,
			description: "Should return 0 when all rewards are claimed",
		},
		{
			name: "no rewards calculated yet",
			project: Project{
				tiers: map[uint64]Tier{
					30: {
						tierAmount:       1000,
						calculatedAmount: 0,
					},
					90: {
						tierAmount:       2000,
						calculatedAmount: 0,
					},
					180: {
						tierAmount:       3000,
						calculatedAmount: 0,
					},
				},
			},
			want:        6000, // 1000 + 2000 + 3000
			description: "Should return total tier amounts when no rewards calculated",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := calculateLeftReward(tt.project)
			uassert.Equal(t, got, tt.want)
		})
	}
}

func TestCreateTier(t *testing.T) {
	// Constants for test
	const (
		AVG_BLOCK_TIME_MS = 2000
		TIMESTAMP_DAY     = 86400
	)

	tests := []struct {
		name                string
		projectId           string
		duration            uint64
		amount              uint64
		startHeight         uint64
		startTime           uint64
		collectWaitDuration uint64
		want                Tier
		description         string
	}{
		{
			name:                "30-day tier creation",
			projectId:           "project1",
			duration:            30,
			amount:              1000,
			startHeight:         1000,
			startTime:           1600000000,
			collectWaitDuration: 100,
			want: Tier{
				id:                  "project1:30",
				collectWaitDuration: 100,
				tierAmount:          1000,
				ended: TimeInfo{
					height: 1000 + (30 * TIMESTAMP_DAY * 1000 / AVG_BLOCK_TIME_MS),
					time:   1600000000 + (30 * TIMESTAMP_DAY),
				},
			},
			description: "Should create a 30-day tier with correct end time and height",
		},
		{
			name:                "90-day tier creation",
			projectId:           "project2",
			duration:            90,
			amount:              2000,
			startHeight:         2000,
			startTime:           1700000000,
			collectWaitDuration: 200,
			want: Tier{
				id:                  "project2:90",
				collectWaitDuration: 200,
				tierAmount:          2000,
				ended: TimeInfo{
					height: 2000 + (90 * TIMESTAMP_DAY * 1000 / AVG_BLOCK_TIME_MS),
					time:   1700000000 + (90 * TIMESTAMP_DAY),
				},
			},
			description: "Should create a 90-day tier with correct end time and height",
		},
		{
			name:                "180-day tier creation",
			projectId:           "project3",
			duration:            180,
			amount:              3000,
			startHeight:         3000,
			startTime:           1800000000,
			collectWaitDuration: 300,
			want: Tier{
				id:                  "project3:180",
				collectWaitDuration: 300,
				tierAmount:          3000,
				ended: TimeInfo{
					height: 3000 + (180 * TIMESTAMP_DAY * 1000 / AVG_BLOCK_TIME_MS),
					time:   1800000000 + (180 * TIMESTAMP_DAY),
				},
			},
			description: "Should create a 180-day tier with correct end time and height",
		},
		{
			name:                "zero duration tier",
			projectId:           "project4",
			duration:            0,
			amount:              1000,
			startHeight:         4000,
			startTime:           1900000000,
			collectWaitDuration: 400,
			want: Tier{
				id:                  "project4:0",
				collectWaitDuration: 400,
				tierAmount:          1000,
				ended: TimeInfo{
					height: 4000,
					time:   1900000000,
				},
			},
			description: "Should handle zero duration correctly",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			projectTiersWithoutDeposit = make(map[string]bool)

			got := createTier(
				tt.projectId,
				tt.duration,
				tt.amount,
				tt.startHeight,
				tt.startTime,
				tt.collectWaitDuration,
			)

			uassert.Equal(t, got.id, tt.want.id)
			uassert.Equal(t, got.collectWaitDuration, tt.want.collectWaitDuration)
			uassert.Equal(t, got.tierAmount, tt.want.tierAmount)
			uassert.Equal(t, got.ended.height, tt.want.ended.height)
			uassert.Equal(t, got.ended.time, tt.want.ended.time)
			uassert.True(t, projectTiersWithoutDeposit[got.id])
		})
	}
}

func TestCalculateProjectParams(t *testing.T) {
	currentTime := uint64(time.Now().Unix())
	baseHeight := uint64(std.GetHeight())

	tests := []struct {
		name    string
		input   ProjectInput
		now     uint64
		want    *ProjectCalculationResult
		wantErr bool
	}{
		{
			name: "valid input with equal ratio distribution",
			input: ProjectInput{
				DepositAmount: 3000,
				Tier30Ratio:   33,
				Tier90Ratio:   33,
				Tier180Ratio:  34,
				StartTime:     currentTime + 1000, // 1000 seconds in future
			},
			now: currentTime,
			want: &ProjectCalculationResult{
				Tier30Amount:  990,              // 3000 * 33 / 100
				Tier90Amount:  990,              // 3000 * 33 / 100
				Tier180Amount: 1020,             // 3000 * 34 / 100
				StartHeight:   baseHeight + 500, // 1000 seconds = 500 blocks
			},
			wantErr: false,
		},
		{
			name: "valid input with uneven ratio distribution",
			input: ProjectInput{
				DepositAmount: 10000,
				Tier30Ratio:   20,
				Tier90Ratio:   30,
				Tier180Ratio:  50,
				StartTime:     currentTime + 2000, // 2000 seconds in future
			},
			now: currentTime,
			want: &ProjectCalculationResult{
				Tier30Amount:  2000,              // 10000 * 20 / 100
				Tier90Amount:  3000,              // 10000 * 30 / 100
				Tier180Amount: 5000,              // 10000 * 50 / 100
				StartHeight:   baseHeight + 1000, // 2000 seconds = 1000 blocks
			},
			wantErr: false,
		},
		{
			name: "start time in the past",
			input: ProjectInput{
				DepositAmount: 1000,
				Tier30Ratio:   30,
				Tier90Ratio:   30,
				Tier180Ratio:  40,
				StartTime:     currentTime - 1000, // 과거 시간
			},
			now:     currentTime,
			want:    nil,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := calculateProjectParams(tt.input, tt.now)

			if tt.wantErr {
				uassert.Error(t, err)
				return
			}

			uassert.NoError(t, err)
			uassert.Equal(t, got.Tier30Amount, tt.want.Tier30Amount)
			uassert.Equal(t, got.Tier90Amount, tt.want.Tier90Amount)
			uassert.Equal(t, got.Tier180Amount, tt.want.Tier180Amount)
			uassert.Equal(t, got.StartHeight, tt.want.StartHeight)
		})
	}
}
