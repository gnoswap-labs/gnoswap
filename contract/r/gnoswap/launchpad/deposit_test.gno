package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
)

func TestDeposit_ID(t *testing.T) {
	tests := []struct {
		name     string
		deposit  *Deposit
		expected string
	}{
		{
			name: "get deposit id successfully",
			deposit: &Deposit{
				id: "test_deposit_id",
			},
			expected: "test_deposit_id",
		},
		{
			name: "get empty deposit id successfully",
			deposit: &Deposit{
				id: "",
			},
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.expected, tt.deposit.ID())
		})
	}
}

func TestDeposit_ProjectID(t *testing.T) {
	tests := []struct {
		name     string
		deposit  *Deposit
		expected string
	}{
		{
			name: "get project id successfully",
			deposit: &Deposit{
				projectID: "test_project_id",
			},
			expected: "test_project_id",
		},
		{
			name: "get empty project id successfully",
			deposit: &Deposit{
				projectID: "",
			},
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.expected, tt.deposit.ProjectID())
		})
	}
}

func TestDeposit_ProjectTierID(t *testing.T) {
	tests := []struct {
		name     string
		deposit  *Deposit
		expected string
	}{
		{
			name: "get project tier id successfully",
			deposit: &Deposit{
				projectID: "test_project",
				tier:      30,
			},
			expected: "test_project:30",
		},
		{
			name: "get project tier id with empty project id",
			deposit: &Deposit{
				projectID: "",
				tier:      30,
			},
			expected: ":30",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.expected, tt.deposit.ProjectTierID())
		})
	}
}

func TestDeposit_IsOwner(t *testing.T) {
	testAddr := testutils.TestAddress("test")
	otherAddr := testutils.TestAddress("other")

	tests := []struct {
		name     string
		deposit  *Deposit
		address  std.Address
		expected bool
	}{
		{
			name: "check owner successfully - true case",
			deposit: &Deposit{
				depositor: testAddr,
			},
			address:  testAddr,
			expected: true,
		},
		{
			name: "check owner successfully - false case",
			deposit: &Deposit{
				depositor: testAddr,
			},
			address:  otherAddr,
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.expected, tt.deposit.IsOwner(tt.address))
		})
	}
}

func TestDeposit_IsEnded(t *testing.T) {
	tests := []struct {
		name          string
		deposit       *Deposit
		currentHeight int64
		expected      bool
	}{
		{
			name: "check is ended successfully - true case",
			deposit: &Deposit{
				endBlockTimeInfo: newBlockTimeInfo(1000, 100),
			},
			currentHeight: 101,
			expected:      true,
		},
		{
			name: "check is ended successfully - false case",
			deposit: &Deposit{
				endBlockTimeInfo: newBlockTimeInfo(1000, 100),
			},
			currentHeight: 99,
			expected:      false,
		},
		{
			name: "check is ended successfully - equal height case",
			deposit: &Deposit{
				endBlockTimeInfo: newBlockTimeInfo(1000, 100),
			},
			currentHeight: 100,
			expected:      false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.expected, tt.deposit.IsEnded(tt.currentHeight))
		})
	}
}

func TestDeposit_Withdraw(t *testing.T) {
	tests := []struct {
		name              string
		deposit           *Deposit
		currentHeight     int64
		expectedAmount    int64
		expectedWithdrawn bool
		expectedRemaining int64
	}{
		{
			name: "withdraw successfully",
			deposit: &Deposit{
				depositAmount:   1000,
				withdrawnHeight: 0,
			},
			currentHeight:     100,
			expectedAmount:    1000,
			expectedWithdrawn: true,
			expectedRemaining: 0,
		},
		{
			name: "withdraw with zero amount",
			deposit: &Deposit{
				depositAmount:   0,
				withdrawnHeight: 0,
			},
			currentHeight:     100,
			expectedAmount:    0,
			expectedWithdrawn: true,
			expectedRemaining: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			amount := tt.deposit.withdraw(tt.currentHeight)
			uassert.Equal(t, tt.expectedAmount, amount)
			uassert.Equal(t, tt.currentHeight, tt.deposit.withdrawnHeight)
			uassert.Equal(t, tt.expectedRemaining, tt.deposit.depositAmount)
			uassert.Equal(t, tt.expectedWithdrawn, tt.deposit.IsWithdrawn())
		})
	}
}

func TestNewDeposit(t *testing.T) {
	testAddr := testutils.TestAddress("test")
	projectID := "gno.land/r/onbloc/obl:123"

	tests := []struct {
		name               string
		depositID          string
		projectID          string
		tier               int64
		depositor          std.Address
		depositAmount      int64
		createdBlockTime   int64
		createdBlockHeight int64
		endBlockTime       int64
		endBlockHeight     int64
		expectedID         string
	}{
		{
			name:               "create new deposit successfully",
			depositID:          "123",
			projectID:          projectID,
			tier:               30,
			depositor:          testAddr,
			depositAmount:      1000,
			createdBlockTime:   900,
			createdBlockHeight: 90,
			endBlockTime:       1000,
			endBlockHeight:     100,
			expectedID:         "123",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			createdBlockTimeInfo := newBlockTimeInfo(tt.createdBlockTime, tt.createdBlockHeight)
			endBlockTimeInfo := newBlockTimeInfo(tt.endBlockTime, tt.endBlockHeight)

			deposit := NewDeposit(
				tt.depositID,
				tt.projectID,
				tt.tier,
				tt.depositor,
				tt.depositAmount,
				createdBlockTimeInfo,
				endBlockTimeInfo,
			)

			uassert.Equal(t, tt.expectedID, deposit.ID())
			uassert.Equal(t, tt.projectID, deposit.ProjectID())
			uassert.Equal(t, tt.tier, deposit.Tier())
			uassert.Equal(t, tt.depositor, deposit.Depositor())
			uassert.Equal(t, tt.depositAmount, deposit.DepositAmount())
			uassert.Equal(t, tt.createdBlockTime, deposit.DepositTime())
			uassert.Equal(t, tt.createdBlockHeight, deposit.DepositHeight())
			uassert.Equal(t, tt.endBlockTime, deposit.EndTime())
			uassert.Equal(t, tt.endBlockHeight, deposit.EndHeight())
			uassert.Equal(t, int64(0), deposit.withdrawnHeight)
		})
	}
}

// TestDepositIndividualUnlockTime verifies that each deposit has its own unlock time
// based on when it was created, not when the project tier ends
func TestDepositIndividualUnlockTime(t *testing.T) {
	deposits = avl.NewTree()
	projects = avl.NewTree()
	projectTierRewardManagers = avl.NewTree()

	currentTime := time.Now().Unix()
	currentHeight := int64(100)
	testing.SetHeight(currentHeight)

	project, _ := createProject(
		&createProjectParams{
			name:               "Test Individual Unlock",
			tokenPath:          "gno.land/r/onbloc/obl",
			depositAmount:      10000000,
			tier30Ratio:        100,
			tier90Ratio:        0,
			tier180Ratio:       0,
			averageBlockTimeMs: 2000, // 2 seconds per block
			recipient:          testutils.TestAddress("project"),
			startTime:          currentTime,
			currentTime:        currentTime,
			currentHeight:      currentHeight,
		},
	)
	projects.Set(project.ID(), project)

	// User 1 deposits at the beginning
	user1 := testutils.TestAddress("user1")
	testing.SetOriginCaller(user1)
	deposit1, _, _, _, _ := depositGns(project.ID(), 30, 1000000, user1)

	// User 2 deposits 10 days later
	tenDaysInBlocks := int64(10 * 24 * 60 * 60 / 2) // 432,000 blocks
	testing.SetHeight(currentHeight + tenDaysInBlocks)

	user2 := testutils.TestAddress("user2")
	testing.SetOriginCaller(user2)
	deposit2, _, _, _, _ := depositGns(project.ID(), 30, 1000000, user2)

	// IMPORTANT: Deposits should have different unlock times
	// User2's deposit should unlock 10 days after User1's
	expectedDifference := tenDaysInBlocks
	actualDifference := deposit2.EndHeight() - deposit1.EndHeight()

	t.Logf("User1 deposit unlock height: %d", deposit1.EndHeight())
	t.Logf("User2 deposit unlock height: %d", deposit2.EndHeight())
	t.Logf("Difference: %d blocks (expected: %d blocks)", actualDifference, expectedDifference)

	// Verify deposits have individual unlock times
	uassert.Equal(t, expectedDifference, actualDifference,
		"Deposits should have individual unlock times based on creation time")

	// Verify User1 can withdraw after 30 days from THEIR deposit
	thirtyDaysInBlocks := int64(30 * 24 * 60 * 60 / 2)
	user1UnlockHeight := deposit1.DepositHeight() + thirtyDaysInBlocks + 1
	testing.SetHeight(user1UnlockHeight)

	// User1 should be able to withdraw
	_, amount1, err1 := withdrawDeposit(deposit1, user1UnlockHeight)
	uassert.NoError(t, err1, "User1 should be able to withdraw 30 days after their deposit")
	uassert.Equal(t, int64(1000000), amount1)

	// User2 should NOT be able to withdraw yet (only 20 days passed for them)
	_, _, err2 := withdrawDeposit(deposit2, user1UnlockHeight)
	uassert.Error(t, err2, "User2 should not be able to withdraw after only 20 days")

	// Move to User2's unlock time and verify they can now withdraw
	user2UnlockHeight := deposit2.DepositHeight() + thirtyDaysInBlocks + 1
	testing.SetHeight(user2UnlockHeight)

	_, amount2, err3 := withdrawDeposit(deposit2, user2UnlockHeight)
	uassert.NoError(t, err3, "User2 should be able to withdraw 30 days after their deposit")
	uassert.Equal(t, int64(1000000), amount2)
}
