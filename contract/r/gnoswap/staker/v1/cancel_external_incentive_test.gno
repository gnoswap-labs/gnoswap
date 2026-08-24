package staker

import (
	"chain/runtime"
	"math"
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/gns"
	sr "gno.land/r/gnoswap/staker"
	"gno.land/r/onbloc/bar"
)

const cancelTestPoolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:3000"

// setupCancelTestPool registers the pool in the pool realm and in the staker
// pool storage, then returns the staker-side pool.
func setupCancelTestPool(cur realm, currentTime int64) *sr.Pool {
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, math.MaxInt)
	CreatePool(cur, barPath, fooPath, fee3000, "79228162514264337593543950336", adminAddr)

	pool := sr.NewPool(cancelTestPoolPath, currentTime)
	getMockInstance().getPools().set(cancelTestPoolPath, pool)

	return pool
}

// createCancelTestIncentive registers an incentive in both the per-pool trees
// and the global incentive tree, exactly as CreateExternalIncentive does.
func createCancelTestIncentive(
	pool *sr.Pool,
	incentiveId string,
	creator address,
	rewardAmount int64,
	depositGnsAmount int64,
	startTime int64,
	endTime int64,
	currentTime int64,
) *sr.ExternalIncentive {
	incentive := sr.NewExternalIncentive(
		incentiveId,
		cancelTestPoolPath,
		barPath,
		rewardAmount,
		startTime,
		endTime,
		creator,
		depositGnsAmount,
		runtime.ChainHeight(),
		currentTime,
	)

	getMockInstance().getExternalIncentives().set(incentiveId, incentive)
	NewPoolResolver(pool).IncentivesResolver().create(incentive)

	return incentive
}

func TestCancelExternalIncentive(cur realm, t *testing.T) {
	creator := testutils.TestAddress("cancel-creator")
	stranger := testutils.TestAddress("cancel-stranger")

	rewardAmount := int64(10_000_000_000)
	depositGnsAmount := int64(100_000_000)
	incentiveId := "cancel-incentive-1"

	tests := []struct {
		name             string
		poolPath         string
		incentiveId      string
		caller           address
		setupPool        bool
		setupIncentive   bool
		startOffset      int64 // start timestamp relative to the current time
		markRefunded     bool
		expectedErrorMsg string
	}{
		{
			name:             "pool not registered in pool accessor",
			poolPath:         "gno.land/r/invalid/pool:path:100",
			incentiveId:      incentiveId,
			caller:           adminAddr,
			setupPool:        false,
			setupIncentive:   false,
			startOffset:      86400,
			expectedErrorMsg: "[GNOSWAP-STAKER-011]", // errInvalidPoolPath
		},
		{
			name:             "caller is neither admin nor governance",
			poolPath:         cancelTestPoolPath,
			incentiveId:      incentiveId,
			caller:           stranger,
			setupPool:        true,
			setupIncentive:   true,
			startOffset:      86400,
			expectedErrorMsg: "is not admin or governance",
		},
		{
			name:             "creator cannot cancel",
			poolPath:         cancelTestPoolPath,
			incentiveId:      incentiveId,
			caller:           creator,
			setupPool:        true,
			setupIncentive:   true,
			startOffset:      86400,
			expectedErrorMsg: "is not admin or governance",
		},
		{
			name:             "incentive not found",
			poolPath:         cancelTestPoolPath,
			incentiveId:      "nonexistent-id",
			caller:           adminAddr,
			setupPool:        true,
			setupIncentive:   true,
			startOffset:      86400,
			expectedErrorMsg: "[GNOSWAP-STAKER-023]", // errCannotCancelIncentive
		},
		{
			name:             "incentive started at current time (boundary)",
			poolPath:         cancelTestPoolPath,
			incentiveId:      incentiveId,
			caller:           adminAddr,
			setupPool:        true,
			setupIncentive:   true,
			startOffset:      0,                      // starts exactly at the current time
			expectedErrorMsg: "[GNOSWAP-STAKER-023]", // errCannotCancelIncentive
		},
		{
			name:             "incentive already started (in the past)",
			poolPath:         cancelTestPoolPath,
			incentiveId:      incentiveId,
			caller:           adminAddr,
			setupPool:        true,
			setupIncentive:   true,
			startOffset:      -86400,                 // started a day ago
			expectedErrorMsg: "[GNOSWAP-STAKER-023]", // errCannotCancelIncentive
		},
		{
			name:             "incentive already refunded",
			poolPath:         cancelTestPoolPath,
			incentiveId:      incentiveId,
			caller:           adminAddr,
			setupPool:        true,
			setupIncentive:   true,
			startOffset:      86400,
			markRefunded:     true,
			expectedErrorMsg: "[GNOSWAP-STAKER-023]", // errCannotCancelIncentive
		},
		{
			name:           "admin cancels before start",
			poolPath:       cancelTestPoolPath,
			incentiveId:    incentiveId,
			caller:         adminAddr,
			setupPool:      true,
			setupIncentive: true,
			startOffset:    86400,
		},
		{
			name:           "governance cancels before start",
			poolPath:       cancelTestPoolPath,
			incentiveId:    incentiveId,
			caller:         govGovernanceAddr,
			setupPool:      true,
			setupIncentive: true,
			startOffset:    86400,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			initStakerTest(cur, t)
			instance := getMockInstance()

			currentTime := time.Now().Unix()
			startTime := currentTime + tt.startOffset
			endTime := startTime + 86400*30

			var pool *sr.Pool
			if tt.setupPool {
				pool = setupCancelTestPool(cur, currentTime)

				if tt.setupIncentive {
					incentive := createCancelTestIncentive(
						pool, incentiveId, creator,
						rewardAmount, depositGnsAmount,
						startTime, endTime, currentTime,
					)

					if tt.markRefunded {
						incentive.SetRefunded(true)
						NewPoolResolver(pool).IncentivesResolver().update(incentive)
					}
				}
			}

			if tt.expectedErrorMsg != "" {
				testing.SetRealm(testing.NewUserRealm(tt.caller))
				uassert.AbortsContains(t, cur, tt.expectedErrorMsg, func() {
					mockInstanceCancelExternalIncentive(cross(cur), tt.poolPath, tt.incentiveId)
				})
				return
			}

			// The reward refund is capped by the ROLE_STAKER balance, and
			// staker/v1 is the cross(rlm) transfer actor for the local mock
			// instance, so fund both. The GNS deposit is paid by the actor only.
			testing.SetRealm(adminRealm)
			bar.Transfer(cross(cur), stakerAddr, rewardAmount)
			bar.Transfer(cross(cur), stakerV1Addr, rewardAmount)
			gns.Transfer(cross(cur), stakerV1Addr, depositGnsAmount)

			// Funds are always returned to the incentive creator.
			barBefore := bar.BalanceOf(creator)
			gnsBefore := gns.BalanceOf(creator)

			testing.SetRealm(testing.NewUserRealm(tt.caller))
			mockInstanceCancelExternalIncentive(cross(cur), tt.poolPath, tt.incentiveId)

			uassert.Equal(t, rewardAmount, bar.BalanceOf(creator)-barBefore)
			uassert.Equal(t, depositGnsAmount, gns.BalanceOf(creator)-gnsBefore)

			// The incentive is gone from the per-pool tree, the per-pool
			// start-time index and the global incentive tree.
			incentivesResolver := NewPoolResolver(pool).IncentivesResolver()
			_, exists := incentivesResolver.Get(tt.incentiveId)
			uassert.False(t, exists)
			uassert.False(t, instance.getExternalIncentives().Has(tt.incentiveId))

			discovered := make([]string, 0)
			incentivesResolver.IterateIncentiveIdsByTime(0, endTime, func(id string) bool {
				discovered = append(discovered, id)
				return false
			})
			uassert.Equal(t, 0, len(discovered))
		})
	}
}

// TestCancelExternalIncentive_KeepsSiblingWithSameStartTime verifies the
// start-time index bucket keeps the other incentives that share the cancelled
// incentive's start timestamp.
func TestCancelExternalIncentive_KeepsSiblingWithSameStartTime(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	instance := getMockInstance()

	creator := testutils.TestAddress("cancel-creator")

	rewardAmount := int64(10_000_000_000)
	depositGnsAmount := int64(100_000_000)

	currentTime := time.Now().Unix()
	startTime := currentTime + 86400
	endTime := startTime + 86400*30

	pool := setupCancelTestPool(cur, currentTime)
	createCancelTestIncentive(pool, "cancel-me", creator, rewardAmount, depositGnsAmount, startTime, endTime, currentTime)
	createCancelTestIncentive(pool, "keep-me", creator, rewardAmount, depositGnsAmount, startTime, endTime, currentTime)

	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), stakerAddr, rewardAmount)
	bar.Transfer(cross(cur), stakerV1Addr, rewardAmount)
	gns.Transfer(cross(cur), stakerV1Addr, depositGnsAmount)

	testing.SetRealm(adminRealm)
	mockInstanceCancelExternalIncentive(cross(cur), cancelTestPoolPath, "cancel-me")

	incentivesResolver := NewPoolResolver(pool).IncentivesResolver()

	_, cancelled := incentivesResolver.Get("cancel-me")
	uassert.False(t, cancelled)

	_, kept := incentivesResolver.Get("keep-me")
	uassert.True(t, kept)
	uassert.True(t, instance.getExternalIncentives().Has("keep-me"))

	discovered := make([]string, 0)
	incentivesResolver.IterateIncentiveIdsByTime(0, endTime, func(id string) bool {
		discovered = append(discovered, id)
		return false
	})
	uassert.Equal(t, 1, len(discovered))
	uassert.Equal(t, "keep-me", discovered[0])
}

// TestCancelExternalIncentive_PoolNoLongerExternallyIncentivized verifies that
// cancelling the only incentive of a pool makes the pool non-stakeable again,
// which is what StakeToken checks through poolHasIncentives.
func TestCancelExternalIncentive_PoolNoLongerExternallyIncentivized(cur realm, t *testing.T) {
	initStakerTest(cur, t)

	creator := testutils.TestAddress("cancel-creator")

	rewardAmount := int64(10_000_000_000)
	depositGnsAmount := int64(100_000_000)

	currentTime := time.Now().Unix()
	startTime := currentTime + 86400
	endTime := startTime + 86400*30

	pool := setupCancelTestPool(cur, currentTime)
	createCancelTestIncentive(pool, "cancel-me", creator, rewardAmount, depositGnsAmount, startTime, endTime, currentTime)

	poolResolver := NewPoolResolver(pool)
	uassert.True(t, poolResolver.IsExternallyIncentivizedPool())

	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), stakerAddr, rewardAmount)
	bar.Transfer(cross(cur), stakerV1Addr, rewardAmount)
	gns.Transfer(cross(cur), stakerV1Addr, depositGnsAmount)

	testing.SetRealm(adminRealm)
	mockInstanceCancelExternalIncentive(cross(cur), cancelTestPoolPath, "cancel-me")

	uassert.False(t, poolResolver.IsExternallyIncentivizedPool())
}

// TestCancelExternalIncentive_RefundsCreator verifies the reward tokens and the
// GNS deposit are returned to the incentive creator, not to the admin/governance
// caller that triggers the cancel.
func TestCancelExternalIncentive_RefundsCreator(cur realm, t *testing.T) {
	initStakerTest(cur, t)

	creator := testutils.TestAddress("cancel-creator")

	rewardAmount := int64(10_000_000_000)
	depositGnsAmount := int64(100_000_000)

	currentTime := time.Now().Unix()
	startTime := currentTime + 86400
	endTime := startTime + 86400*30

	pool := setupCancelTestPool(cur, currentTime)
	createCancelTestIncentive(pool, "cancel-me", creator, rewardAmount, depositGnsAmount, startTime, endTime, currentTime)

	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), stakerAddr, rewardAmount)
	bar.Transfer(cross(cur), stakerV1Addr, rewardAmount)
	gns.Transfer(cross(cur), stakerV1Addr, depositGnsAmount)

	creatorBarBefore := bar.BalanceOf(creator)
	creatorGnsBefore := gns.BalanceOf(creator)
	adminBarBefore := bar.BalanceOf(adminAddr)
	adminGnsBefore := gns.BalanceOf(adminAddr)

	// Admin triggers the cancel, but the refund goes to the creator.
	testing.SetRealm(adminRealm)
	mockInstanceCancelExternalIncentive(cross(cur), cancelTestPoolPath, "cancel-me")

	uassert.Equal(t, rewardAmount, bar.BalanceOf(creator)-creatorBarBefore)
	uassert.Equal(t, depositGnsAmount, gns.BalanceOf(creator)-creatorGnsBefore)

	// The admin caller receives nothing back.
	uassert.Equal(t, int64(0), bar.BalanceOf(adminAddr)-adminBarBefore)
	uassert.Equal(t, int64(0), gns.BalanceOf(adminAddr)-adminGnsBefore)
}

// TestCancelExternalIncentive_RefundCappedByStakerBalance verifies the refund is
// capped by the balance actually held, so a short balance still releases the
// GNS deposit instead of aborting.
func TestCancelExternalIncentive_RefundCappedByStakerBalance(cur realm, t *testing.T) {
	initStakerTest(cur, t)

	creator := testutils.TestAddress("cancel-creator")

	depositGnsAmount := int64(100_000_000)

	currentTime := time.Now().Unix()
	startTime := currentTime + 86400
	endTime := startTime + 86400*30

	pool := setupCancelTestPool(cur, currentTime)

	// The refund cap reads the ROLE_STAKER balance, which carries over between
	// tests in the same VM, so derive the expected refund from it instead of a
	// fixed amount. staker/v1 is the actual transfer actor for the local mock
	// instance, so it needs at least the capped amount.
	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), stakerAddr, 4_000_000_000)
	cappedRefund := bar.BalanceOf(stakerAddr)
	bar.Transfer(cross(cur), stakerV1Addr, cappedRefund)
	gns.Transfer(cross(cur), stakerV1Addr, depositGnsAmount)

	// Reward amount exceeds what the staker actually holds.
	rewardAmount := cappedRefund + 1_000_000_000
	createCancelTestIncentive(pool, "cancel-me", creator, rewardAmount, depositGnsAmount, startTime, endTime, currentTime)

	barBefore := bar.BalanceOf(creator)
	gnsBefore := gns.BalanceOf(creator)

	testing.SetRealm(adminRealm)
	mockInstanceCancelExternalIncentive(cross(cur), cancelTestPoolPath, "cancel-me")

	uassert.Equal(t, cappedRefund, bar.BalanceOf(creator)-barBefore)
	uassert.Equal(t, depositGnsAmount, gns.BalanceOf(creator)-gnsBefore)
}

// TestCancelExternalIncentive_RejectsAccruedIncentive verifies the defensive
// guard: an incentive carrying distributed rewards or an accumulated penalty is
// never removed, because dropping the record would strand those tokens.
func TestCancelExternalIncentive_RejectsAccruedIncentive(cur realm, t *testing.T) {
	creator := testutils.TestAddress("cancel-creator")

	rewardAmount := int64(10_000_000_000)
	depositGnsAmount := int64(100_000_000)

	tests := []struct {
		name   string
		mutate func(resolver *ExternalIncentiveResolver)
	}{
		{
			name:   "distributed reward amount",
			mutate: func(resolver *ExternalIncentiveResolver) { resolver.addDistributedRewardAmount(1) },
		},
		{
			name:   "accumulated penalty amount",
			mutate: func(resolver *ExternalIncentiveResolver) { resolver.addAccumulatedPenaltyAmount(1) },
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			initStakerTest(cur, t)

			currentTime := time.Now().Unix()
			startTime := currentTime + 86400
			endTime := startTime + 86400*30

			pool := setupCancelTestPool(cur, currentTime)
			incentive := createCancelTestIncentive(
				pool, "cancel-me", creator,
				rewardAmount, depositGnsAmount,
				startTime, endTime, currentTime,
			)
			tt.mutate(NewExternalIncentiveResolver(incentive))

			testing.SetRealm(adminRealm)
			uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-023]", func() {
				mockInstanceCancelExternalIncentive(cross(cur), cancelTestPoolPath, "cancel-me")
			})
		})
	}
}

// TestAssertIsNotStartedIncentive_StartBoundary pins the before/at/after-start
// exception handling of the cancel guard directly: an incentive is cancellable
// strictly before its start timestamp, and rejected once currentTime reaches or
// passes it. This isolates the boundary from the full CancelExternalIncentive
// flow, so an off-by-one in IsStarted would fail here regardless of pool setup.
func TestAssertIsNotStartedIncentive_StartBoundary(cur realm, t *testing.T) {
	creator := testutils.TestAddress("cancel-creator")

	startTimestamp := int64(2_000_000_000)
	endTimestamp := startTimestamp + 86400*30

	newResolver := func() *ExternalIncentiveResolver {
		incentive := sr.NewExternalIncentive(
			"boundary-incentive",
			cancelTestPoolPath,
			barPath,
			1_000_000_000,
			startTimestamp,
			endTimestamp,
			creator,
			100_000_000,
			runtime.ChainHeight(),
			startTimestamp-86400,
		)
		return NewExternalIncentiveResolver(incentive)
	}

	// Before start: cancellable (no panic).
	uassert.NotPanics(t, cur, func() {
		assertIsNotStartedIncentive(newResolver(), startTimestamp-1)
	})

	// Exactly at start: rejected (currentTime >= start).
	uassert.PanicsContains(t, cur, "already started", func() {
		assertIsNotStartedIncentive(newResolver(), startTimestamp)
	})

	// After start: rejected.
	uassert.PanicsContains(t, cur, "already started", func() {
		assertIsNotStartedIncentive(newResolver(), startTimestamp+1)
	})
}
