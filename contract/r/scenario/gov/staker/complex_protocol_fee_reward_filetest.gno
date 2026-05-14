// complex protocol fee reward

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"chain/banker"
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"

	en "gno.land/r/gnoswap/emission"

	pf "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/sol"
)

var t *testing.T

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	stakerAddr  = access.MustGetAddress(prbac.ROLE_STAKER.String())
	stakerRealm = testing.NewUserRealm(stakerAddr)

	dummyAddr   = testutils.TestAddress("dummy")
	dummyRealm  = testing.NewUserRealm(dummyAddr)
	dummy2Addr  = testutils.TestAddress("dummy2")
	dummy2Realm = testing.NewUserRealm(dummy2Addr)

	minAmount = int64(1_000_000)

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	solPath = "gno.land/r/gnoswap/test_token/sol"

	wugnotPath         = "gno.land/r/gnoland/wugnot"
	wugnotAddr address = "g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"

	govStakerAddr, _ = access.GetAddress(prbac.ROLE_GOV_STAKER.String())

	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	protocolFeeV1Realm = testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1")
)

func fundAndApproveProtocolFeeCallerAtom(amount int64) {
	testing.SetRealm(adminRealm)
	atom.Transfer(cross, stakerAddr, amount)
	testing.SetRealm(stakerRealm)
	atom.Approve(cross, protocolFeeAddr, amount)
	atom.Approve(cross, protocolFeeV1Realm.Address(), amount)
}

func fundAndApproveProtocolFeeCallerSol(amount int64) {
	testing.SetRealm(adminRealm)
	sol.Transfer(cross, stakerAddr, amount)
	testing.SetRealm(stakerRealm)
	sol.Approve(cross, protocolFeeAddr, amount)
	sol.Approve(cross, protocolFeeV1Realm.Address(), amount)
}

func fundAndApproveProtocolFeeCallerWugnot(amount int64) {
	testing.SetRealm(adminRealm)
	wugnot.Transfer(cross, stakerAddr, amount)
	testing.SetRealm(stakerRealm)
	wugnot.Approve(cross, protocolFeeAddr, amount)
	wugnot.Approve(cross, protocolFeeV1Realm.Address(), amount)
}

func main() {
	println("[SCENARIO] 1. Prepare protocol fee tokens (WUGNOT, atom, sol)")
	setupTokens()
	println()

	println("[SCENARIO] 2. Admin delegates GNS to dummy2")
	delegateAdminToDummy2()
	println()

	println("[SCENARIO] 3. Dummy delegates GNS to dummy")
	delegateDummyToDummy()
	println()

	println("[SCENARIO] 4. Protocol fee deposit")
	depositProtocolFeePre()
	// Deposit must be called from main() due to AssertOriginCall frame limit
	testing.SetRealm(adminRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 10000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(chain.Coins{})
	depositProtocolFeePost()
	println()

	println("[SCENARIO] 5. Skip blocks and distribute emission/protocol fee")
	skipBlocksAndDistribute()
	println()

	println("[SCENARIO] 6. Collect rewards")
	collectRewardsByDummy()
	println()

	println("[SCENARIO] 7. Additional protocol fee deposit")
	depositProtocolFeeAdditional()
	println()

	println("[SCENARIO] 8. Collect rewards after additional protocol fee")
	collectRewardsByDummy()
	println()

	println("[SCENARIO] 9. Admin undelegates dummy2 and collects reward")
	unDelegateAndCollectRewardByAdmin()
	println()
}

func setupTokens() {
	println("[INFO] WUGNOT token issued for protocol fee")
}

func delegateAdminToDummy2() {
	testing.SetRealm(adminRealm)
	gns.Approve(cross, govStakerAddr, minAmount)
	staker.Delegate(cross, dummy2Addr, int64(minAmount), "")
	ufmt.Printf("[INFO] delegated %d GNS from admin to dummy2\n", minAmount)
}

func delegateDummyToDummy() {
	testing.SetRealm(adminRealm)
	amount := 5 * minAmount
	gns.Transfer(cross, dummyAddr, amount)

	testing.SetRealm(dummyRealm)
	gns.Approve(cross, govStakerAddr, amount)
	staker.Delegate(cross, dummyAddr, int64(amount), "")
	ufmt.Printf("[INFO] delegated %d GNS from dummy to dummy\n", amount)
}

func depositProtocolFeePre() {
	// protocol fee deposit (atom, sol, wugnot)
	testing.SetRealm(adminRealm)
	atom.Transfer(cross, stakerAddr, 1000)
	sol.Transfer(cross, stakerAddr, 2500)

	coins := chain.Coins{{"ugnot", 10000}}
	testing.IssueCoins(adminAddr, coins)
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(adminAddr, wugnotAddr, coins)
	// Deposit is done in main()
}

func depositProtocolFeePost() {
	fundAndApproveProtocolFeeCallerWugnot(10000)
	testing.SetRealm(stakerRealm)
	atom.Approve(cross, protocolFeeAddr, 1000)
	sol.Approve(cross, protocolFeeAddr, 2500)
	wugnot.Approve(cross, protocolFeeAddr, 10000)
	pf.AddToProtocolFee(cross, atomPath, 1000)
	pf.AddToProtocolFee(cross, solPath, 2500)
	pf.AddToProtocolFee(cross, wugnotPath, 10000)

	currentAtomBalance := atom.BalanceOf(protocolFeeAddr)
	currentSolBalance := sol.BalanceOf(protocolFeeAddr)
	currentWugnotBalance := wugnot.BalanceOf(protocolFeeAddr)

	ufmt.Printf("[INFO] protocol fee deposited: atom(%d), sol(%d), wugnot(%d)\n", currentAtomBalance, currentSolBalance, currentWugnotBalance)
}

func skipBlocksAndDistribute() {
	testing.SkipHeights(10)
	en.MintAndDistributeGns(cross)
	testing.SkipHeights(1)
	println("[INFO] skipped 10+1 blocks and distributed emission/protocol fee")
}

func depositProtocolFeeAdditional() {
	// additional protocol fee deposit (atom, sol)
	fundAndApproveProtocolFeeCallerAtom(2500)
	fundAndApproveProtocolFeeCallerSol(4000)
	testing.SetRealm(stakerRealm)
	atom.Approve(cross, protocolFeeAddr, 2500)
	sol.Approve(cross, protocolFeeAddr, 4000)
	pf.AddToProtocolFee(cross, atomPath, 2500)
	pf.AddToProtocolFee(cross, solPath, 4000)

	currentAtomBalance := atom.BalanceOf(protocolFeeAddr)
	currentSolBalance := sol.BalanceOf(protocolFeeAddr)
	currentWugnotBalance := wugnot.BalanceOf(protocolFeeAddr)

	ufmt.Printf("[INFO] protocol fee deposited: atom(%d), sol(%d), wugnot(%d)\n", currentAtomBalance, currentSolBalance, currentWugnotBalance)
}

func collectRewardsByDummy() {
	testing.SetOriginCaller(dummyAddr)
	testing.SkipHeights(1)

	prevAtomBalance := atom.BalanceOf(dummyAddr)
	prevSolBalance := sol.BalanceOf(dummyAddr)

	staker.CollectReward(cross)

	afterAtomBalance := atom.BalanceOf(dummyAddr)
	afterSolBalance := sol.BalanceOf(dummyAddr)

	ufmt.Printf("[INFO] collected more protocol fee reward for dummy: atom(%d), sol(%d)\n", afterAtomBalance-prevAtomBalance, afterSolBalance-prevSolBalance)
}

func unDelegateAndCollectRewardByAdmin() {
	testing.SetRealm(adminRealm)
	testing.SkipHeights(1)

	prevAtomBalance := atom.BalanceOf(adminAddr)
	prevSolBalance := sol.BalanceOf(adminAddr)

	staker.Undelegate(cross, adminAddr, int64(minAmount))
	staker.CollectReward(cross)

	afterAtomBalance := atom.BalanceOf(adminAddr)
	afterSolBalance := sol.BalanceOf(adminAddr)

	ufmt.Printf("[INFO] admin undelegated %d GNS from dummy2: atom(%d), sol(%d)\n", minAmount, afterAtomBalance-prevAtomBalance, afterSolBalance-prevSolBalance)
}

// Output:
// [SCENARIO] 1. Prepare protocol fee tokens (WUGNOT, atom, sol)
// [INFO] WUGNOT token issued for protocol fee
//
// [SCENARIO] 2. Admin delegates GNS to dummy2
// [INFO] delegated 1000000 GNS from admin to dummy2
//
// [SCENARIO] 3. Dummy delegates GNS to dummy
// [INFO] delegated 5000000 GNS from dummy to dummy
//
// [SCENARIO] 4. Protocol fee deposit
// [INFO] protocol fee deposited: atom(1000), sol(2500), wugnot(10000)
//
// [SCENARIO] 5. Skip blocks and distribute emission/protocol fee
// [INFO] skipped 10+1 blocks and distributed emission/protocol fee
//
// [SCENARIO] 6. Collect rewards
// [INFO] collected more protocol fee reward for dummy: atom(833), sol(2083)
//
// [SCENARIO] 7. Additional protocol fee deposit
// [INFO] protocol fee deposited: atom(2500), sol(4000), wugnot(0)
//
// [SCENARIO] 8. Collect rewards after additional protocol fee
// [INFO] collected more protocol fee reward for dummy: atom(2083), sol(3333)
//
// [SCENARIO] 9. Admin undelegates dummy2 and collects reward
// [INFO] admin undelegated 1000000 GNS from dummy2: atom(583), sol(1083)
