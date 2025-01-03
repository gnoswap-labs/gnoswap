package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
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
	
	// 기본 tier 맵 생성
	tiers := make(map[uint64]Tier)
	tiersRatios := make(map[uint64]uint64)
	
	// 30일 tier
	tiers[30] = Tier{
		// id:                  "test/token:" + strconv.Itoa(height) + ":30",
		id: ufmt.Sprintf("test/token:%d:30", height),
		collectWaitDuration: TIMESTAMP_3DAYS * 1000 / 1000,
		tierAmount:         300,
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

	// 90일 tier
	tiers[90] = Tier{
		id: ufmt.Sprintf("test/token:%d:90", height),
		collectWaitDuration: TIMESTAMP_7DAYS * 1000 / 1000,
		tierAmount:         300,
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

	// 180일 tier
	tiers[180] = Tier{
		id: ufmt.Sprintf("test/token:%d:180", height),
		collectWaitDuration: TIMESTAMP_14DAYS * 1000 / 1000,
		tierAmount:         400,
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
			totalDeposit: 0,
			actualDeposit: 0,
			totalParticipant: 0,
			actualParticipant: 0,
			totalCollected: 0,
		},
		refund: RefundInfo{
			amount: 0,
			height: 0,
			time: 0,
		},
	}
}

// Unit Tests
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
		name           string
		info          ProjectTierInfo
		wantHeight    uint64
		wantTime      uint64
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
			wantHeight: 600,      // Height(500) + collectWaitDuration(100)
			wantTime:   759200,   // CurrentTime(500000) + TIMESTAMP_3DAYS
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
			wantHeight: 550,      // min(400+200, endHeight(550))
			wantTime:   600000,   // min(400000+TIMESTAMP_7DAYS, endTime(600000))
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
			wantHeight: 400,      // Height(100) + collectWaitDuration(300)
			wantTime:   1309600,  // CurrentTime(100000) + TIMESTAMP_14DAYS
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