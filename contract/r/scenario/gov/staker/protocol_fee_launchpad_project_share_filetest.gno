// PKGPATH: gno.land/r/gnoswap/v1/main

// a launchpad project wallet shares fees with delegators through the same epochs
//
// Hand check:
//   epoch 1: alice 1_000_000
//   epoch 2: project wallet 1_000_000 via launchpad (total 2_000_000)
//   fee 2_000_000 -> +1 per stake -> 1_000_000 each
//   epoch 3: launchpad removes the project stake (total 1_000_000)
//   fee 3_000_000 -> +3 per stake -> alice 3_000_000
//   launchpad collects for the project: 1_000_000; alice: 4_000_000.
package main

import (
	"chain/runtime"
	"testing"

	prbac "gno.land/p/gnoswap/rbac/v1"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"

	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

const (
	barPath = "gno.land/r/onbloc/bar.BAR"
	quxPath = "gno.land/r/onbloc/qux.QUX"
)

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	stakerAddr      = access.MustGetAddress(prbac.ROLE_STAKER.String())
	stakerRealm     = testing.NewUserRealm(stakerAddr)
	protocolFeeAddr = access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	govStakerAddr   = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	devOpsAddr      = access.MustGetAddress(prbac.ROLE_DEVOPS.String())
	launchpadAddr   = access.MustGetAddress(prbac.ROLE_LAUNCHPAD.String())
	launchpadRealm  = testing.NewUserRealm(launchpadAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)
	bobAddr    = testutils.TestAddress("bob")
	bobRealm   = testing.NewUserRealm(bobAddr)
	carolAddr  = testutils.TestAddress("carol")
	carolRealm = testing.NewUserRealm(carolAddr)
)

func main(cur realm) {
	println("[SCENARIO] 1. alice delegates, the launchpad stakes for a project wallet")
	delegate(cur, aliceRealm, aliceAddr, 1_000_000)
	testing.SetRealm(launchpadRealm)
	staker.SetAmountByProjectWallet(cross(cur), carolAddr, 1_000_000, true)
	ufmt.Printf("[INFO] project wallet staked, epoch %d, totalStaked %d\n", protocol_fee.GetAccrualEpoch(), staker.GetTotalDelegated())
	fee(cur, barPath, 2_000_000)
	println()

	println("[SCENARIO] 2. the launchpad removes the project stake, another fee arrives")
	testing.SetRealm(launchpadRealm)
	staker.SetAmountByProjectWallet(cross(cur), carolAddr, 1_000_000, false)
	ufmt.Printf("[INFO] project wallet unstaked, epoch %d, totalStaked %d\n", protocol_fee.GetAccrualEpoch(), staker.GetTotalDelegated())
	fee(cur, barPath, 3_000_000)
	println()

	println("[SCENARIO] 3. the launchpad collects for the project, alice collects for herself")
	_, projectFees, _ := staker.GetClaimableRewardByLaunchpad(carolAddr)
	ufmt.Printf("[EXPECTED] project claimable BAR: %d\n", projectFees[barPath])
	testing.SetRealm(launchpadRealm)
	staker.CollectRewardFromLaunchPad(cross(cur), carolAddr)
	report("project", carolAddr)
	collectAll(cur, "alice", aliceRealm, aliceAddr)
	residue()
}

// fee routes amount of tokenPath into the protocol fee realm as a collected fee.
func fee(cur realm, tokenPath string, amount int64) {
	testing.SetRealm(adminRealm)
	if tokenPath == barPath {
		bar.Transfer(cross(cur), stakerAddr, amount)
	} else {
		qux.Transfer(cross(cur), stakerAddr, amount)
	}

	testing.SetRealm(stakerRealm)
	if tokenPath == barPath {
		bar.Approve(cross(cur), protocolFeeAddr, amount)
	} else {
		qux.Approve(cross(cur), protocolFeeAddr, amount)
	}
	protocol_fee.AddToProtocolFee(cross(cur), tokenPath, amount)
	ufmt.Printf("[INFO] fee %d %s at accrual epoch %d, totalStaked %d\n", amount, symbol(tokenPath), protocol_fee.GetAccrualEpoch(), staker.GetTotalDelegated())
}

// delegate funds the delegator with GNS and delegates amount to itself.
func delegate(cur realm, delegatorRealm runtime.Realm, delegator address, amount int64) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), delegator, amount)

	testing.SetRealm(delegatorRealm)
	gns.Approve(cross(cur), govStakerAddr, amount)
	staker.Delegate(cross(cur), delegator, amount, "")
	ufmt.Printf("[INFO] delegated %d, epoch %d, totalStaked %d\n", amount, protocol_fee.GetAccrualEpoch(), staker.GetTotalDelegated())
}

func undelegate(cur realm, delegatorRealm runtime.Realm, delegator address, amount int64) {
	testing.SetRealm(delegatorRealm)
	staker.Undelegate(cross(cur), delegator, amount)
	ufmt.Printf("[INFO] undelegated %d, epoch %d, totalStaked %d\n", amount, protocol_fee.GetAccrualEpoch(), staker.GetTotalDelegated())
}

func collectAll(cur realm, name string, userRealm runtime.Realm, user address) {
	testing.SetRealm(userRealm)
	staker.CollectReward(cross(cur))
	report(name, user)
}

func collectToken(cur realm, name string, userRealm runtime.Realm, user address, tokenPath string) {
	testing.SetRealm(userRealm)
	staker.CollectProtocolFeeReward(cross(cur), tokenPath)
	report(name, user)
}

func claimable(name string, user address) {
	_, fees, _ := staker.GetClaimableRewardByAddress(user)
	ufmt.Printf("[EXPECTED] %s claimable BAR: %d, QUX: %d\n", name, fees[barPath], fees[quxPath])
}

func report(name string, user address) {
	ufmt.Printf("[EXPECTED] %s BAR balance: %d, QUX balance: %d\n", name, bar.BalanceOf(user), qux.BalanceOf(user))
}

func residue() {
	ufmt.Printf("[EXPECTED] gov/staker BAR residue: %d, QUX residue: %d\n", bar.BalanceOf(govStakerAddr), qux.BalanceOf(govStakerAddr))
}

func symbol(tokenPath string) string {
	if tokenPath == barPath {
		return "BAR"
	}
	return "QUX"
}

// Output:
// [SCENARIO] 1. alice delegates, the launchpad stakes for a project wallet
// [INFO] delegated 1000000, epoch 1, totalStaked 1000000
// [INFO] project wallet staked, epoch 2, totalStaked 1000000
// [INFO] fee 2000000 BAR at accrual epoch 2, totalStaked 1000000
//
// [SCENARIO] 2. the launchpad removes the project stake, another fee arrives
// [INFO] project wallet unstaked, epoch 3, totalStaked 1000000
// [INFO] fee 3000000 BAR at accrual epoch 3, totalStaked 1000000
//
// [SCENARIO] 3. the launchpad collects for the project, alice collects for herself
// [EXPECTED] project claimable BAR: 1000000
// [EXPECTED] project BAR balance: 1000000, QUX balance: 0
// [EXPECTED] alice BAR balance: 4000000, QUX balance: 0
// [EXPECTED] gov/staker BAR residue: 0, QUX residue: 0
