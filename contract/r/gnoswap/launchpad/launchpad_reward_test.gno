package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
)

func TestConditionCheckedAtAllStages(t *testing.T) {
	initLaunchpadProjectTest(t)
	initLaunchpadProjectTestAvgBlockTime(t, 2000)

	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	launchpadAddr, _ := access.GetAddress(access.ROLE_LAUNCHPAD)
	user := testutils.TestAddress("user")

	testing.SetOriginCaller(adminAddr)
	obl.Approve(cross, launchpadAddr, 1_000_000_000)

	currentTime := time.Now().Unix()
	currentHeight := std.ChainHeight()

	project, err := createProject(
		&createProjectParams{
			name:               "Test Project",
			tokenPath:          "gno.land/r/onbloc/obl",
			depositAmount:      1_000_000_000,
			conditionTokens:    "gno.land/r/onbloc/foo",
			conditionAmounts:   "1000",
			tier30Ratio:        100,
			tier90Ratio:        0,
			tier180Ratio:       0,
			averageBlockTimeMs: 2000,
			recipient:          testutils.TestAddress("project"),
			startTime:          currentTime + 3600,
			currentTime:        currentTime,
			currentHeight:      currentHeight,
		},
	)
	uassert.NoError(t, err)
	projects.Set(project.ID(), project)

	testing.SkipHeights(1800)

	// Give user tokens to meet condition
	testing.SetOriginCaller(user)
	TokenFaucet(t, fooPath, user)
	TokenFaucet(t, gnsPath, user)
	gns.Approve(cross, launchpadAddr, 1_000_000)

	// verify user meets condition
	fooBalance := foo.BalanceOf(user)
	uassert.True(t, fooBalance >= 1000, "User should have enough FOO tokens")

	// user deposits successfully
	deposit, _, _, _, err := depositGns(project.ID(), 30, 1_000_000, user)
	uassert.NoError(t, err, "Deposit should succeed with condition met")
	deposits.Set(deposit.ID(), deposit)

	// user gets rid of all foo tokens
	foo.Transfer(cross, testutils.TestAddress("burn"), foo.BalanceOf(user))
	uassert.Equal(t, int64(0), foo.BalanceOf(user), "User should have 0 FOO")

	// wait for rewards to accumulate
	testing.SkipHeights(1000)
	expectedPanicMsg := "[GNOSWAP-LAUNCHPAD-016] invalid data || input amount(0) is less than minimum amount(1000)"
	// user cannot collect rewards without foo tokens anymore
	func() {
		uassert.AbortsWithMessage(t, expectedPanicMsg, func() {
			CollectRewardByDepositId(cross, deposit.ID())
		})
	}()

	// fast forward to end of tier
	projectTier, _ := project.getTier(30)
	testing.SetHeight(projectTier.EndHeight() + 1)

	// user cannot withdraw deposit without foo tokens anymore
	func() {
		uassert.AbortsWithMessage(t, expectedPanicMsg, func() {
			CollectDepositGns(cross, deposit.ID())
		})
	}()
}
