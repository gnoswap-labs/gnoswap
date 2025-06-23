package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/gns"
)

func setupTestDeposit(t *testing.T) (*MockTokenTeller, std.Address) {
	t.Helper()
	projects = make(map[string]Project)
	deposits = make(map[string]Deposit)
	depositsByProject = make(map[string]map[string][]string)
	depositsByUser = make(map[std.Address][]string)
	depositsByUserByProject = make(map[std.Address]map[string][]string)

	mockTeller := &MockTokenTeller{balance: 1000}
	testAddr := testutils.TestAddress("test")

	return mockTeller, testAddr
}

func createTestProject(t *testing.T) Project {
	now := uint64(time.Now().Unix())
	height := uint64(std.ChainHeight())

	tiers := make(map[uint64]Tier)
	tiersRatios := make(map[uint64]uint64)

	tiers[30] = Tier{
		id:                  ufmt.Sprintf("gno.land/r/gnoswap/v1/gns:%d:30", height),
		collectWaitDuration: TIMESTAMP_3DAYS * 1000 / 1000,
		tierAmount:          300,
		started: TimeInfo{
			height: height,
			time:   now,
		},
		ended: TimeInfo{
			height: height + (30 * 24 * 60 * 60),
			time:   now + (30 * 24 * 60 * 60),
		},
		reward: *NewReward(u256.Zero(), 0, 0),
	}
	tiersRatios[30] = 30

	tiers[90] = Tier{
		id:                  ufmt.Sprintf("gno.land/r/gnoswap/v1/gns:%d:90", height),
		collectWaitDuration: TIMESTAMP_7DAYS * 1000 / 1000,
		tierAmount:          300,
		started: TimeInfo{
			height: height,
			time:   now,
		},
		ended: TimeInfo{
			height: height + (90 * 24 * 60 * 60),
			time:   now + (90 * 24 * 60 * 60),
		},
		reward: *NewReward(u256.Zero(), 0, 0),
	}
	tiersRatios[90] = 30

	tiers[180] = Tier{
		id:                  ufmt.Sprintf("gno.land/r/gnoswap/v1/gns:%d:180", height),
		collectWaitDuration: TIMESTAMP_14DAYS * 1000 / 1000,
		tierAmount:          400,
		started: TimeInfo{
			height: height,
			time:   now,
		},
		ended: TimeInfo{
			height: height + (180 * 24 * 60 * 60),
			time:   now + (180 * 24 * 60 * 60),
		},
		reward: *NewReward(u256.Zero(), 0, 0),
	}
	tiersRatios[180] = 40

	return Project{
		id:            ufmt.Sprintf("gno.land/r/gnoswap/v1/gns:%d", height),
		name:          "Test Project",
		tokenPath:     "gno.land/r/gnoswap/v1/gns",
		depositAmount: 1000,
		recipient:     testutils.TestAddress("recipient"),
		conditions:    make(map[string]Condition),
		tiers:         tiers,
		tiersRatios:   tiersRatios,
		created: TimeInfo{
			height: height,
			time:   now,
		},
		started: TimeInfo{
			height: height,
			time:   now,
		},
		ended: TimeInfo{
			height: height + (180 * 24 * 60 * 60),
			time:   now + (180 * 24 * 60 * 60),
		},
		stats: ProjectStats{
			totalDeposit:      0,
			actualDeposit:     0,
			totalParticipant:  0,
			actualParticipant: 0,
			totalCollected:    0,
		},
		refund: RefundInfo{
			amount: 0,
			height: 0,
			time:   0,
		},
	}
}

func TestValidateProjectTier(t *testing.T) {
	setupTestDeposit(t)
	project := createTestProject(t)
	projects[project.id] = project

	tests := []struct {
		name        string
		projectId   string
		tierStr     string
		shouldError bool
	}{
		{
			name:        "Valid project and tier",
			projectId:   project.id,
			tierStr:     "30",
			shouldError: false,
		},
		{
			name:        "Invalid project id",
			projectId:   "nonexistent",
			tierStr:     "30",
			shouldError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, err := validateProjectTier(tt.projectId, tt.tierStr)
			switch tt.shouldError {
			case true:
				uassert.Error(t, err)
			case false:
				uassert.NoError(t, err)
			}
		})
	}
}

func TestCreateDeposit(t *testing.T) {
	setupTestDeposit(t)
	project := createTestProject(t)
	now := uint64(time.Now().Unix())
	height := uint64(std.ChainHeight())

	info := ProjectTierInfo{
		Project:       project,
		Tier:          project.tiers[30],
		TierType:      "30",
		CurrentHeight: height,
		CurrentTime:   now,
	}

	deposit, err := createDeposit(cross, info, 100)
	if err != nil {
		t.Fatalf("Failed to create deposit: %v", err)
	}

	uassert.Equal(t, deposit.amount, uint64(100))
	uassert.Equal(t, deposit.depositHeight, height)
	uassert.Equal(t, deposit.depositTime, now)
	uassert.Equal(t, deposit.projectId, project.id)
}

func TestCalculateClaimableTimes(t *testing.T) {
	tests := []struct {
		name       string
		info       ProjectTierInfo
		wantHeight uint64
		wantTime   uint64
	}{
		{
			name: "Tier 30 - Normal Case",
			info: ProjectTierInfo{
				Project: Project{},
				Tier: Tier{
					collectWaitDuration: 100,
					ended: TimeInfo{
						height: 1000,
						time:   1000000,
					},
				},
				TierType:      "30",
				CurrentHeight: 500,
				CurrentTime:   500000,
			},
			wantHeight: 600,    // CurrentHeight(500) + collectWaitDuration(100)
			wantTime:   759200, // CurrentTime(500000) + TIMESTAMP_3DAYS
		},
		{
			name: "Tier 90 - Exceeds End CurrentHeight/Time",
			info: ProjectTierInfo{
				Project: Project{},
				Tier: Tier{
					collectWaitDuration: 200,
					ended: TimeInfo{
						height: 550,
						time:   600000,
					},
				},
				TierType:      "90",
				CurrentHeight: 400,
				CurrentTime:   400000,
			},
			wantHeight: 550,    // min(400+200, endHeight(550))
			wantTime:   600000, // min(400000+TIMESTAMP_7DAYS, endTime(600000))
		},
		{
			name: "Tier 180 - Early Stage",
			info: ProjectTierInfo{
				Project: Project{},
				Tier: Tier{
					collectWaitDuration: 300,
					ended: TimeInfo{
						height: 2000,
						time:   2000000,
					},
				},
				TierType:      "180",
				CurrentHeight: 100,
				CurrentTime:   100000,
			},
			wantHeight: 400,     // CurrentHeight(100) + collectWaitDuration(300)
			wantTime:   1309600, // CurrentTime(100000) + TIMESTAMP_14DAYS
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotHeight, gotTime := calculateClaimableTimes(tt.info)
			uassert.Equal(t, gotHeight, tt.wantHeight)
			uassert.Equal(t, gotTime, tt.wantTime)
		})
	}
}

func TestCollectDeposit(t *testing.T) {
	t.Skip("fix this test")
	_, testAddr := setupTestDeposit(t)
	project := createTestProject(t)
	projects[project.id] = project
	currentTime := uint64(time.Now().Unix())
	height := uint64(std.ChainHeight())

	// Create test deposit
	info := ProjectTierInfo{
		Project:       project,
		Tier:          project.tiers[30],
		TierType:      "30",
		CurrentHeight: height,
		CurrentTime:   currentTime,
	}

	deposit, err := createDeposit(cross, info, 100)
	if err != nil {
		t.Fatalf("Failed to create deposit: %v", err)
	}

	// Add deposit to indices
	deposits[deposit.id] = deposit
	updateDepositIndices(deposit, &DepositState{
		Deposits:              make(map[string]Deposit),
		DepositsByProject:     depositsByProject,
		DepositsByUser:        depositsByUser,
		DepositsByUserProject: depositsByUserByProject,
	})

	t.Run("Cannot collect before claimable height", func(t *testing.T) {
		testing.SetRealm(std.NewUserRealm(testAddr))
		amount, _ := processDepositCollection(cross, []string{deposit.id}, "")
		uassert.Equal(t, uint64(0), amount)
	})

	t.Run("Can collect after claimable height", func(t *testing.T) {
		// Skip to after claimable height
		testing.SkipHeights(int64(deposit.claimableHeight - height + 1))

		testing.SetRealm(std.NewUserRealm(testAddr))
		amount, errCode := processDepositCollection(cross, []string{deposit.id}, "")
		uassert.NoError(t, errCode)
		uassert.Equal(t, uint64(100), amount)
	})
}

func TestDepositGns(t *testing.T) {
	project := createTestProject(t)

	tests := []struct {
		name             string
		inputPoolId      string
		inputAmount      uint64
		expectedHasPanic bool
		expectedPanicMsg string
		expectedHasAbort bool
		expectedAbortMsg string
	}{
		{
			name:             "deposit gns success",
			inputPoolId:      project.id + ":30",
			inputAmount:      1000000,
			expectedHasAbort: false,
			expectedAbortMsg: "",
		},
		{
			name:             "deposit gns failed by insufficient balance",
			inputPoolId:      project.id + ":30",
			inputAmount:      1000,
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-LAUNCHPAD-017] invalid amount || amount(1000) should greater than minimum deposit amount(1000000)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			_, testAddr := setupTestDeposit(t)
			projects[project.id] = project

			testing.SetRealm(adminRealm)
			gns.Transfer(cross, testAddr, 1000000)

			testing.SetRealm(std.NewUserRealm(testAddr))
			gns.Approve(cross, launchpadAddr, 1000000)

			var depositId string

			// when
			if tt.expectedHasPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMsg, func() {
					DepositGns(cross, tt.inputPoolId, tt.inputAmount, "")
				})
				return
			} else if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					DepositGns(cross, tt.inputPoolId, tt.inputAmount, "")
				})
				return
			} else {
				depositId = DepositGns(cross, tt.inputPoolId, tt.inputAmount, "")
			}

			// then
			testing.SkipHeights(10)

			deposit := deposits[depositId]

			uassert.Equal(t, tt.inputAmount, deposit.amount)
			uassert.Equal(t, testAddr, deposit.depositor)
		})
	}

}

func TestUpdateDepositIndices(t *testing.T) {
	_, testAddr := setupTestDeposit(t)
	project := createTestProject(t)

	deposit := Deposit{
		id:        "test_deposit_1",
		projectId: project.id,
		tier:      "30",
		depositor: testAddr,
		amount:    100,
	}

	state := &DepositState{
		Deposits:              make(map[string]Deposit),
		DepositsByProject:     make(map[string]map[string][]string),
		DepositsByUser:        make(map[std.Address][]string),
		DepositsByUserProject: make(map[std.Address]map[string][]string),
	}

	updateDepositIndices(deposit, state)

	// Check depositsByUser
	userDeposits := state.DepositsByUser[testAddr]
	uassert.Equal(t, 1, len(userDeposits))
	uassert.Equal(t, deposit.id, userDeposits[0])

	// Check depositsByProject
	projectDeposits := state.DepositsByProject[project.id][deposit.tier]
	uassert.Equal(t, 1, len(projectDeposits))
	uassert.Equal(t, deposit.id, projectDeposits[0])

	// Check depositsByUserProject
	userProjectDeposits := state.DepositsByUserProject[testAddr][project.id]
	uassert.Equal(t, 1, len(userProjectDeposits))
	uassert.Equal(t, deposit.id, userProjectDeposits[0])
}

func TestMultipleDeposits(t *testing.T) {
	_, testAddr := setupTestDeposit(t)
	project := createTestProject(t)
	projects[project.id] = project

	state := &DepositState{
		Deposits:              make(map[string]Deposit),
		DepositsByProject:     depositsByProject,
		DepositsByUser:        depositsByUser,
		DepositsByUserProject: depositsByUserByProject,
	}

	// Create multiple deposits
	for i := 0; i < 3; i++ {
		info := ProjectTierInfo{
			Project:       project,
			Tier:          project.tiers[30],
			TierType:      "30",
			CurrentHeight: uint64(std.ChainHeight()),
			CurrentTime:   uint64(time.Now().Unix()),
		}

		testing.SetRealm(std.NewUserRealm(testAddr))
		deposit, _ := createDeposit(cross, info, 100)
		deposits[deposit.id] = deposit
		updateDepositIndices(deposit, state)

		testing.SkipHeights(100) // Skip some blocks between deposits
	}

	// Verify indices are correct
	userDeposits := state.DepositsByUser[testAddr]
	uassert.Equal(t, 3, len(userDeposits))

	projectDeposits := state.DepositsByProject[project.id]["30"]
	uassert.Equal(t, 3, len(projectDeposits))
}

func TestUpdateDepositIndices_EmptyState(t *testing.T) {
	_, testAddr := setupTestDeposit(t)
	deposit := Deposit{
		id:        "test_deposit",
		projectId: "test_project",
		tier:      "30",
		depositor: testAddr,
		amount:    100,
	}

	state := &DepositState{
		Deposits:              make(map[string]Deposit),
		DepositsByProject:     make(map[string]map[string][]string),
		DepositsByUser:        make(map[std.Address][]string),
		DepositsByUserProject: make(map[std.Address]map[string][]string),
	}

	updateDepositIndices(deposit, state)

	uassert.NotEqual(t, nil, state.DepositsByUser)
	uassert.NotEqual(t, nil, state.DepositsByProject)
	uassert.NotEqual(t, nil, state.DepositsByUserProject)

	uassert.Equal(t, 1, len(state.DepositsByUser[testAddr]))
	uassert.Equal(t, deposit.id, state.DepositsByUser[testAddr][0])
}

func TestIsProjectActive(t *testing.T) {
	project := Project{
		started: TimeInfo{height: 100},
		ended:   TimeInfo{height: 200},
	}

	tests := []struct {
		name           string
		height         uint64
		shouldBeActive bool
	}{
		{
			name:           "Before start",
			height:         50,
			shouldBeActive: false,
		},
		{
			name:           "At start",
			height:         100,
			shouldBeActive: true,
		},
		{
			name:           "During active period",
			height:         150,
			shouldBeActive: true,
		},
		{
			name:           "At end",
			height:         200,
			shouldBeActive: true,
		},
		{
			name:           "After end",
			height:         250,
			shouldBeActive: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			active := isProjectActive(project, tt.height)
			uassert.Equal(t, tt.shouldBeActive, active)
		})
	}
}

func TestIsTierActive(t *testing.T) {
	tier := Tier{
		ended: TimeInfo{height: 200},
	}

	tests := []struct {
		name           string
		height         uint64
		shouldBeActive bool
	}{
		{
			name:           "Before end",
			height:         150,
			shouldBeActive: true,
		},
		{
			name:           "At end",
			height:         200,
			shouldBeActive: true,
		},
		{
			name:           "After end",
			height:         250,
			shouldBeActive: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			active := isTierActive(tier, tt.height)
			uassert.Equal(t, tt.shouldBeActive, active)
		})
	}
}

// Mock for GRC20 Token and Ledger
type MockPrivateLedger struct {
	burnCalled bool
	burnAmount uint64
	burnFrom   std.Address
	mintCalled bool
	mintAmount uint64
	mintTo     std.Address
}

func (m *MockPrivateLedger) Burn(from std.Address, amount uint64) error {
	m.burnCalled = true
	m.burnFrom = from
	m.burnAmount = amount
	return nil
}

func (m *MockPrivateLedger) Mint(to std.Address, amount uint64) error {
	m.mintCalled = true
	m.mintTo = to
	m.mintAmount = amount
	return nil
}

type MockToken struct {
	balances map[string]uint64
}

func NewMockToken() *MockToken {
	return &MockToken{
		balances: make(map[string]uint64),
	}
}

func (m *MockToken) BalanceOf(addr std.Address) uint64 {
	return m.balances[addr.String()]
}

// Mock for emission
type MockEmission struct {
	mintCalled bool
}

func (m *MockEmission) MintAndDistributeGns() {
	m.mintCalled = true
}

type MockCommon struct {
	haltCheckCalled bool
}

func (m *MockCommon) IsHalted() {
	m.haltCheckCalled = true
}

func TestProcessCollectedDeposits_TransactionFail(t *testing.T) {
	t.Skip("fix this test")
	mockXGNS, _ := setupXGNSTest(t)
	project := createTestProject(t)
	projects[project.id] = project

	info := ProjectTierInfo{
		Project:       project,
		Tier:          project.tiers[30],
		TierType:      "30",
		CurrentHeight: uint64(std.ChainHeight()),
		CurrentTime:   uint64(time.Now().Unix()),
	}

	deposit, _ := createDeposit(cross, info, 1000)
	deposits[deposit.id] = deposit

	xgnsMint(t, mockXGNS, launchpadAddr, 500)

	testing.SetRealm(std.NewCodeRealm(consts.LAUNCHPAD_PATH))

	processCollectedDeposits(cross, []string{deposit.id}, "")
}

// func TestProcessCollectedDeposits_BalanceChanges(t *testing.T) {
// 	depositor := testutils.TestAddress("depositor")

// 	mockXGNS, _ := setupXGNSTest(t)
// 	project := createTestProject(t)
// 	projects[project.id] = project

// 	depositAmount := int64(1000)
// 	xgnsMint(t, mockXGNS, launchpadAddr, depositAmount)

// 	info := ProjectTierInfo{
// 		Project:       project,
// 		Tier:          project.tiers[30],
// 		TierType:      "30",
// 		CurrentHeight: uint64(std.ChainHeight()),
// 		CurrentTime:   uint64(time.Now().Unix()),
// 	}

// 	testing.SetRealm(std.NewUserRealm(depositor))
// 	deposit, _ := createDeposit(cross, info, uint64(depositAmount))
// 	deposits[deposit.id] = deposit

// 	testing.SkipHeights(int64(deposit.claimableHeight - uint64(std.ChainHeight()) + 1))

// 	processCollectedDeposits(cross, []string{deposit.id}, "")

// 	xgnsCheckTotalSupply(t, mockXGNS, 1000)
// }

// XXX: this test is not working as expected
func TestCollectDepositGnsByDepositId_ClaimableCheck(t *testing.T) {
	_, depositor := setupTestDeposit(t)

	tests := []struct {
		name             string
		inputDepositUser std.Address
		expectedHasPanic bool
		expectedPanicMsg string
		expectedHasAbort bool
		expectedAbortMsg string
	}{
		{
			name:             "collect deposit gns by deposit id failed by collect early",
			inputDepositUser: depositor,
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-LAUNCHPAD-007] invalid input data || user has no deposits in any project",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SkipHeights(10)
			project := createTestProject(t)
			projects[project.id] = project

			info := ProjectTierInfo{
				Project:       project,
				Tier:          project.tiers[30],
				TierType:      "30",
				CurrentHeight: uint64(std.ChainHeight()),
				CurrentTime:   uint64(time.Now().Unix()),
			}

			deposit, err := createDeposit(cross, info, 100)
			if err != nil {
				t.Fatalf("failed create deposit: %v", err)
			}

			updateDepositIndices(deposit, &DepositState{
				Deposits:              deposits,
				DepositsByProject:     depositsByProject,
				DepositsByUser:        depositsByUser,
				DepositsByUserProject: depositsByUserByProject,
			})

			testing.SetRealm(std.NewUserRealm(tt.inputDepositUser))
			if tt.expectedHasPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMsg, func() {
					CollectDepositGnsByDepositId(cross, deposit.id)
				})
			} else if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					CollectDepositGnsByDepositId(cross, deposit.id)
				})
			} else {
				CollectDepositGnsByDepositId(cross, deposit.id)
			}
		})
	}
}

// func TestCollectDepositGnsByDepositId_OtherOwner(t *testing.T) {
// 	_, userA := setupTestDeposit(t)
// 	userB := testutils.TestAddress("userB")

// 	project := createTestProject(t)
// 	projects[project.id] = project

// 	// create deposit (owner = userA)
// 	now := uint64(time.Now().Unix())
// 	height := uint64(std.ChainHeight())
// 	info := ProjectTierInfo{
// 		Project:       project,
// 		Tier:          project.tiers[30],
// 		TierType:      "30",
// 		CurrentHeight: height,
// 		CurrentTime:   now,
// 	}

// 	deposit, err := createDeposit(cross,info, 100)
// 	if err != nil {
// 		t.Fatalf("failed to create deposit: %v", err)
// 	}

// 	updateDepositIndices(deposit, &DepositState{
// 		Deposits:              deposits,
// 		DepositsByProject:     depositsByProject,
// 		DepositsByUser:        depositsByUser,
// 		DepositsByUserProject: depositsByUserByProject,
// 	})

// 	t.Run("UserB tries to collect userA's deposit => panic expected", func(t *testing.T) {
// 		testing.SetRealm(std.NewUserRealm(userB))
// 		defer func() {
// 			if r := recover(); r == nil {
// 				t.Errorf("expected panic but did not occur")
// 			} else {
// 				uassert.Equal(t, "[GNOSWAP-LAUNCHPAD-007] invalid input data || user has no deposits in any project", r.(string))
// 			}
// 		}()
// 		CollectDepositGnsByDepositId(deposit.id)
// 	})
// }

// XXX: this test is not set up project
// func TestCollectDepositGnsByDepositId_ExactClaimable(t *testing.T) {
// 	tests := []struct {
// 		name              string
// 		claimableHeight   uint64
// 		claimableTime     uint64
// 		expectedCollected uint64
// 		expectedHasPanic  bool
// 		expectedPanicMsg  string
// 		expectedHasAbort  bool
// 		expectedAbortMsg  string
// 	}{
// 		{
// 			name:              "collect deposit gns by deposit id success (claimableHeight)",
// 			claimableHeight:   10,
// 			claimableTime:     100,
// 			expectedCollected: 200,
// 			expectedHasAbort:  false,
// 			expectedAbortMsg:  "",
// 		},
// 	}

// 	for _, tt := range tests {
// 		t.Run(tt.name, func(t *testing.T) {
// 			testing.SkipHeights(10)
// 			_, depositor := setupTestDeposit(t)

// 			testing.SetRealm(std.NewUserRealm(depositor))
// 			testing.SetOriginCaller(depositor)

// 			project := createTestProject(t)
// 			projects[project.id] = project

// 			info := ProjectTierInfo{
// 				Project:       project,
// 				Tier:          project.tiers[30],
// 				TierType:      "30",
// 				CurrentHeight: uint64(std.ChainHeight()),
// 				CurrentTime:   uint64(time.Now().Unix()),
// 			}

// 			deposit, err := createDeposit(cross, info, uint64(200))
// 			if err != nil {
// 				t.Fatalf("failed create deposit: %v", err)
// 			}

// 			deposit.claimableHeight = tt.claimableHeight
// 			deposit.claimableTime = tt.claimableTime

// 			updateDepositIndices(deposit, &DepositState{
// 				Deposits:              deposits,
// 				DepositsByProject:     depositsByProject,
// 				DepositsByUser:        depositsByUser,
// 				DepositsByUserProject: depositsByUserByProject,
// 			})

// 			if tt.expectedHasPanic {
// 				uassert.PanicsWithMessage(t, tt.expectedPanicMsg, func() {
// 					CollectDepositGnsByDepositId(cross, deposit.id)
// 				})
// 			} else if tt.expectedHasAbort {
// 				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
// 					CollectDepositGnsByDepositId(cross, deposit.id)
// 				})
// 			} else {
// 				CollectDepositGnsByDepositId(cross, deposit.id)
// 			}

// 			// then
// 			testing.SkipHeights(10)

// 			deposit = deposits[deposit.id]
// 			uassert.Equal(t, tt.expectedCollected, deposit.amount)
// 		})
// 	}
// }

func TestProcessDepositCollection_ClaimableLogic(t *testing.T) {
	setupTestDeposit(t)
	project := createTestProject(t)
	projects[project.id] = project
	baseTime := uint64(time.Now().Unix())

	type testDeposit struct {
		amount         uint64
		claimableDelay uint64
		expectedResult bool
	}

	tests := []testDeposit{
		{100, 10, true},  // Claimable deposit (short waiting period)
		{200, 50, false}, // Not yet claimable deposit (long waiting period)
		{300, 5, true},   // Claimable deposit (very short waiting period)
	}

	depositIds := []string{}
	totalClaimableAmount := uint64(0)

	// create deposits with different heights and times
	for i, tt := range tests {
		// avoid creating deposits at the same height
		// this may cause the test to duplicate the same id error
		testing.SkipHeights(1)
		currentHeight := uint64(std.ChainHeight())
		currentTime := baseTime + uint64(i*100)

		info := ProjectTierInfo{
			Project:       project,
			Tier:          project.tiers[30],
			TierType:      "30",
			CurrentHeight: currentHeight,
			CurrentTime:   currentTime,
		}

		deposit, err := createDeposit(cross, info, tt.amount)
		if err != nil {
			t.Fatalf("failed to create deposit: %v", err)
		}

		// Set claimable height
		deposit.claimableHeight = currentHeight + tt.claimableDelay
		deposits[deposit.id] = deposit
		depositIds = append(depositIds, deposit.id)

		if tt.expectedResult {
			totalClaimableAmount += tt.amount
		}

		// Update deposit indices
		updateDepositIndices(deposit, &DepositState{
			Deposits:              make(map[string]Deposit),
			DepositsByProject:     depositsByProject,
			DepositsByUser:        depositsByUser,
			DepositsByUserProject: depositsByUserByProject,
		})
	}

	// Skip blocks until reaching claimable point
	testing.SkipHeights(15)

	// Execute processDepositCollection
	amount, err := processDepositCollection(cross, depositIds, "")
	if err != nil {
		t.Fatalf("processDepositCollection failed: %v", err)
	}

	uassert.Equal(t, totalClaimableAmount, amount, "collected amount should match expected claimable amount")

	for i, tt := range tests {
		deposit := deposits[depositIds[i]]
		if tt.expectedResult {
			// Verify claimable deposits
			uassert.NotEqual(t, uint64(0), deposit.depositCollectHeight,
				"claimable deposit should have been collected")
			uassert.Equal(t, tt.amount, deposit.amount,
				"collected amount should match deposit amount")
		} else {
			// Verify non-claimable deposits
			uassert.Equal(t, uint64(0), deposit.depositCollectHeight,
				"non-claimable deposit should not have been collected")
		}
	}
}

func TestProcessDepositCollection_ProjectEndCondition(t *testing.T) {
	setupTestDeposit(t)
	project := createTestProject(t)

	// Set project end height to future
	currentHeight := uint64(std.ChainHeight())
	project.ended.height = currentHeight + 100
	projects[project.id] = project

	// Create deposit
	info := ProjectTierInfo{
		Project:       project,
		Tier:          project.tiers[30],
		TierType:      "30",
		CurrentHeight: currentHeight,
		CurrentTime:   uint64(time.Now().Unix()),
	}

	deposit, err := createDeposit(cross, info, 100)
	if err != nil {
		t.Fatalf("failed to create deposit: %v", err)
	}

	// Set claimable height to current height
	deposit.claimableHeight = currentHeight
	deposits[deposit.id] = deposit

	updateDepositIndices(deposit, &DepositState{
		Deposits:              make(map[string]Deposit),
		DepositsByProject:     depositsByProject,
		DepositsByUser:        depositsByUser,
		DepositsByUserProject: depositsByUserByProject,
	})

	// Test if deposit can be claimed before project ends
	amount, err := processDepositCollection(cross, []string{deposit.id}, "")
	if err != nil {
		t.Fatalf("processDepositCollection failed: %v", err)
	}

	uassert.Equal(t, uint64(100), amount,
		"should be able to collect deposit even before project end")
	uassert.NotEqual(t, uint64(0), deposits[deposit.id].depositCollectHeight,
		"deposit should have been collected")
}
