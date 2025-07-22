package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gov/xgns"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestCollectDepositGns(t *testing.T) {
	userAddr := testutils.TestAddress("user")
	otherAddr := testutils.TestAddress("other")

	tests := []struct {
		name                 string
		depositID            string
		callerAddress        std.Address
		expectedHasAbort     bool
		expectedAbortMessage string
		expectedAmount       int64
	}{
		{
			name:             "collect deposit gns successfully",
			depositID:        "1",
			callerAddress:    userAddr,
			expectedHasAbort: false,
			expectedAmount:   1000000000,
		},
		{
			name:                 "collect deposit gns failed by invalid deposit id",
			depositID:            "invalid_deposit",
			callerAddress:        userAddr,
			expectedHasAbort:     true,
			expectedAbortMessage: "[GNOSWAP-LAUNCHPAD-020] not exist deposit || (invalid_deposit)",
		},
		{
			name:                 "collect deposit gns failed by invalid owner",
			depositID:            "1",
			callerAddress:        otherAddr,
			expectedHasAbort:     true,
			expectedAbortMessage: "[GNOSWAP-LAUNCHPAD-026] invalid owner || (g1da6xsetjta047h6lta047h6lta047h6ltrh8mk)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadWithdrawTest(t)
			testing.SetOriginCaller(tt.callerAddress)

			collectDepositFn := func() {
				CollectDepositGns(cross, tt.depositID)
			}

			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMessage, collectDepositFn)
				return
			}

			amount, err := CollectDepositGns(cross, tt.depositID)
			uassert.NoError(t, err)
			uassert.Equal(t, tt.expectedAmount, amount)
		})
	}
}

func TestWithdrawDeposit(t *testing.T) {
	const currentDepositID = "1"

	tests := []struct {
		name                 string
		depositID            string
		expectedHasError     bool
		expectedErrorMessage string
		expectedAmount       int64
	}{
		{
			name:             "withdraw deposit successfully",
			depositID:        currentDepositID,
			expectedHasError: false,
			expectedAmount:   1000000000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initLaunchpadWithdrawTest(t)

			deposit, _ := getDeposit(tt.depositID)

			_, amount, err := withdrawDeposit(deposit, std.ChainHeight())

			if tt.expectedHasError {
				uassert.Equal(t, tt.expectedErrorMessage, err.Error())
				return
			}

			uassert.NoError(t, err)
			uassert.Equal(t, tt.expectedAmount, amount)
		})
	}
}

func initLaunchpadWithdrawTest(t *testing.T) {
	testing.SetHeight(123)

	// Initialize test environment
	deposits = avl.NewTree()
	depositCounter = NewCounter()
	projects = avl.NewTree()
	projectTierRewardManagers = avl.NewTree()

	// Setup test project
	currentTime := time.Now().Unix()
	currentHeight := std.ChainHeight()

	// Setup test project
	project, _ := createProject(
		&createProjectParams{
			name:               "Test Project",
			tokenPath:          "gno.land/r/onbloc/obl",
			depositAmount:      1000000,
			tier30Ratio:        30,
			tier90Ratio:        30,
			tier180Ratio:       40,
			averageBlockTimeMs: 2000,
			recipient:          testutils.TestAddress("project"), // TODO: change to real address
			startTime:          currentTime + 10,
			currentTime:        currentTime,
			currentHeight:      currentHeight,
		},
	)
	projects.Set(project.ID(), project)

	testing.SkipHeights(10)

	depositAmount := int64(1000000000)

	depositor := testutils.TestAddress("user")
	testing.SetOriginCaller(depositor)
	depositGns(project.ID(), 30, depositAmount, depositor)

	govStakerAddr, _ := access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm := std.NewUserRealm(govStakerAddr)
	testing.SetRealm(govStakerRealm)

	launchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	xgns.Mint(cross, launchpadAddr, depositAmount)

	projectTier, _ := project.getTier(30)
	testing.SetHeight(projectTier.EndHeight() + 1)
}
