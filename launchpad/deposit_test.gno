package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gns"
)

// Mock data structs
type MockTokenTeller struct {
	balance uint64
	addr    std.Address
}

func (m *MockTokenTeller) TransferFrom(from std.Address, to std.Address, amount uint64) {
	m.balance = amount
	m.addr = to
}

func (m *MockTokenTeller) BalanceOf(addr std.Address) uint64 {
	return m.balance
}

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
	height := uint64(std.GetHeight())

	tiers := make(map[uint64]Tier)
	tiersRatios := make(map[uint64]uint64)

	tiers[30] = Tier{
		id:                  ufmt.Sprintf("test/token:%d:30", height),
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
	}
	tiersRatios[30] = 30

	tiers[90] = Tier{
		id:                  ufmt.Sprintf("test/token:%d:90", height),
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
	}
	tiersRatios[90] = 30

	tiers[180] = Tier{
		id:                  ufmt.Sprintf("test/token:%d:180", height),
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
	}
	tiersRatios[180] = 40

	return Project{
		id:            ufmt.Sprintf("test/token:%d", height),
		name:          "Test Project",
		tokenPath:     "test/token",
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
	mockTeller, _ := setupTestDeposit(t)
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
	_, testAddr := setupTestDeposit(t)
	project := createTestProject(t)
	now := uint64(time.Now().Unix())
	height := uint64(std.GetHeight())

	info := ProjectTierInfo{
		Project:     project,
		Tier:        project.tiers[30],
		TierStr:     "30",
		Height:      height,
		CurrentTime: now,
	}

	deposit, err := createDeposit(info, 100)
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
				TierStr:     "30",
				Height:      500,
				CurrentTime: 500000,
			},
			wantHeight: 600,    // Height(500) + collectWaitDuration(100)
			wantTime:   759200, // CurrentTime(500000) + TIMESTAMP_3DAYS
		},
		{
			name: "Tier 90 - Exceeds End Height/Time",
			info: ProjectTierInfo{
				Project: Project{},
				Tier: Tier{
					collectWaitDuration: 200,
					ended: TimeInfo{
						height: 550,
						time:   600000,
					},
				},
				TierStr:     "90",
				Height:      400,
				CurrentTime: 400000,
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
				TierStr:     "180",
				Height:      100,
				CurrentTime: 100000,
			},
			wantHeight: 400,     // Height(100) + collectWaitDuration(300)
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
	mockTeller, testAddr := setupTestDeposit(t)
	project := createTestProject(t)
	projects[project.id] = project
	currentTime := uint64(time.Now().Unix())
	height := uint64(std.GetHeight())

	// Create test deposit
	info := ProjectTierInfo{
		Project:     project,
		Tier:        project.tiers[30],
		TierStr:     "30",
		Height:      height,
		CurrentTime: currentTime,
	}

	deposit, err := createDeposit(info, 100)
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
		std.TestSetRealm(std.NewUserRealm(testAddr))
		amount, err := processDepositCollection([]string{deposit.id}, "")
		uassert.Equal(t, uint64(0), amount)
	})

	t.Run("Can collect after claimable height", func(t *testing.T) {
		// Skip to after claimable height
		std.TestSkipHeights(int64(deposit.claimableHeight - height + 1))

		std.TestSetRealm(std.NewUserRealm(testAddr))
		amount, err := processDepositCollection([]string{deposit.id}, "")
		uassert.NoError(t, err)
		uassert.Equal(t, uint64(100), amount)
	})
}

func TestDepositGns(t *testing.T) {
	mockTeller, testAddr := setupTestDeposit(t)
	project := createTestProject(t)
	projects[project.id] = project

	t.Run("Fail with insufficient balance", func(t *testing.T) {
		std.TestSetRealm(std.NewUserRealm(testAddr))

		defer func() {
			r := recover()
			if r != nil {
				t.Logf("Recovered from panic: %v", r)
			}
		}()

		DepositGns(project.id+":30", 1000)
	})

	t.Run("Success with sufficient balance", func(t *testing.T) {
		// transfer enough gns
		std.TestSetRealm(adminRealm)
		gns.Transfer(common.AddrToUser(testAddr), 1000)

		std.TestSetRealm(std.NewUserRealm(testAddr))
		gns.Approve(common.AddrToUser(consts.LAUNCHPAD_ADDR), 1000)

		depositId := DepositGns(project.id+":30", 1000)
		deposit := deposits[depositId]

		uassert.Equal(t, deposit.amount, uint64(1000))
		uassert.Equal(t, deposit.depositor, testAddr)
	})
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
	mockTeller, testAddr := setupTestDeposit(t)
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
			Project:     project,
			Tier:        project.tiers[30],
			TierStr:     "30",
			Height:      uint64(std.GetHeight()),
			CurrentTime: uint64(time.Now().Unix()),
		}

		deposit, _ := createDeposit(info, 100)
		deposits[deposit.id] = deposit
		updateDepositIndices(deposit, state)

		std.TestSkipHeights(100) // Skip some blocks between deposits
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
	mockXGNS, _ := setupXGNSTest(t)
	project := createTestProject(t)
	projects[project.id] = project

	info := ProjectTierInfo{
		Project:     project,
		Tier:        project.tiers[30],
		TierStr:     "30",
		Height:      uint64(std.GetHeight()),
		CurrentTime: uint64(time.Now().Unix()),
	}

	deposit, _ := createDeposit(info, 1000)
	deposits[deposit.id] = deposit

	xgnsMint(t, mockXGNS, a2u(consts.LAUNCHPAD_ADDR), 500)

	std.TestSetRealm(std.NewCodeRealm(consts.LAUNCHPAD_PATH))

	processCollectedDeposits([]string{deposit.id}, "")
}

func TestProcessCollectedDeposits_BalanceChanges(t *testing.T) {
	mockXGNS, testAddr := setupXGNSTest(t)
	project := createTestProject(t)
	projects[project.id] = project

	depositAmount := uint64(1000)
	xgnsMint(t, mockXGNS, a2u(consts.LAUNCHPAD_ADDR), depositAmount)

	info := ProjectTierInfo{
		Project:     project,
		Tier:        project.tiers[30],
		TierStr:     "30",
		Height:      uint64(std.GetHeight()),
		CurrentTime: uint64(time.Now().Unix()),
	}

	deposit, _ := createDeposit(info, depositAmount)
	deposits[deposit.id] = deposit

	std.TestSkipHeights(int64(deposit.claimableHeight - uint64(std.GetHeight()) + 1))

	std.TestSetRealm(std.NewCodeRealm(consts.LAUNCHPAD_PATH))
	amount := processCollectedDeposits([]string{deposit.id}, "")

	xgnsCheckTotalSupply(t, mockXGNS, 1000)
}
