// PKGPATH: gno.land/r/gnoswap/v1/main

// three stakers, interleaved joins and exits, one collect each at different times
//
// Hand check (per-stake growth = fee / total, whole numbers):
//   e1 alice 1_000_000 (1_000_000)          fee 1_000_000 -> +1 -> a 1_000_000
//   e2 bob   2_000_000 (3_000_000)          fee 6_000_000 -> +2 -> a 2_000_000, b 4_000_000
//   bob collects here: 4_000_000 (alice keeps accruing)
//   e3 carol 3_000_000 (6_000_000)          fee 6_000_000 -> +1 -> a 1_000_000, b 2_000_000, c 3_000_000
//   e4 alice leaves    (5_000_000)          fee 5_000_000 -> +1 -> b 2_000_000, c 3_000_000
//   alice collects: 4_000_000; bob: 4_000_000 more (8_000_000 total); carol: 6_000_000.
//   sum 18_000_000 = fees, residue 0.
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
	println("[SCENARIO] 1. alice, then bob; bob collects early")
	delegate(cur, aliceRealm, aliceAddr, 1_000_000)
	fee(cur, barPath, 1_000_000)
	delegate(cur, bobRealm, bobAddr, 2_000_000)
	fee(cur, barPath, 6_000_000)
	collectAll(cur, "bob", bobRealm, bobAddr)
	println()

	println("[SCENARIO] 2. carol joins, alice leaves")
	delegate(cur, carolRealm, carolAddr, 3_000_000)
	fee(cur, barPath, 6_000_000)
	undelegate(cur, aliceRealm, aliceAddr, 1_000_000)
	fee(cur, barPath, 5_000_000)
	println()

	println("[SCENARIO] 3. everyone collects")
	claimable("alice", aliceAddr)
	claimable("bob", bobAddr)
	claimable("carol", carolAddr)
	testing.SkipHeights(1)
	collectAll(cur, "alice", aliceRealm, aliceAddr)
	collectAll(cur, "bob", bobRealm, bobAddr)
	collectAll(cur, "carol", carolRealm, carolAddr)
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
// [SCENARIO] 1. alice, then bob; bob collects early
// [INFO] delegated 1000000, epoch 1, totalStaked 1000000
// [INFO] fee 1000000 BAR at accrual epoch 1, totalStaked 1000000
// [INFO] delegated 2000000, epoch 2, totalStaked 3000000
// [INFO] fee 6000000 BAR at accrual epoch 2, totalStaked 3000000
// [EXPECTED] bob BAR balance: 4000000, QUX balance: 0
//
// [SCENARIO] 2. carol joins, alice leaves
// [INFO] delegated 3000000, epoch 3, totalStaked 6000000
// [INFO] fee 6000000 BAR at accrual epoch 3, totalStaked 6000000
// [INFO] undelegated 1000000, epoch 4, totalStaked 5000000
// [INFO] fee 5000000 BAR at accrual epoch 4, totalStaked 5000000
//
// [SCENARIO] 3. everyone collects
// [EXPECTED] alice claimable BAR: 4000000, QUX: 0
// [EXPECTED] bob claimable BAR: 4000000, QUX: 0
// [EXPECTED] carol claimable BAR: 6000000, QUX: 0
// [EXPECTED] alice BAR balance: 4000000, QUX balance: 0
// [EXPECTED] bob BAR balance: 8000000, QUX balance: 0
// [EXPECTED] carol BAR balance: 6000000, QUX balance: 0
// [EXPECTED] gov/staker BAR residue: 0, QUX residue: 0
