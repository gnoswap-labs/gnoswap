// PKGPATH: gno.land/r/gnoswap/v1/main

// rounding: shares are floored per collect and the sub-unit remainder is carried
//
// alice 1_000_000, bob 2_000_000 (total 3_000_000), fee 1_000_000 twice.
// Per-stake growth is 1/3, floored in X128. Hand check:
//
//	after fee 1: alice 333_333.33.. -> 333_333, bob 666_666.66.. -> 666_666 (sum 999_999)
//	after fee 2 (cumulative): alice 666_666.66.. -> 666_666 (+333_333),
//	                          bob 1_333_333.33.. -> 1_333_333 (+666_667)
//	paid 1_999_999 of 2_000_000; the last unit stays in gov/staker as carried fractions.
package main

import (
	"chain/runtime"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
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
	println("[SCENARIO] 1. alice 1M and bob 2M delegate, a fee of 1M arrives")
	delegate(cur, aliceRealm, aliceAddr, 1_000_000)
	delegate(cur, bobRealm, bobAddr, 2_000_000)
	fee(cur, barPath, 1_000_000)
	claimable("alice", aliceAddr)
	claimable("bob", bobAddr)
	collectAll(cur, "alice", aliceRealm, aliceAddr)
	collectAll(cur, "bob", bobRealm, bobAddr)
	residue()
	println()

	println("[SCENARIO] 2. a second fee of 1M, the carried fractions top up the payouts")
	testing.SkipHeights(1)
	fee(cur, barPath, 1_000_000)
	claimable("alice", aliceAddr)
	claimable("bob", bobAddr)
	collectAll(cur, "alice", aliceRealm, aliceAddr)
	collectAll(cur, "bob", bobRealm, bobAddr)
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
// [SCENARIO] 1. alice 1M and bob 2M delegate, a fee of 1M arrives
// [INFO] delegated 1000000, epoch 1, totalStaked 1000000
// [INFO] delegated 2000000, epoch 2, totalStaked 3000000
// [INFO] fee 1000000 BAR at accrual epoch 2, totalStaked 3000000
// [EXPECTED] alice claimable BAR: 333333, QUX: 0
// [EXPECTED] bob claimable BAR: 666666, QUX: 0
// [EXPECTED] alice BAR balance: 333333, QUX balance: 0
// [EXPECTED] bob BAR balance: 666666, QUX balance: 0
// [EXPECTED] gov/staker BAR residue: 1, QUX residue: 0
//
// [SCENARIO] 2. a second fee of 1M, the carried fractions top up the payouts
// [INFO] fee 1000000 BAR at accrual epoch 2, totalStaked 3000000
// [EXPECTED] alice claimable BAR: 333333, QUX: 0
// [EXPECTED] bob claimable BAR: 666667, QUX: 0
// [EXPECTED] alice BAR balance: 666666, QUX balance: 0
// [EXPECTED] bob BAR balance: 1333333, QUX balance: 0
// [EXPECTED] gov/staker BAR residue: 1, QUX residue: 0
