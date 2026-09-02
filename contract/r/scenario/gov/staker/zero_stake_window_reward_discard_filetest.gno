// PKGPATH: gno.land/r/gnoswap/v1/main

// zero stake window rewards are discarded by both gov/staker accumulators
//
// A window in which totalStakedAmount is 0 has nobody to credit. Both the emission and
// the protocol fee accumulator drop that window's delta and advance their cursor past it,
// so the next staker inherits nothing from before it staked. The dropped amounts stay in
// the gov/staker realm and no reward path hands them out.

package main

import (
	"chain/runtime"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	"gno.land/r/gnoswap/scenarioutils"
	"gno.land/r/onbloc/bar"

	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

const barPath = "gno.land/r/onbloc/bar.BAR"

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	stakerAddr, _      = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm        = testing.NewUserRealm(stakerAddr)
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	govStakerAddr, _   = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm     = testing.NewUserRealm(govStakerAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	bobAddr  = testutils.TestAddress("bob")
	bobRealm = testing.NewUserRealm(bobAddr)

	minAmount = int64(1_000_000)
)

func main(cur realm) {
	println("[SCENARIO] 1. Start emission with no delegator at all")
	startEmission(cur)
	println()

	// A long window (300 blocks) so its emission is clearly larger than the 100 block
	// windows the delegators are actually entitled to.
	println("[SCENARIO] 2. Fees and emission accrue over a 300 block zero stake window")
	accrue(cur, 300, 10_000)
	println()

	println("[SCENARIO] 3. Alice makes the first delegation")
	delegate(cur, aliceRealm, aliceAddr)
	reportCursors(cur)
	println()

	println("[SCENARIO] 4. Alice earns over 100 blocks, the pre-stake window is not hers")
	accrue(cur, 100, 4_000)
	reportClaimable(cur, "alice", aliceAddr)
	println()

	println("[SCENARIO] 5. Alice fully undelegates, reopening a 200 block zero stake window")
	undelegateAll(cur)
	accrue(cur, 200, 7_000)
	println()

	println("[SCENARIO] 6. Bob delegates after the window and earns over 100 blocks")
	delegate(cur, bobRealm, bobAddr)
	reportCursors(cur)
	accrue(cur, 100, 2_000)
	reportClaimable(cur, "bob", bobAddr)
	println()

	println("[SCENARIO] 7. Both collect; the discarded windows stay in the gov/staker realm")
	reportResidue(cur)
}

// startEmission routes half of the emission to gov/staker and starts distribution.
func startEmission(cur realm) {
	testing.SetRealm(adminRealm)
	emission.ChangeDistributionPct(cross(cur), 5000, 0, 0, 5000)
	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	println("[INFO] emission started with govStaker share 50%")
}

// accrue collects a protocol fee, skips blocks and mints emission, reporting how much
// reached gov/staker over the window.
func accrue(cur realm, blocks int64, feeAmount int64) {
	beforeEmission := emission.GetAccuDistributedToGovStaker()

	collectProtocolFee(cur, feeAmount)

	testing.SkipHeights(blocks)
	testing.SetRealm(adminRealm)
	emission.MintAndDistributeGns(cross(cur))

	ufmt.Printf("[INFO] totalStaked over the window: %d\n", staker.GetTotalDelegated())
	ufmt.Printf("[INFO] BAR reserved for gov/staker over the window: %d\n", feeAmount)
	ufmt.Printf("[INFO] emission reaching gov/staker over the window: %d\n",
		emission.GetAccuDistributedToGovStaker()-beforeEmission)
}

func collectProtocolFee(cur realm, amount int64) {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), stakerAddr, amount)

	testing.SetRealm(stakerRealm)
	bar.Approve(cross(cur), protocolFeeAddr, amount)
	protocol_fee.AddToProtocolFee(cross(cur), barPath, amount)

	testing.SetRealm(govStakerRealm)
	protocol_fee.DistributeProtocolFee(cross(cur))
}

func delegate(cur realm, delegatorRealm runtime.Realm, delegator address) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), delegator, minAmount)

	testing.SetRealm(delegatorRealm)
	gns.Approve(cross(cur), govStakerAddr, minAmount)
	staker.Delegate(cross(cur), delegator, minAmount, "")
	ufmt.Printf("[INFO] delegated %d GNS, totalStaked now %d\n", minAmount, staker.GetTotalDelegated())
}

func undelegateAll(cur realm) {
	testing.SetRealm(aliceRealm)
	staker.Undelegate(cross(cur), aliceAddr, minAmount)
	ufmt.Printf("[INFO] alice undelegated, totalStaked now %d\n", staker.GetTotalDelegated())
}

// reportCursors shows that both accumulators moved past the zero stake window without
// crediting anyone: their cursors caught up with the source of truth while the per-stake
// accumulators stayed where they were.
func reportCursors(cur realm) {
	ufmt.Printf("[EXPECTED] emission cursor advanced to accu: %t\n",
		staker.GetEmissionDistributedAmount() == emission.GetAccuDistributedToGovStaker())
	ufmt.Printf("[EXPECTED] protocol fee cursor advanced to accu: %t\n",
		staker.GetProtocolFeeAmount(barPath) == protocol_fee.GetAccuTransferToGovStakerByTokenPath(barPath))
}

func reportClaimable(cur realm, name string, addr address) {
	emissionReward, protocolFees, _ := staker.GetClaimableRewardByAddress(addr)
	ufmt.Printf("[EXPECTED] %s claimable emission: %d\n", name, emissionReward)
	ufmt.Printf("[EXPECTED] %s claimable BAR: %d\n", name, protocolFees[barPath])
}

// reportResidue records the accepted consequence of the discard policy: once every
// delegator has collected, the two zero stake windows are still sitting in the realm.
func reportResidue(cur realm) {
	testing.SetRealm(aliceRealm)
	staker.CollectReward(cross(cur))
	testing.SetRealm(bobRealm)
	staker.CollectReward(cross(cur))

	ufmt.Printf("[EXPECTED] alice collected BAR: %d\n", bar.BalanceOf(aliceAddr))
	ufmt.Printf("[EXPECTED] bob collected BAR: %d\n", bar.BalanceOf(bobAddr))
	ufmt.Printf("[EXPECTED] BAR ever reserved for gov/staker: %d\n",
		protocol_fee.GetAccuTransferToGovStakerByTokenPath(barPath))
	ufmt.Printf("[EXPECTED] BAR left unassignable in gov/staker: %d\n", bar.BalanceOf(govStakerAddr))
}

// Output:
// [SCENARIO] 1. Start emission with no delegator at all
// [INFO] emission started with govStaker share 50%
//
// [SCENARIO] 2. Fees and emission accrue over a 300 block zero stake window
// [INFO] totalStaked over the window: 0
// [INFO] BAR reserved for gov/staker over the window: 10000
// [INFO] emission reaching gov/staker over the window: 5351027250
//
// [SCENARIO] 3. Alice makes the first delegation
// [INFO] delegated 1000000 GNS, totalStaked now 1000000
// [EXPECTED] emission cursor advanced to accu: true
// [EXPECTED] protocol fee cursor advanced to accu: true
//
// [SCENARIO] 4. Alice earns over 100 blocks, the pre-stake window is not hers
// [INFO] totalStaked over the window: 1000000
// [INFO] BAR reserved for gov/staker over the window: 4000
// [INFO] emission reaching gov/staker over the window: 1783675750
// [EXPECTED] alice claimable emission: 1783675749
// [EXPECTED] alice claimable BAR: 3999
//
// [SCENARIO] 5. Alice fully undelegates, reopening a 200 block zero stake window
// [INFO] alice undelegated, totalStaked now 0
// [INFO] totalStaked over the window: 0
// [INFO] BAR reserved for gov/staker over the window: 7000
// [INFO] emission reaching gov/staker over the window: 3567351500
//
// [SCENARIO] 6. Bob delegates after the window and earns over 100 blocks
// [INFO] delegated 1000000 GNS, totalStaked now 1000000
// [EXPECTED] emission cursor advanced to accu: true
// [EXPECTED] protocol fee cursor advanced to accu: true
// [INFO] totalStaked over the window: 1000000
// [INFO] BAR reserved for gov/staker over the window: 2000
// [INFO] emission reaching gov/staker over the window: 1783675750
// [EXPECTED] bob claimable emission: 1783675749
// [EXPECTED] bob claimable BAR: 1999
//
// [SCENARIO] 7. Both collect; the discarded windows stay in the gov/staker realm
// [EXPECTED] alice collected BAR: 3999
// [EXPECTED] bob collected BAR: 1999
// [EXPECTED] BAR ever reserved for gov/staker: 23000
// [EXPECTED] BAR left unassignable in gov/staker: 17002
