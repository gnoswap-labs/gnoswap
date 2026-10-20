package launchpad

import (
	"chain"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/obl"
)

const preCheckCollectorPkgPath = "gno.land/r/gnoswap/launchpad/v1"

type collectDepositSnapshot struct {
	tierCollected    int64
	managerClaimed   int64
	rewardClaimed    int64
	totalStaked      int64
	gnsTotalSupply   int64
	collectorOBL     int64
	depositWithdrawn bool
}

func takeCollectDepositSnapshot(t *testing.T, lp *launchpadV1, projectID, depositID string) collectDepositSnapshot {
	project, err := lp.getProject(projectID)
	uassert.NoError(t, err)
	tier, err := getProjectTier(project, projectTier30)
	uassert.NoError(t, err)
	manager, err := lp.getProjectTierRewardManager(tier.ID())
	uassert.NoError(t, err)

	rewardClaimed := int64(-1)
	if rewardState, err := getDepositRewardState(manager, depositID); err == nil {
		rewardClaimed = rewardState.ClaimedAmount()
	}

	return collectDepositSnapshot{
		tierCollected:    tier.TotalCollectedAmount(),
		managerClaimed:   manager.TotalClaimedAmount(),
		rewardClaimed:    rewardClaimed,
		totalStaked:      lp.store.GetTotalGNSStakedAmount(),
		gnsTotalSupply:   gns.TotalSupply(),
		collectorOBL:     obl.BalanceOf(chain.PackageAddress(preCheckCollectorPkgPath)),
		depositWithdrawn: lp.mustGetDeposit(depositID).IsWithdrawn(),
	}
}

func assertCollectDepositSnapshotUnchanged(t *testing.T, before, after collectDepositSnapshot, msg string) {
	uassert.Equal(t, before.tierCollected, after.tierCollected, msg)
	uassert.Equal(t, before.managerClaimed, after.managerClaimed, msg)
	uassert.Equal(t, before.rewardClaimed, after.rewardClaimed, msg)
	uassert.Equal(t, before.totalStaked, after.totalStaked, msg)
	uassert.Equal(t, before.gnsTotalSupply, after.gnsTotalSupply, msg)
	uassert.Equal(t, before.collectorOBL, after.collectorOBL, msg)
	uassert.Equal(t, before.depositWithdrawn, after.depositWithdrawn, msg)
}

func TestCollectDepositGns_PreChecksPreventStateChanges(cur realm, t *testing.T) {
	lp, launchpadAddr, _, projectID, tier := setupPreStartProject(cur, t)
	depositID := createV1OwnedDeposit(cur, t, lp, launchpadAddr, projectID, projectTier30, preStartTestDepositUnit)
	claimableTime := tier.StartTime() + projectTierRewardCollectableDuration[projectTier30]

	tests := []struct {
		name        string
		currentTime int64
	}{
		{"before tier start", tier.StartTime() - 1},
		{"after reward becomes claimable", claimableTime},
		{"one second before tier end", tier.EndTime() - 1},
		{"at tier end", tier.EndTime()},
	}

	for _, tt := range tests {
		setPreStartTestTime(tt.currentTime)
		before := takeCollectDepositSnapshot(t, lp, projectID, depositID)

		uassert.AbortsContains(t, cur, "[GNOSWAP-LAUNCHPAD-016] project lock period is not over yet", func() {
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))
				lp.CollectDepositGns(0, cur, depositID)
			}(cross(cur))
		})

		assertCollectDepositSnapshotUnchanged(t, before, takeCollectDepositSnapshot(t, lp, projectID, depositID), tt.name)
	}

	setPreStartTestTime(tier.EndTime() + 1)
	before := takeCollectDepositSnapshot(t, lp, projectID, depositID)

	var amount int64
	var err error
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))
		amount, err = lp.CollectDepositGns(0, cur, depositID)
	}(cross(cur))

	after := takeCollectDepositSnapshot(t, lp, projectID, depositID)
	reward := after.collectorOBL - before.collectorOBL
	uassert.NoError(t, err)
	uassert.Equal(t, preStartTestDepositUnit, amount)
	uassert.Equal(t, preStartTestRewardAmount-1, reward)
	uassert.Equal(t, reward, after.tierCollected)
	uassert.Equal(t, before.totalStaked-preStartTestDepositUnit, after.totalStaked)
	uassert.True(t, after.depositWithdrawn)

	// A withdrawn deposit fails on the pre-check without touching state.
	setPreStartTestTime(tier.EndTime() + 2)
	uassert.AbortsContains(t, cur, "[GNOSWAP-LAUNCHPAD-013] already collected", func() {
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))
			lp.CollectDepositGns(0, cur, depositID)
		}(cross(cur))
	})
	assertCollectDepositSnapshotUnchanged(t, after, takeCollectDepositSnapshot(t, lp, projectID, depositID), "already withdrawn")
}

func TestCollectDepositGns_RejectsSpoofedRealm(cur realm, t *testing.T) {
	lp, launchpadAddr, _, projectID, tier := setupPreStartProject(cur, t)
	depositID := createV1OwnedDeposit(cur, t, lp, launchpadAddr, projectID, projectTier30, preStartTestDepositUnit)
	setPreStartTestTime(tier.EndTime() + 1)
	before := takeCollectDepositSnapshot(t, lp, projectID, depositID)

	stale := cur
	uassert.AbortsContains(t, cur, "rlm does not match the current crossing frame", func() {
		func(cur realm) {
			testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))
			lp.CollectDepositGns(0, stale, depositID)
		}(cross(cur))
	})

	assertCollectDepositSnapshotUnchanged(t, before, takeCollectDepositSnapshot(t, lp, projectID, depositID), "spoofed realm")
}
