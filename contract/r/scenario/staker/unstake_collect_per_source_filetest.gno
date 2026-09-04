// PKGPATH: gno.land/r/gnoswap/v1/main

// An unstaked position collects per source, the same way a staked one does, and cannot be
// staked again until it has.
//
// The exit checkpoint owes the emission reward and one incentive. Each is collected on its own
// entry point, so neither transaction carries the other's cost, and the checkpoint is dropped
// only once both are done - which is also when the position becomes stakeable again.

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	"gno.land/r/gnoswap/scenarioutils"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	// The staker unstakes and never comes back, so nothing that needs their signature can
	// unblock the incentive.
	stakerUserAddr  = testutils.TestAddress("absentStaker")
	stakerUserRealm = testing.NewUserRealm(stakerUserAddr)

	creatorAddr  = testutils.TestAddress("incentiveCreator")
	creatorRealm = testing.NewUserRealm(creatorAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	quxPath = "gno.land/r/onbloc/qux.QUX"
	gnsPath = "gno.land/r/gnoswap/gns.GNS"

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	incentiveDuration int64 = 90 * 24 * 60 * 60
	rewardAmount      int64 = 1_500_000_000

	incentiveId string
)

func main(cur realm) {
	println("[SCENARIO] 1. Create an incentive and stake against it")
	setup(cur)

	println()
	println("[SCENARIO] 2. Unstake without collecting")
	unstakeWithoutCollecting(cur)

	println()
	println("[SCENARIO] 3. Staking again is refused while rewards are uncollected")
	restakeRejected(cur)

	println()
	println("[SCENARIO] 4. Collect the emission reward on its own")
	collectEmissionOnly(cur)

	println()
	println("[SCENARIO] 5. Collect the incentive reward on its own")
	collectIncentiveOnly(cur)

	println()
	println("[SCENARIO] 6. The position can be staked again")
	restakeAccepted(cur)
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)

	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	bar.Transfer(cross(cur), stakerUserAddr, 10000)
	qux.Transfer(cross(cur), stakerUserAddr, 10000)
	gns.Transfer(cross(cur), creatorAddr, rewardAmount+100_000_000_000)

	pl.CreatePool(cross(cur), barPath, quxPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross(cur), poolPath, 1)

	testing.SetRealm(creatorRealm)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	createdAt := time.Now().Unix()
	startTime := ((createdAt / 86400) + 2) * 86400
	incentiveId = ufmt.Sprintf("%s:%d:%d", creatorAddr, createdAt, 1)

	sr.CreateExternalIncentive(cross(cur), poolPath, gnsPath, rewardAmount, startTime, startTime+incentiveDuration)

	if left := startTime - time.Now().Unix(); left > 0 {
		testing.SkipHeights(left / 5)
	}

	testing.SetRealm(stakerUserRealm)
	bar.Approve(cross(cur), poolAddr, maxInt64)
	qux.Approve(cross(cur), poolAddr, maxInt64)

	positionId, _, _, _ := pn.Mint(
		cross(cur), barPath, quxPath, fee100,
		int32(-100), int32(100), "1000", "1000", "1", "1",
		maxTimeout, stakerUserAddr, "",
	)

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross(cur), positionId, "")

	ufmt.Printf("[INFO] staked position %d against the incentive\n", positionId)
}

func unstakeWithoutCollecting(cur realm) {
	testing.SkipHeights((incentiveDuration + 24*60*60) / 5)

	testing.SetRealm(stakerUserRealm)
	sr.UnStakeToken(cross(cur), 1)

	ufmt.Printf("[EXPECTED] position left uncollected: %t\n", sr.HasUnstakedPosition(1))
}

func restakeRejected(cur realm) {
	testing.SetRealm(stakerUserRealm)
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(1))

	var t *testing.T
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-024]", func() {
		println("[EXPECTED] staking a position that still owes rewards is refused")
		sr.StakeToken(cross(cur), 1, "")
	})
}

func collectEmissionOnly(cur realm) {
	testing.SetRealm(stakerUserRealm)

	before := gns.BalanceOf(stakerUserAddr)
	sr.CollectEmissionReward(cross(cur), 1)

	ufmt.Printf("[EXPECTED] the emission reward was paid: %t\n", gns.BalanceOf(stakerUserAddr) > before)
	ufmt.Printf("[EXPECTED] the checkpoint still owes the incentive: %t\n", sr.HasUnstakedPosition(1))
}

func collectIncentiveOnly(cur realm) {
	testing.SetRealm(stakerUserRealm)

	before := gns.BalanceOf(stakerUserAddr)
	sr.CollectExternalIncentiveReward(cross(cur), 1, incentiveId)

	ufmt.Printf("[EXPECTED] the incentive reward was paid: %t\n", gns.BalanceOf(stakerUserAddr) > before)
	ufmt.Printf("[EXPECTED] the checkpoint is gone: %t\n", !sr.HasUnstakedPosition(1))
}

func restakeAccepted(cur realm) {
	testing.SetRealm(stakerUserRealm)

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross(cur), 1, "")

	ufmt.Printf("[EXPECTED] position is staked again: %t\n", sr.IsStaked(1))
}

func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Create an incentive and stake against it
// [INFO] staked position 1 against the incentive
//
// [SCENARIO] 2. Unstake without collecting
// [EXPECTED] position left uncollected: true
//
// [SCENARIO] 3. Staking again is refused while rewards are uncollected
// [EXPECTED] staking a position that still owes rewards is refused
//
// [SCENARIO] 4. Collect the emission reward on its own
// [EXPECTED] the emission reward was paid: true
// [EXPECTED] the checkpoint still owes the incentive: true
//
// [SCENARIO] 5. Collect the incentive reward on its own
// [EXPECTED] the incentive reward was paid: true
// [EXPECTED] the checkpoint is gone: true
//
// [SCENARIO] 6. The position can be staked again
// [EXPECTED] position is staked again: true
