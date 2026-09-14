// PKGPATH: gno.land/r/gnoswap/v1/main

// The reward quote getters follow a position onto its exit checkpoint.
//
// CollectableEmissionReward and CollectableExternalIncentiveReward answer for a position that was
// unstaked without collecting: the quote is frozen at the exit, does not drift while blocks pass,
// matches what the collect then pays, drops to zero once each source is collected, and only
// reports a missing deposit once the checkpoint itself is gone.

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	"gno.land/r/gnoswap/scenarioutils"

	"gno.land/p/nt/grc721/v0"
	testutils "gno.land/p/nt/testutils/v0"
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

	stakerUserAddr  = testutils.TestAddress("quotedStaker")
	stakerUserRealm = testing.NewUserRealm(stakerUserAddr)

	creatorAddr  = testutils.TestAddress("incentiveCreator")
	creatorRealm = testing.NewUserRealm(creatorAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	quxPath = "gno.land/r/onbloc/qux.QUX"

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	incentiveDuration int64 = 90 * 24 * 60 * 60
	rewardAmount      int64 = 1_500_000_000

	incentiveId string

	stakedEmission, stakedIncentive int64
	exitEmission, exitIncentive     int64
)

func main(cur realm) {
	println("[SCENARIO] 1. Create a BAR incentive and stake against it")
	setup(cur)

	println()
	println("[SCENARIO] 2. Quote while staked, then unstake without collecting")
	quoteAndUnstake(cur)

	println()
	println("[SCENARIO] 3. The quote is frozen at the exit while blocks pass")
	quoteStaysFrozen(cur)

	println()
	println("[SCENARIO] 4. The collect pays exactly the quote, and the quote drops to zero per source")
	collectAndRequote(cur)

	println()
	println("[SCENARIO] 5. Once the checkpoint is gone the quote reports a missing deposit")
	quoteAfterClear(cur)
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)

	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	bar.Transfer(cross(cur), stakerUserAddr, 10000)
	qux.Transfer(cross(cur), stakerUserAddr, 10000)
	bar.Transfer(cross(cur), creatorAddr, rewardAmount)
	gns.Transfer(cross(cur), creatorAddr, 100_000_000_000)

	pl.CreatePool(cross(cur), barPath, quxPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross(cur), poolPath, 1)

	testing.SetRealm(creatorRealm)
	bar.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	createdAt := time.Now().Unix()
	startTime := ((createdAt / 86400) + 2) * 86400
	incentiveId = ufmt.Sprintf("%s:%d:%d", creatorAddr, createdAt, 1)

	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, rewardAmount, startTime, startTime+incentiveDuration)

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

func quoteAndUnstake(cur realm) {
	testing.SkipHeights(30 * 24 * 60 * 60 / 5)

	stakedEmission, _ = sr.CollectableEmissionReward(1)
	stakedIncentive, _ = sr.CollectableExternalIncentiveReward(1, incentiveId)

	testing.SetRealm(stakerUserRealm)
	sr.UnStakeToken(cross(cur), 1)

	var errEmission, errIncentive error
	exitEmission, errEmission = sr.CollectableEmissionReward(1)
	exitIncentive, errIncentive = sr.CollectableExternalIncentiveReward(1, incentiveId)

	ufmt.Printf("[EXPECTED] both quotes were positive while staked: %t\n", stakedEmission > 0 && stakedIncentive > 0)
	ufmt.Printf("[EXPECTED] both quotes still answer after the unstake: %t\n", errEmission == nil && errIncentive == nil)
	ufmt.Printf("[EXPECTED] the exit quotes equal the staked quotes of the same block: %t\n",
		exitEmission == stakedEmission && exitIncentive == stakedIncentive)
}

func quoteStaysFrozen(cur realm) {
	testing.SkipHeights(500)

	laterEmission, _ := sr.CollectableEmissionReward(1)
	laterIncentive, _ := sr.CollectableExternalIncentiveReward(1, incentiveId)

	ufmt.Printf("[EXPECTED] the emission quote did not move: %t\n", laterEmission == exitEmission)
	ufmt.Printf("[EXPECTED] the incentive quote did not move: %t\n", laterIncentive == exitIncentive)
}

func collectAndRequote(cur realm) {
	testing.SetRealm(stakerUserRealm)

	gnsBefore := gns.BalanceOf(stakerUserAddr)
	sr.CollectEmissionReward(cross(cur), 1)
	paidEmission := gns.BalanceOf(stakerUserAddr) - gnsBefore

	emissionAfter, _ := sr.CollectableEmissionReward(1)
	incentiveStill, _ := sr.CollectableExternalIncentiveReward(1, incentiveId)

	ufmt.Printf("[EXPECTED] the emission collect paid the quote: %t\n", paidEmission == exitEmission)
	ufmt.Printf("[EXPECTED] the emission quote is now zero: %t\n", emissionAfter == 0)
	ufmt.Printf("[EXPECTED] the incentive quote is untouched by the emission collect: %t\n", incentiveStill == exitIncentive)

	barBefore := bar.BalanceOf(stakerUserAddr)
	sr.CollectExternalIncentiveReward(cross(cur), 1, incentiveId)
	paidIncentive := bar.BalanceOf(stakerUserAddr) - barBefore

	ufmt.Printf("[EXPECTED] the incentive collect paid the quote: %t\n", paidIncentive == exitIncentive)
	ufmt.Printf("[EXPECTED] the checkpoint is gone: %t\n", !sr.HasUnstakedPosition(1))
}

func quoteAfterClear(cur realm) {
	_, errEmission := sr.CollectableEmissionReward(1)
	_, errIncentive := sr.CollectableExternalIncentiveReward(1, incentiveId)

	ufmt.Printf("[EXPECTED] the emission quote reports a missing deposit: %t\n", errEmission != nil)
	ufmt.Printf("[EXPECTED] the incentive quote reports a missing deposit: %t\n", errIncentive != nil)
}

func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Create a BAR incentive and stake against it
// [INFO] staked position 1 against the incentive
//
// [SCENARIO] 2. Quote while staked, then unstake without collecting
// [EXPECTED] both quotes were positive while staked: true
// [EXPECTED] both quotes still answer after the unstake: true
// [EXPECTED] the exit quotes equal the staked quotes of the same block: true
//
// [SCENARIO] 3. The quote is frozen at the exit while blocks pass
// [EXPECTED] the emission quote did not move: true
// [EXPECTED] the incentive quote did not move: true
//
// [SCENARIO] 4. The collect pays exactly the quote, and the quote drops to zero per source
// [EXPECTED] the emission collect paid the quote: true
// [EXPECTED] the emission quote is now zero: true
// [EXPECTED] the incentive quote is untouched by the emission collect: true
// [EXPECTED] the incentive collect paid the quote: true
// [EXPECTED] the checkpoint is gone: true
//
// [SCENARIO] 5. Once the checkpoint is gone the quote reports a missing deposit
// [EXPECTED] the emission quote reports a missing deposit: true
// [EXPECTED] the incentive quote reports a missing deposit: true
