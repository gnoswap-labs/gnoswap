// PKGPATH: gno.land/r/gnoswap/v1/main

// governance proposal execute - staker CancelExternalIncentive via governance
//
// CancelExternalIncentive accepts admin or governance, so the governance half of
// that check needs a real execution path. This drives the parameter-change
// registry entry end to end: a pending external incentive is created, a proposal
// to cancel it passes, and executing the proposal refunds the reward tokens plus
// the GNS deposit to the refund address and removes the incentive.
//
// The default governance schedule takes longer than the maximum permitted
// incentive lead time. This scenario first adopts a short schedule, then
// exercises cancellation while the incentive remains pending.

package main

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"

	govStaker "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	pl "gno.land/r/gnoswap/pool"
	_ "gno.land/r/gnoswap/pool/v1"
	sr "gno.land/r/gnoswap/staker"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/qux"
)

var (
	adminAddr     = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	stakerAddr    = access.MustGetAddress(prbac.ROLE_STAKER.String())

	refundeeAddr = testutils.TestAddress("refundee")

	currentBlockTime = int64(2)
)

const (
	barPath = "gno.land/r/onbloc/bar.BAR"
	quxPath = "gno.land/r/onbloc/qux.QUX"

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"

	fee100 uint32 = 100

	maxInt64 int64 = 9223372036854775807

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60
	REWARD_AMOUNT      int64 = 1_000_000_000
)

var (
	incentiveID             string
	creatorBarBeforeExecute int64
	creatorGnsBeforeExecute int64
)

func main(cur realm) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	config, err := governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}

	println("[SCENARIO] 1. Delegate gns to admin")
	delegateGnsToAdmin(cur)
	println()

	println("[SCENARIO] 2. Skip voting smoothing duration")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	ufmt.Printf("[INFO] current height: %d\n", runtime.ChainHeight())
	println()

	println("[SCENARIO] 3. Adopt a short governance schedule")
	proposalID := proposeShortVotingSchedule(cur)
	voteAndExecuteShortSchedule(cur, proposalID, config)
	config, err = governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}
	println()

	println("[SCENARIO] 4. Create pool and a pending external incentive")
	createPoolAndIncentive(cur)
	println()

	println("[SCENARIO] 5. Propose CancelExternalIncentive")
	proposalID = proposeCancelExternalIncentive(cur)
	println()

	println("[SCENARIO] 6. Vote and execute the proposal")
	voteAndExecute(cur, proposalID, config)
	println()

	println("[SCENARIO] 7. Verify the refund and the removal")
	verifyCancelled(cur)
	println()
}

func delegateGnsToAdmin(cur realm) {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	gns.Approve(cross(cur), govStakerAddr, delegatedAmount)
	govStaker.Delegate(cross(cur), adminAddr, delegatedAmount, "")

	ufmt.Printf("[INFO] gns delegated to %s (amount: %d)\n", adminAddr.String(), delegatedAmount)
}

func createPoolAndIncentive(cur realm) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	pl.SetPoolCreationFee(cross(cur), 0)
	pl.CreatePool(
		cross(cur),
		barPath,
		quxPath,
		fee100,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	bar.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	createTimestamp := time.Now().Unix()

	// The first eligible midnight is at least one day after creation; this
	// latest allowed start leaves the short governance proposal time to cancel.
	startTimestamp := ((createTimestamp / 86400) + 8) * 86400
	endTimestamp := startTimestamp + INCENTIVE_DURATION

	incentiveID = ufmt.Sprintf("%s:%d:%d", adminAddr, createTimestamp, 1)
	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, REWARD_AMOUNT, startTimestamp, endTimestamp)

	incentives, err := sr.GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[INFO] pending incentives for pool: %d\n", len(incentives))
}

func proposeShortVotingSchedule(cur realm) int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	return governance.ProposeParameterChange(
		cross(cur),
		"governance",
		"Adopt a short governance schedule",
		1,
		"gno.land/r/gnoswap/gov/governance*EXE*Reconfigure*EXE*8640,60480,86400,50,1000000000,0,2592000",
	)
}

func voteAndExecuteShortSchedule(cur realm, proposalID int64, config governance.Config) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	testing.SkipHeights(int64(config.VotingStartDelay)/currentBlockTime + 1)
	governance.Vote(cross(cur), proposalID, true)
	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)
	governance.Execute(cross(cur), proposalID)
}

func proposeCancelExternalIncentive(cur realm) int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	params := poolPath + "," + incentiveID
	proposalID := governance.ProposeParameterChange(
		cross(cur),
		"staker",
		"Cancel the pending BAR external incentive",
		1,
		"gno.land/r/gnoswap/staker*EXE*CancelExternalIncentive*EXE*"+params,
	)

	ufmt.Printf("[INFO] CancelExternalIncentive Proposal ID: %d\n", proposalID)
	return proposalID
}

func voteAndExecute(cur realm, proposalID int64, config governance.Config) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	testing.SkipHeights(int64(config.VotingStartDelay)/currentBlockTime + 1)
	governance.Vote(cross(cur), proposalID, true)
	ufmt.Printf("[INFO] Voted YES for proposal %d\n", proposalID)

	testing.SkipHeights(int64(config.VotingPeriod) / currentBlockTime)

	// The cancel refunds to the incentive creator (admin); capture its balance
	// right before execution so the delta isolates the refund.
	creatorBarBeforeExecute = bar.BalanceOf(adminAddr)
	creatorGnsBeforeExecute = gns.BalanceOf(adminAddr)
	governance.Execute(cross(cur), proposalID)
	ufmt.Printf("[EXPECTED] Proposal %d executed successfully\n", proposalID)
}

func verifyCancelled(cur realm) {
	ufmt.Printf("[EXPECTED] creator BAR refund delta: %d\n", bar.BalanceOf(adminAddr)-creatorBarBeforeExecute)
	ufmt.Printf("[EXPECTED] creator GNS refund delta: %d\n", gns.BalanceOf(adminAddr)-creatorGnsBeforeExecute)
	incentives, err := sr.GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		panic(err)
	}
	ufmt.Printf("[EXPECTED] remaining incentives for pool: %d\n", len(incentives))
}

// Output:
// [SCENARIO] 1. Delegate gns to admin
// [INFO] gns delegated to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 (amount: 1000000000)
//
// [SCENARIO] 2. Skip voting smoothing duration
// [INFO] current height: 43323
//
// [SCENARIO] 3. Adopt a short governance schedule
//
// [SCENARIO] 4. Create pool and a pending external incentive
// [INFO] pending incentives for pool: 1
//
// [SCENARIO] 5. Propose CancelExternalIncentive
// [INFO] CancelExternalIncentive Proposal ID: 2
//
// [SCENARIO] 6. Vote and execute the proposal
// [INFO] Voted YES for proposal 2
// [EXPECTED] Proposal 2 executed successfully
//
// [SCENARIO] 7. Verify the refund and the removal
// [EXPECTED] creator BAR refund delta: 1000000000
// [EXPECTED] creator GNS refund delta: 100000000000
// [EXPECTED] remaining incentives for pool: 0
//
