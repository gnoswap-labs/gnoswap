// PKGPATH: gno.land/r/gnoswap/v1/main

// A checkpoint settles under the unstaking fee in force at its exit, not at its collect.
//
// A staker unstakes while the fee is zero. Governance then raises the fee before anyone collects.
// The checkpoint's window closed under the old rate, and its collect is permissionless, so the new
// rate must not apply retroactively: the staker receives the full quoted amount with no fee cut,
// while a position that is still staked settles under the live rate.

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath/v1"
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

	exitedAddr  = testutils.TestAddress("exitedStaker")
	exitedRealm = testing.NewUserRealm(exitedAddr)

	stayingAddr  = testutils.TestAddress("stayingStaker")
	stayingRealm = testing.NewUserRealm(stayingAddr)

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

	exitedQuote int64
)

func main(cur realm) {
	println("[SCENARIO] 1. Create a BAR incentive and stake two positions against it")
	setup(cur)

	println()
	println("[SCENARIO] 2. One staker unstakes without collecting while the fee is zero")
	unstakeAtZeroFee(cur)

	println()
	println("[SCENARIO] 3. The fee is raised to 10% before anyone collects")
	raiseFee(cur)

	println()
	println("[SCENARIO] 4. The checkpoint settles fee-free, the staked position pays the live fee")
	collectBoth(cur)
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)

	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	for _, addr := range []address{exitedAddr, stayingAddr} {
		bar.Transfer(cross(cur), addr, 10000)
		qux.Transfer(cross(cur), addr, 10000)
	}
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

	for _, addr := range []address{exitedAddr, stayingAddr} {
		testing.SetRealm(testing.NewUserRealm(addr))
		bar.Approve(cross(cur), poolAddr, maxInt64)
		qux.Approve(cross(cur), poolAddr, maxInt64)

		positionId, _, _, _ := pn.Mint(
			cross(cur), barPath, quxPath, fee100,
			int32(-100), int32(100), "1000", "1000", "1", "1",
			maxTimeout, addr, "",
		)

		gnft.Approve(cross(cur), stakerAddr, positionIdFrom(positionId))
		sr.StakeToken(cross(cur), positionId, "")

		ufmt.Printf("[INFO] staked position %d against the incentive\n", positionId)
	}
}

func unstakeAtZeroFee(cur realm) {
	testing.SkipHeights(30 * 24 * 60 * 60 / 5)

	testing.SetRealm(exitedRealm)
	sr.UnStakeToken(cross(cur), 1)

	exitedQuote, _ = sr.CollectableExternalIncentiveReward(1, incentiveId)

	ufmt.Printf("[EXPECTED] position 1 left uncollected: %t\n", sr.HasUnstakedPosition(1))
	ufmt.Printf("[EXPECTED] the checkpoint quotes a positive BAR reward: %t\n", exitedQuote > 0)
}

func raiseFee(cur realm) {
	testing.SetRealm(adminRealm)
	sr.SetUnStakingFee(cross(cur), 1000)

	ufmt.Printf("[INFO] unstaking fee is now %d bps\n", sr.GetUnstakingFee())
}

func collectBoth(cur realm) {
	// A third party settles the checkpoint; the exited staker receives the whole quote.
	testing.SetRealm(creatorRealm)
	exitedBefore := bar.BalanceOf(exitedAddr)
	sr.CollectExternalIncentiveReward(cross(cur), 1, incentiveId)
	exitedPaid := bar.BalanceOf(exitedAddr) - exitedBefore

	sr.CollectEmissionReward(cross(cur), 1)

	ufmt.Printf("[EXPECTED] the exited staker received the full quote with no fee: %t\n", exitedPaid == exitedQuote)
	ufmt.Printf("[EXPECTED] the checkpoint is gone: %t\n", !sr.HasUnstakedPosition(1))

	// The position that stayed staked settles at the live 10% rate.
	stayingQuote, _ := sr.CollectableExternalIncentiveReward(2, incentiveId)

	testing.SetRealm(stayingRealm)
	stayingBefore := bar.BalanceOf(stayingAddr)
	sr.CollectExternalIncentiveReward(cross(cur), 2, incentiveId)
	stayingPaid := bar.BalanceOf(stayingAddr) - stayingBefore

	ufmt.Printf("[EXPECTED] the staying staker paid the live fee: %t\n", stayingPaid == stayingQuote-stayingQuote*1000/10000)
}

func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Create a BAR incentive and stake two positions against it
// [INFO] staked position 1 against the incentive
// [INFO] staked position 2 against the incentive
//
// [SCENARIO] 2. One staker unstakes without collecting while the fee is zero
// [EXPECTED] position 1 left uncollected: true
// [EXPECTED] the checkpoint quotes a positive BAR reward: true
//
// [SCENARIO] 3. The fee is raised to 10% before anyone collects
// [INFO] unstaking fee is now 1000 bps
//
// [SCENARIO] 4. The checkpoint settles fee-free, the staked position pays the live fee
// [EXPECTED] the exited staker received the full quote with no fee: true
// [EXPECTED] the checkpoint is gone: true
// [EXPECTED] the staying staker paid the live fee: true
