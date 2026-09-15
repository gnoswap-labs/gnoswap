// PKGPATH: gno.land/r/gnoswap/v1/main

// protocol fee epoch attribution across stake changes
//
// Fees are never folded on a stake change. Three epochs with different stake
// distributions collect fees, nobody collects until the end, and every fee is still
// attributed to the distribution in force when it arrived.
//
// Hand check (per-stake growth = fee / totalStaked, chosen to be whole numbers):
//   epoch 1: alice 1_000_000            fee 1_000_000 -> +1 per stake -> alice 1_000_000
//   epoch 2: + bob 3_000_000 (4_000_000) fee 8_000_000 -> +2 per stake -> alice 2_000_000, bob 6_000_000
//   epoch 3: - alice        (3_000_000) fee 3_000_000 -> +1 per stake -> bob 3_000_000
//   alice total 3_000_000, bob total 9_000_000, sum 12_000_000 = fees, residue 0.
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
	println("[SCENARIO] 1. alice delegates, a fee arrives with alice alone")
	delegate(cur, aliceRealm, aliceAddr, 1_000_000)
	fee(cur, barPath, 1_000_000)
	println()

	println("[SCENARIO] 2. bob delegates three times as much, a fee arrives")
	delegate(cur, bobRealm, bobAddr, 3_000_000)
	fee(cur, barPath, 8_000_000)
	println()

	println("[SCENARIO] 3. alice undelegates everything, a fee arrives with bob alone")
	undelegate(cur, aliceRealm, aliceAddr, 1_000_000)
	fee(cur, barPath, 3_000_000)
	ufmt.Printf("[EXPECTED] nothing folded yet, folded BAR amount: %d\n", staker.GetProtocolFeeAmount(barPath))
	println()

	println("[SCENARIO] 4. queries report the attributed shares before any fold")
	claimable("alice", aliceAddr)
	claimable("bob", bobAddr)
	println()

	println("[SCENARIO] 5. both collect, alice after having left")
	collectAll(cur, "alice", aliceRealm, aliceAddr)
	collectAll(cur, "bob", bobRealm, bobAddr)
	ufmt.Printf("[EXPECTED] folded BAR amount: %d\n", staker.GetProtocolFeeAmount(barPath))
	residue()
	println()

	println("[SCENARIO] 6. collecting again pays nothing")
	testing.SkipHeights(1)
	collectAll(cur, "alice", aliceRealm, aliceAddr)
	collectAll(cur, "bob", bobRealm, bobAddr)
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
// [SCENARIO] 1. alice delegates, a fee arrives with alice alone
// [INFO] delegated 1000000, epoch 1, totalStaked 1000000
// [INFO] fee 1000000 BAR at accrual epoch 1, totalStaked 1000000
//
// [SCENARIO] 2. bob delegates three times as much, a fee arrives
// [INFO] delegated 3000000, epoch 2, totalStaked 4000000
// [INFO] fee 8000000 BAR at accrual epoch 2, totalStaked 4000000
//
// [SCENARIO] 3. alice undelegates everything, a fee arrives with bob alone
// [INFO] undelegated 1000000, epoch 3, totalStaked 3000000
// [INFO] fee 3000000 BAR at accrual epoch 3, totalStaked 3000000
// [EXPECTED] nothing folded yet, folded BAR amount: 0
//
// [SCENARIO] 4. queries report the attributed shares before any fold
// [EXPECTED] alice claimable BAR: 3000000, QUX: 0
// [EXPECTED] bob claimable BAR: 9000000, QUX: 0
//
// [SCENARIO] 5. both collect, alice after having left
// [EXPECTED] alice BAR balance: 3000000, QUX balance: 0
// [EXPECTED] bob BAR balance: 9000000, QUX balance: 0
// [EXPECTED] folded BAR amount: 12000000
// [EXPECTED] gov/staker BAR residue: 0, QUX residue: 0
//
// [SCENARIO] 6. collecting again pays nothing
// [EXPECTED] alice BAR balance: 3000000, QUX balance: 0
// [EXPECTED] bob BAR balance: 9000000, QUX balance: 0
