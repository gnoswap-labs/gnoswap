package launchpad

import (
	"chain/runtime"
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/onbloc/obl"

	u256 "gno.land/p/gnoswap/uint256/v1"
	"gno.land/r/gnoswap/launchpad"
)

const (
	preStartTestCreatedAt    = int64(1234567890)
	preStartTestRewardAmount = int64(1_000_000_000)
	preStartTestDepositUnit  = int64(1_000_000)
)

func setPreStartTestTime(unixTime int64) {
	ctx := testing.GetContext()
	ctx.Time = time.Unix(unixTime, 0)
	testing.SetContext(ctx)
}

// setupPreStartProject creates a 30-day-only project without advancing time.
func setupPreStartProject(cur realm, t *testing.T) (*launchpadV1, address, runtime.Realm, string, *launchpad.ProjectTier) {
	launchpadAddr, adminRealm := setupTestEnvironment(cur, t, testEnvConfig{height: 123, initialTime: preStartTestCreatedAt})
	lp := getTestImplementation()

	testing.SetRealm(adminRealm)
	obl.Approve(cross(cur), launchpadAddr, preStartTestRewardAmount)
	projectID := createDepositTestProject(
		cur, lp, launchpadAddr, adminRealm, "Pre Start Project", testutils.TestAddress("pre_start_project"),
		preStartTestRewardAmount, 100, 0, 0, preStartTestCreatedAt+projectMinimumStartDelayTime,
	)

	project, err := lp.getProject(projectID)
	uassert.NoError(t, err)
	tier, err := getProjectTier(project, projectTier30)
	uassert.NoError(t, err)

	return lp, launchpadAddr, adminRealm, projectID, tier
}

func depositPreStartTest(cur realm, t *testing.T, lp *launchpadV1, launchpadAddr address, adminRealm runtime.Realm, projectID, userSuffix string, amount int64) (address, string) {
	return createTestDeposit(cur, t, lp, launchpadAddr, adminRealm, projectID, testDepositConfig{
		userSuffix:    userSuffix,
		depositAmount: amount,
		tier:          projectTier30,
	})
}

func TestIsTierDepositable(t *testing.T) {
	tier := newProjectTier("p", projectTier30, 1000, 1000, 2000)

	tests := []struct {
		name        string
		currentTime int64
		expected    bool
	}{
		{"before start", 0, true},
		{"one second before start", 999, true},
		{"at start", 1000, true},
		{"one second before end", 1999, true},
		{"at end", 2000, false},
		{"after end", 2001, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.expected, isTierDepositable(tier, tt.currentTime))
		})
	}
}

func TestAddRewardStateByDeposit_RewardStartTime(t *testing.T) {
	const (
		startTime = int64(1000)
		endTime   = int64(2000)
	)

	tests := []struct {
		name              string
		createdAt         int64
		claimableDuration int64
		hasPriorDeposit   bool
		expectedStartTime int64
		expectedClaimable int64
	}{
		{"first deposit before start", 500, 100, false, startTime, 1100},
		{"later deposit before start", 500, 100, true, startTime, 1100},
		{"deposit one second before start", 999, 100, true, startTime, 1100},
		{"deposit at start", 1000, 100, true, startTime, 1100},
		{"deposit after start", 1500, 100, true, 1500, 1600},
		{"pre-start claimable time capped at end", 500, 5000, true, startTime, endTime},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			manager := newRewardManager(1000, startTime, endTime, tt.claimableDuration)
			if tt.hasPriorDeposit {
				prior := newDeposit("prior", "p", projectTier30, testutils.TestAddress("prior"), 100, 1, 400, endTime)
				addRewardStateByDeposit(manager, *prior)
			}

			deposit := newDeposit("target", "p", projectTier30, testutils.TestAddress("target"), 100, 1, tt.createdAt, endTime)
			rewardState := addRewardStateByDeposit(manager, *deposit)

			uassert.Equal(t, tt.expectedStartTime, rewardState.DistributeStartTime())
			uassert.Equal(t, tt.expectedClaimable, rewardState.ClaimableTime())
			uassert.True(t, rewardState.PriceDebtX128().IsZero())
		})
	}
}

func TestUpdateRewardPerDepositX128_PreStart(t *testing.T) {
	t.Run("no accrual before or at start", func(t *testing.T) {
		manager := newRewardManager(1000, 1000, 2000, 0)

		for _, currentTime := range []int64{500, 999, 1000} {
			uassert.NoError(t, updateRewardPerDepositX128(manager, 100, currentTime))
			uassert.True(t, manager.AccumulatedRewardPerDepositX128().IsZero())
			uassert.Equal(t, int64(0), manager.AccumulatedTime())
		}
	})

	t.Run("accrual starts from start time", func(t *testing.T) {
		manager := newRewardManager(1000, 1000, 2000, 0)
		uassert.NoError(t, updateRewardPerDepositX128(manager, 100, 500))
		uassert.NoError(t, updateRewardPerDepositX128(manager, 100, 1001))

		expected := u256.MulDiv(u256.NewUint(1), manager.DistributeAmountPerSecondX128(), u256.NewUint(100))
		uassert.Equal(t, expected.ToString(), manager.AccumulatedRewardPerDepositX128().ToString())
		uassert.Equal(t, int64(1001), manager.AccumulatedTime())
	})

	t.Run("pre-start deposit receives full reward through end", func(t *testing.T) {
		manager := newRewardManager(1000, 1000, 2000, 0)
		deposit := newDeposit("1", "p", projectTier30, testutils.TestAddress("user"), 100, 1, 500, 2000)
		rewardState := addRewardStateByDeposit(manager, *deposit)

		uassert.NoError(t, updateRewardPerDepositX128(manager, 100, 500))
		uassert.NoError(t, updateRewardPerDepositX128(manager, 100, 3000))

		uassert.Equal(t, int64(1000), calculateClaimableReward(rewardState, manager.AccumulatedRewardPerDepositX128()))
		uassert.Equal(t, int64(2000), manager.AccumulatedTime())
	})
}

func TestDepositGns_PreStartBoundaries(cur realm, t *testing.T) {
	startTime := preStartTestCreatedAt + projectMinimumStartDelayTime
	endTime := startTime + projectTierDurationTimes[projectTier30]
	claimableDuration := projectTierRewardCollectableDuration[projectTier30]

	tests := []struct {
		name              string
		depositTime       int64
		expectedError     string
		expectedClaimable int64
	}{
		{"at project creation", preStartTestCreatedAt, "", startTime + claimableDuration},
		{"one second before start", startTime - 1, "", startTime + claimableDuration},
		{"at start", startTime, "", startTime + claimableDuration},
		{"one second before end", endTime - 1, "", endTime},
		{"at end", endTime, errInactiveProject, 0},
		{"after end", endTime + 1, errInactiveProject, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			lp, _, _, projectID, _ := setupPreStartProject(cur, t)
			setPreStartTestTime(tt.depositTime)

			project, err := lp.getProject(projectID)
			uassert.NoError(t, err)

			deposit, rewardState, _, _, err := lp.depositGns(0, cur, project, projectTier30, preStartTestDepositUnit, testutils.TestAddress("boundary_user"))
			if tt.expectedError != "" {
				uassert.ErrorContains(t, err, tt.expectedError)
				return
			}

			uassert.NoError(t, err)
			uassert.Equal(t, tt.depositTime, deposit.CreatedAt())
			uassert.Equal(t, tt.expectedClaimable, rewardState.ClaimableTime())
		})
	}
}

func TestCollectReward_PreStartDepositClaimableTime(cur realm, t *testing.T) {
	lp, launchpadAddr, adminRealm, projectID, tier := setupPreStartProject(cur, t)
	userAddr, depositID := depositPreStartTest(cur, t, lp, launchpadAddr, adminRealm, projectID, "claim_user", preStartTestDepositUnit)
	deposit := lp.mustGetDeposit(depositID)
	claimableTime := tier.StartTime() + projectTierRewardCollectableDuration[projectTier30]

	for _, currentTime := range []int64{tier.StartTime() - 1, tier.StartTime(), claimableTime - 1} {
		setPreStartTestTime(currentTime)
		_, _, err := lp.collectDepositReward(0, cur, deposit, 0, currentTime)
		uassert.ErrorContains(t, err, errInvalidRewardState)
	}

	setPreStartTestTime(claimableTime)
	reward := collectTestReward(cur, t, lp, userAddr, depositID)
	// One day of a 30-day tier: floor(1e9 / 30) with Q128 truncation.
	uassert.Equal(t, int64(33_333_333), reward)
	uassert.Equal(t, reward, obl.BalanceOf(userAddr))
}

func TestPreStartDeposit_RewardDistribution(cur realm, t *testing.T) {
	t.Run("single pre-start deposit takes the whole tier reward", func(cur realm, t *testing.T) {
		lp, launchpadAddr, adminRealm, projectID, tier := setupPreStartProject(cur, t)
		userAddr, depositID := depositPreStartTest(cur, t, lp, launchpadAddr, adminRealm, projectID, "solo", preStartTestDepositUnit)

		setPreStartTestTime(tier.EndTime() + 1)
		reward := collectTestReward(cur, t, lp, userAddr, depositID)

		uassert.Equal(t, preStartTestRewardAmount-1, reward)
	})

	t.Run("pre-start deposit and mid-tier deposit split by time weight", func(cur realm, t *testing.T) {
		lp, launchpadAddr, adminRealm, projectID, tier := setupPreStartProject(cur, t)
		earlyAddr, earlyID := depositPreStartTest(cur, t, lp, launchpadAddr, adminRealm, projectID, "early", preStartTestDepositUnit)

		setPreStartTestTime(tier.StartTime() + (tier.EndTime()-tier.StartTime())/2)
		lateAddr, lateID := depositPreStartTest(cur, t, lp, launchpadAddr, adminRealm, projectID, "late", preStartTestDepositUnit)

		setPreStartTestTime(tier.EndTime() + 1)
		earlyReward := collectTestReward(cur, t, lp, earlyAddr, earlyID)
		lateReward := collectTestReward(cur, t, lp, lateAddr, lateID)

		uassert.Equal(t, int64(749_999_999), earlyReward)
		uassert.Equal(t, int64(249_999_999), lateReward)
	})

	t.Run("multiple pre-start deposits share from start by amount", func(cur realm, t *testing.T) {
		lp, launchpadAddr, adminRealm, projectID, tier := setupPreStartProject(cur, t)

		aliceAddr, aliceID := depositPreStartTest(cur, t, lp, launchpadAddr, adminRealm, projectID, "alice", preStartTestDepositUnit)
		setPreStartTestTime(tier.StartTime() - dayTime)
		bobAddr, bobID := depositPreStartTest(cur, t, lp, launchpadAddr, adminRealm, projectID, "bob", 2*preStartTestDepositUnit)
		setPreStartTestTime(tier.StartTime() - 1)
		charlieAddr, charlieID := depositPreStartTest(cur, t, lp, launchpadAddr, adminRealm, projectID, "charlie", preStartTestDepositUnit)

		rewardManager, err := lp.getProjectTierRewardManager(tier.ID())
		uassert.NoError(t, err)
		uassert.True(t, rewardManager.AccumulatedRewardPerDepositX128().IsZero())

		setPreStartTestTime(tier.EndTime() + 1)
		aliceReward := collectTestReward(cur, t, lp, aliceAddr, aliceID)
		bobReward := collectTestReward(cur, t, lp, bobAddr, bobID)
		charlieReward := collectTestReward(cur, t, lp, charlieAddr, charlieID)

		uassert.Equal(t, int64(249_999_999), aliceReward)
		uassert.Equal(t, int64(499_999_999), bobReward)
		uassert.Equal(t, int64(249_999_999), charlieReward)
		uassert.True(t, aliceReward+bobReward+charlieReward <= preStartTestRewardAmount)
	})
}

func TestCollectDepositGns_PreStartDepositLockedUntilTierEnd(cur realm, t *testing.T) {
	lp, launchpadAddr, adminRealm, projectID, tier := setupPreStartProject(cur, t)
	_, depositID := depositPreStartTest(cur, t, lp, launchpadAddr, adminRealm, projectID, "lock_user", preStartTestDepositUnit)
	deposit := lp.mustGetDeposit(depositID)

	for _, currentTime := range []int64{tier.StartTime() - 1, tier.EndTime()} {
		setPreStartTestTime(currentTime)
		_, _, err := lp.withdrawDeposit(0, cur, deposit, 0, currentTime)
		uassert.ErrorContains(t, err, errNotYetEndedProject)
	}

	setPreStartTestTime(tier.EndTime() + 1)
	_, amount, err := lp.withdrawDeposit(0, cur, deposit, 0, tier.EndTime()+1)
	uassert.NoError(t, err)
	uassert.Equal(t, preStartTestDepositUnit, amount)
}
