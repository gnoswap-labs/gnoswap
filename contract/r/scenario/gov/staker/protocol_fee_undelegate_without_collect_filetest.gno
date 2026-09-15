// PKGPATH: gno.land/r/gnoswap/v1/main

// undelegate never folds fees; the share earned before leaving is paid on a later collect
//
// Hand check:
//   epoch 1: alice 1_000_000            fee 2_000_000 -> +2 per stake -> alice 2_000_000
//   epoch 2: alice leaves (0 staked)     fee 5_000_000 -> nobody to credit, dropped
//   epoch 3: bob 2_000_000               fee 4_000_000 -> +2 per stake -> bob 4_000_000
//   bob collects first and folds every bucket; alice then collects 2_000_000.
//   residue = the dropped 5_000_000.
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
	println("[SCENARIO] 1. alice delegates and a fee arrives")
	delegate(cur, aliceRealm, aliceAddr, 1_000_000)
	fee(cur, barPath, 2_000_000)
	println()

	println("[SCENARIO] 2. alice undelegates everything without collecting")
	undelegate(cur, aliceRealm, aliceAddr, 1_000_000)
	ufmt.Printf("[EXPECTED] BAR still pending on protocol_fee: %t\n", len(protocol_fee.GetAccrualPendingTokens()) == 1)
	ufmt.Printf("[EXPECTED] folded BAR amount after undelegate: %d\n", staker.GetProtocolFeeAmount(barPath))
	claimable("alice", aliceAddr)
	println()

	println("[SCENARIO] 3. a fee arrives while nobody is staked")
	fee(cur, barPath, 5_000_000)
	println()

	println("[SCENARIO] 4. bob delegates, a fee arrives, bob collects and folds everything")
	delegate(cur, bobRealm, bobAddr, 2_000_000)
	fee(cur, barPath, 4_000_000)
	collectAll(cur, "bob", bobRealm, bobAddr)
	ufmt.Printf("[EXPECTED] folded BAR amount: %d\n", staker.GetProtocolFeeAmount(barPath))
	println()

	println("[SCENARIO] 5. alice collects what she earned before leaving")
	claimable("alice", aliceAddr)
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
// [SCENARIO] 1. alice delegates and a fee arrives
// [INFO] delegated 1000000, epoch 1, totalStaked 1000000
// [INFO] fee 2000000 BAR at accrual epoch 1, totalStaked 1000000
//
// [SCENARIO] 2. alice undelegates everything without collecting
// [INFO] undelegated 1000000, epoch 2, totalStaked 0
// [EXPECTED] BAR still pending on protocol_fee: true
// [EXPECTED] folded BAR amount after undelegate: 0
// [EXPECTED] alice claimable BAR: 2000000, QUX: 0
//
// [SCENARIO] 3. a fee arrives while nobody is staked
// [INFO] fee 5000000 BAR at accrual epoch 2, totalStaked 0
//
// [SCENARIO] 4. bob delegates, a fee arrives, bob collects and folds everything
// [INFO] delegated 2000000, epoch 3, totalStaked 2000000
// [INFO] fee 4000000 BAR at accrual epoch 3, totalStaked 2000000
// [EXPECTED] bob BAR balance: 4000000, QUX balance: 0
// [EXPECTED] folded BAR amount: 11000000
//
// [SCENARIO] 5. alice collects what she earned before leaving
// [EXPECTED] alice claimable BAR: 2000000, QUX: 0
// [EXPECTED] alice BAR balance: 2000000, QUX balance: 0
// [EXPECTED] gov/staker BAR residue: 5000000, QUX residue: 0
