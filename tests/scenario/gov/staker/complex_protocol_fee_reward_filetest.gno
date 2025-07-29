// complex protocol fee reward

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v1/access"
	en "gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/staker"
	pf "gno.land/r/gnoswap/v1/protocol_fee"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var t *testing.T

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = std.NewUserRealm(adminAddr)
	dummyAddr     = testutils.TestAddress("dummy")
	dummyRealm    = std.NewUserRealm(dummyAddr)
	dummy2Addr    = testutils.TestAddress("dummy2")
	dummy2Realm   = std.NewUserRealm(dummy2Addr)
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm   = std.NewUserRealm(stakerAddr)
	minAmount     = int64(1_000_000)

	barPath    = "gno.land/r/onbloc/bar"
	quxPath    = "gno.land/r/onbloc/qux"

	wugnotPath = "gno.land/r/demo/wugnot"
	wugnotAddr std.Address = "g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6"

	govStakerAddr, _ = access.GetAddress(prbac.ROLE_GOV_STAKER.String())

	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
)

func main() {
	println("[SCENARIO] 1. Prepare protocol fee tokens (WUGNOT, bar, qux)")
	setupTokens()
	println()

	println("[SCENARIO] 2. Admin delegates GNS to dummy2")
	delegateAdminToDummy2()
	println()

	println("[SCENARIO] 3. Dummy delegates GNS to dummy")
	delegateDummyToDummy()
	println()

	println("[SCENARIO] 4. Protocol fee deposit")
	depositProtocolFee()
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
	ufmt.Printf("[INFO] WUGNOT token issued for protocol fee\n")
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

func depositProtocolFee() {
	// protocol fee deposit (bar, qux, wugnot)
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, protocolFeeAddr, 1000)
	qux.Transfer(cross, protocolFeeAddr, 2500)

	coins := std.Coins{{"ugnot", 10000}}
	testing.IssueCoins(adminAddr, coins)
	banker := std.NewBanker(std.BankerTypeRealmSend)

	banker.SendCoins(adminAddr, wugnotAddr, coins)

	testing.SetOriginSend(coins)
	wugnot.Deposit(cross)
	wugnot.Transfer(cross, protocolFeeAddr, 10000)

	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, barPath, 1000)
	pf.AddToProtocolFee(cross, quxPath, 2500)
	pf.AddToProtocolFee(cross, wugnotPath, 10000)

	currentBarBalance := bar.BalanceOf(protocolFeeAddr)
	currentQuxBalance := qux.BalanceOf(protocolFeeAddr)
	currentWugnotBalance := wugnot.BalanceOf(protocolFeeAddr)

	ufmt.Printf("[INFO] protocol fee deposited: bar(%d), qux(%d), wugnot(%d)\n", currentBarBalance, currentQuxBalance, currentWugnotBalance)
}

func skipBlocksAndDistribute() {
	testing.SkipHeights(10)
	en.MintAndDistributeGns(cross)
	testing.SkipHeights(1)
	ufmt.Printf("[INFO] skipped 10+1 blocks and distributed emission/protocol fee\n")
}

func depositProtocolFeeAdditional() {
	// additional protocol fee deposit (bar, qux)
	testing.SetRealm(adminRealm)

	bar.Transfer(cross, protocolFeeAddr, 2500)
	qux.Transfer(cross, protocolFeeAddr, 4000)

	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, barPath, 2500)
	pf.AddToProtocolFee(cross, quxPath, 4000)

	currentBarBalance := bar.BalanceOf(protocolFeeAddr)
	currentQuxBalance := qux.BalanceOf(protocolFeeAddr)
	currentWugnotBalance := wugnot.BalanceOf(protocolFeeAddr)

	ufmt.Printf("[INFO] protocol fee deposited: bar(%d), qux(%d), wugnot(%d)\n", currentBarBalance, currentQuxBalance, currentWugnotBalance)
}

func collectRewardsByDummy() {
	testing.SetOriginCaller(dummyAddr)
	testing.SkipHeights(1)

	prevBarBalance := bar.BalanceOf(dummyAddr)
	prevQuxBalance := qux.BalanceOf(dummyAddr)
	prevGnotBalance := getUgnotBalance(dummyAddr)

	staker.CollectReward(cross)

	afterBarBalance := bar.BalanceOf(dummyAddr)
	afterQuxBalance := qux.BalanceOf(dummyAddr)
	afterGnotBalance := getUgnotBalance(dummyAddr)

	ufmt.Printf("[INFO] collected more protocol fee reward for dummy: bar(%d), qux(%d), gnot(%d)\n", afterBarBalance-prevBarBalance, afterQuxBalance-prevQuxBalance, afterGnotBalance-prevGnotBalance)
}

func unDelegateAndCollectRewardByAdmin() {
	testing.SetRealm(adminRealm)
	testing.SkipHeights(1)

	prevBarBalance := bar.BalanceOf(adminAddr)
	prevQuxBalance := qux.BalanceOf(adminAddr)
	prevGnotBalance := getUgnotBalance(adminAddr)

	staker.Undelegate(cross, adminAddr, int64(minAmount))
	staker.CollectReward(cross)

	afterBarBalance := bar.BalanceOf(adminAddr)
	afterQuxBalance := qux.BalanceOf(adminAddr)
	afterGnotBalance := getUgnotBalance(adminAddr)

	ufmt.Printf("[INFO] admin undelegated %d GNS from dummy2: bar(%d), qux(%d), gnot(%d)\n", minAmount, afterBarBalance-prevBarBalance, afterQuxBalance-prevQuxBalance, afterGnotBalance-prevGnotBalance)
}

func getUgnotBalance(addr std.Address) int64 {
	banker := std.NewBanker(std.BankerTypeRealmIssue)
	coins := banker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return int64(coins.AmountOf("ugnot"))
}

// Output:
// [SCENARIO] 1. Prepare protocol fee tokens (WUGNOT, bar, qux)
// [INFO] WUGNOT token issued for protocol fee
//
// [SCENARIO] 2. Admin delegates GNS to dummy2
// [INFO] delegated 1000000 GNS from admin to dummy2
//
// [SCENARIO] 3. Dummy delegates GNS to dummy
// [INFO] delegated 5000000 GNS from dummy to dummy
//
// [SCENARIO] 4. Protocol fee deposit
// [INFO] protocol fee deposited: bar(1000), qux(2500), wugnot(10000)
//
// [SCENARIO] 5. Skip blocks and distribute emission/protocol fee
// [INFO] skipped 10+1 blocks and distributed emission/protocol fee
//
// [SCENARIO] 6. Collect rewards
// [INFO] collected more protocol fee reward for dummy: bar(833), qux(2083), gnot(8333)
//
// [SCENARIO] 7. Additional protocol fee deposit
// [INFO] protocol fee deposited: bar(2500), qux(4000), wugnot(0)
//
// [SCENARIO] 8. Collect rewards after additional protocol fee
// [INFO] collected more protocol fee reward for dummy: bar(2083), qux(3333), gnot(0)
//
// [SCENARIO] 9. Admin undelegates dummy2 and collects reward
// [INFO] admin undelegated 1000000 GNS from dummy2: bar(583), qux(1083), gnot(1666)
