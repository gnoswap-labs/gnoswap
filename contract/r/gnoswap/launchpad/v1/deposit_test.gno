package v1

import (
	"math"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/launchpad"
)

func TestDeposit_ID(t *testing.T) {
	tests := []struct {
		name     string
		deposit  *launchpad.Deposit
		expected string
	}{
		{
			name: "get deposit id successfully",
			deposit: newDeposit(
				"test_deposit_id",
				"test_project",
				30,
				testutils.TestAddress("test"),
				1000,
				100,
				time.Now().Unix(),
				time.Now().Add(time.Hour*24*30).Unix(),
			),
			expected: "test_deposit_id",
		},
		{
			name: "get empty deposit id successfully",
			deposit: newDeposit(
				"",
				"test_project",
				30,
				testutils.TestAddress("test"),
				1000,
				100,
				time.Now().Unix(),
				time.Now().Add(time.Hour*24*30).Unix(),
			),
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
		deposit  *launchpad.Deposit
		expected string
	}{
		{
			name: "get project id successfully",
			deposit: newDeposit(
				"test_deposit_id",
				"test_project_id",
				30,
				testutils.TestAddress("test"),
				1000,
				100,
				time.Now().Unix(),
				time.Now().Add(time.Hour*24*30).Unix(),
			),
			expected: "test_project_id",
		},
		{
			name: "get empty project id successfully",
			deposit: newDeposit(
				"test_deposit_id",
				"",
				30,
				testutils.TestAddress("test"),
				1000,
				100,
				time.Now().Unix(),
				time.Now().Add(time.Hour*24*30).Unix(),
			),
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
		deposit  *launchpad.Deposit
		expected string
	}{
		{
			name: "get project tier id successfully",
			deposit: newDeposit(
				"test_deposit_id",
				"test_project",
				30,
				testutils.TestAddress("test"),
				1000,
				100,
				time.Now().Unix(),
				time.Now().Add(time.Hour*24*30).Unix(),
			),
			expected: "test_project:30",
		},
		{
			name: "get project tier id with empty project id",
			deposit: newDeposit(
				"test_deposit_id",
				"",
				30,
				testutils.TestAddress("test"),
				1000,
				100,
				time.Now().Unix(),
				time.Now().Add(time.Hour*24*30).Unix(),
			),
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
		deposit  *launchpad.Deposit
		address  address
		expected bool
	}{
		{
			name: "check owner successfully - true case",
			deposit: newDeposit(
				"test_deposit_id",
				"test_project",
				30,
				testAddr,
				1000,
				100,
				time.Now().Unix(),
				time.Now().Add(time.Hour*24*30).Unix(),
			),
			address:  testAddr,
			expected: true,
		},
		{
			name: "check owner successfully - false case",
			deposit: newDeposit(
				"test_deposit_id",
				"test_project",
				30,
				testAddr,
				1000,
				100,
				time.Now().Unix(),
				time.Now().Add(time.Hour*24*30).Unix(),
			),
			address:  otherAddr,
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.expected, tt.deposit.IsDepositor(tt.address))
		})
	}
}

func TestDeposit_IsEnded(t *testing.T) {
	testAddr := testutils.TestAddress("test")
	tests := []struct {
		name        string
		deposit     *launchpad.Deposit
		currentTime int64
		expected    bool
	}{
		{
			name: "check is ended successfully - true case",
			deposit: newDeposit(
				"test_deposit_id",
				"test_project",
				30,
				testAddr,
				1000,
				100,
				0,
				100,
			),
			currentTime: 101,
			expected:    true,
		},
		{
			name: "check is ended successfully - false case",
			deposit: newDeposit(
				"test_deposit_id",
				"test_project",
				30,
				testAddr,
				1000,
				100,
				0,
				100,
			),
			currentTime: 99,
			expected:    false,
		},
		{
			name: "check is ended successfully - equal height case",
			deposit: newDeposit(
				"test_deposit_id",
				"test_project",
				30,
				testAddr,
				1000,
				100,
				0,
				100,
			),
			currentTime: 100,
			expected:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.expected, tt.deposit.IsEnded(tt.currentTime))
		})
	}
}

func TestDeposit_IsWithdrawn(t *testing.T) {
	tests := []struct {
		name             string
		withdrawnTime    int64
		withdrawnHeight  int64
		expectedWithdawn bool
	}{
		{
			name:             "not withdrawn when both time and height are zero",
			withdrawnTime:    0,
			withdrawnHeight:  0,
			expectedWithdawn: false,
		},
		{
			name:             "not withdrawn when only time is set",
			withdrawnTime:    100,
			withdrawnHeight:  0,
			expectedWithdawn: false,
		},
		{
			name:             "not withdrawn when only height is set",
			withdrawnTime:    0,
			withdrawnHeight:  100,
			expectedWithdawn: false,
		},
		{
			name:             "withdrawn when both time and height are set",
			withdrawnTime:    100,
			withdrawnHeight:  100,
			expectedWithdawn: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			deposit := newDeposit(
				"test_deposit_id",
				"test_project",
				30,
				testutils.TestAddress("test"),
				1000,
				100,
				time.Now().Unix(),
				time.Now().Add(time.Hour*24*30).Unix(),
			)
			deposit.SetWithdrawn(tt.withdrawnHeight, tt.withdrawnTime)
			uassert.Equal(t, tt.expectedWithdawn, deposit.IsWithdrawn())
		})
	}
}

func TestDeposit_WithdrawnHeight(t *testing.T) {
	tests := []struct {
		name            string
		withdrawnHeight int64
		expected        int64
	}{
		{
			name:            "zero withdrawn height",
			withdrawnHeight: 0,
			expected:        0,
		},
		{
			name:            "positive withdrawn height",
			withdrawnHeight: 12345,
			expected:        12345,
		},
		{
			name:            "max int64 withdrawn height",
			withdrawnHeight: math.MaxInt64,
			expected:        math.MaxInt64,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			deposit := &launchpad.Deposit{}
			deposit.SetWithdrawnHeight(tt.withdrawnHeight)
			uassert.Equal(t, tt.expected, deposit.WithdrawnHeight())
		})
	}
}

func TestDeposit_Withdraw(t *testing.T) {
	testAddr := testutils.TestAddress("test")
	tests := []struct {
		name              string
		depositAmount     int64
		currentTime       int64
		expectedAmount    int64
		expectedWithdrawn bool
		expectedRemaining int64
	}{
		{
			name:              "withdraw successfully",
			depositAmount:     1000,
			currentTime:       100,
			expectedAmount:    1000,
			expectedWithdrawn: true,
			expectedRemaining: 0,
		},
		{
			name:              "withdraw with zero amount",
			depositAmount:     0,
			currentTime:       100,
			expectedAmount:    0,
			expectedWithdrawn: true,
			expectedRemaining: 0,
		},
		{
			name:              "withdraw with max int64 amount",
			depositAmount:     9223372036854775807, // MaxInt64
			currentTime:       100,
			expectedAmount:    9223372036854775807,
			expectedWithdrawn: true,
			expectedRemaining: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			deposit := newDeposit(
				"test_deposit",
				"test_project",
				30,
				testAddr,
				tt.depositAmount,
				100,
				time.Now().Unix(),
				time.Now().Add(time.Hour*24*30).Unix(),
			)
			currentHeight := int64(123)
			amount := withdrawDeposit(deposit, currentHeight, tt.currentTime)
			uassert.Equal(t, tt.expectedAmount, amount)
			uassert.Equal(t, tt.currentTime, deposit.WithdrawnTime())
			uassert.Equal(t, currentHeight, deposit.WithdrawnHeight())
			uassert.Equal(t, tt.expectedRemaining, deposit.DepositAmount())
			uassert.Equal(t, tt.expectedWithdrawn, deposit.IsWithdrawn())
		})
	}
}

func TestDeposit_NewDeposit(t *testing.T) {
	testAddr := testutils.TestAddress("test")
	projectID := "gno.land/r/onbloc/obl:123"

	tests := []struct {
		name               string
		depositID          string
		projectID          string
		tier               int64
		depositor          address
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
		{
			name:               "create deposit with zero values",
			depositID:          "0",
			projectID:          projectID,
			tier:               0,
			depositor:          testAddr,
			depositAmount:      0,
			createdBlockTime:   0,
			createdBlockHeight: 0,
			endBlockTime:       0,
			endBlockHeight:     0,
			expectedID:         "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			deposit := newDeposit(
				tt.depositID,
				tt.projectID,
				tt.tier,
				tt.depositor,
				tt.depositAmount,
				tt.createdBlockHeight,
				tt.createdBlockTime,
				tt.endBlockTime,
			)

			uassert.Equal(t, tt.expectedID, deposit.ID())
			uassert.Equal(t, tt.projectID, deposit.ProjectID())
			uassert.Equal(t, tt.tier, deposit.Tier())
			uassert.Equal(t, tt.depositor, deposit.Depositor())
			uassert.Equal(t, tt.depositAmount, deposit.DepositAmount())
			uassert.Equal(t, tt.createdBlockTime, deposit.CreatedAt())
			uassert.Equal(t, tt.createdBlockHeight, deposit.CreatedHeight())
			uassert.Equal(t, tt.endBlockTime, deposit.EndTime())
			uassert.Equal(t, int64(0), deposit.WithdrawnHeight())
		})
	}
}
