// complex protocol fee reward

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
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
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)
	dummyAddr    = testutils.TestAddress("dummy")
	dummyRealm   = std.NewUserRealm(dummyAddr)
	dummy2Addr   = testutils.TestAddress("dummy2")
	dummy2Realm  = std.NewUserRealm(dummy2Addr)
	stakerRealm  = std.NewUserRealm(consts.STAKER_ADDR)
	minAmount    = int64(1_000_000)

	barPath    = "gno.land/r/onbloc/bar"
	quxPath    = "gno.land/r/onbloc/qux"
	wugnotPath = "gno.land/r/demo/wugnot"
)

func main() {
	println("[SCENARIO] 1. Prepare protocol fee tokens (WUGNOT, bar, qux)")
	setupTokens()
	println()

	println("[SCENARIO] 2. Admin delegates GNS to dummy2")
	delegateToDummy2()
	println()

	println("[SCENARIO] 3. Admin delegates GNS to dummy")
	delegateToDummy()
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

	println("[SCENARIO] 9. Admin undelegates dummy2")
	undelegateByDummy2()
	println()
}

func setupTokens() {
	ufmt.Printf("[INFO] WUGNOT token issued for protocol fee\n")
}

func delegateToDummy2() {
	testing.SetRealm(adminRealm)
	gns.Approve(cross, consts.GOV_STAKER_ADDR, minAmount)
	staker.Delegate(cross, dummy2Addr, uint64(minAmount), "")
	ufmt.Printf("[INFO] delegated %d GNS from admin to dummy2\n", minAmount)
}

func delegateToDummy() {
	testing.SetRealm(adminRealm)
	amount := 5 * minAmount
	gns.Transfer(cross, dummyAddr, amount)
	testing.SetRealm(dummyRealm)
	gns.Approve(cross, consts.GOV_STAKER_ADDR, amount)
	staker.Delegate(cross, dummyAddr, uint64(amount), "")
	ufmt.Printf("[INFO] delegated %d GNS from admin to dummy\n", amount)
}

func depositProtocolFee() {
	// protocol fee deposit (bar, qux, wugnot)
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 1000)
	qux.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 2500)

	coins := std.Coins{{"ugnot", 10000}}
	testing.IssueCoins(adminAddr, coins)
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminAddr, consts.WUGNOT_ADDR, coins)

	testing.SetOriginSend(coins)
	wugnot.Deposit(cross)
	wugnot.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 10000)

	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, barPath, 1000)
	pf.AddToProtocolFee(cross, quxPath, 2500)
	pf.AddToProtocolFee(cross, wugnotPath, 10000)

	currentBarBalance := bar.BalanceOf(consts.PROTOCOL_FEE_ADDR)
	currentQuxBalance := qux.BalanceOf(consts.PROTOCOL_FEE_ADDR)
	currentWugnotBalance := wugnot.BalanceOf(consts.PROTOCOL_FEE_ADDR)

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

	bar.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 2500)
	qux.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 4000)

	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, barPath, 2500)
	pf.AddToProtocolFee(cross, quxPath, 4000)

	currentBarBalance := bar.BalanceOf(consts.PROTOCOL_FEE_ADDR)
	currentQuxBalance := qux.BalanceOf(consts.PROTOCOL_FEE_ADDR)
	currentWugnotBalance := wugnot.BalanceOf(consts.PROTOCOL_FEE_ADDR)

	ufmt.Printf("[INFO] protocol fee deposited: bar(%d), qux(%d), wugnot(%d)\n", currentBarBalance, currentQuxBalance, currentWugnotBalance)
}

func collectRewardsByDummy() {
	testing.SetRealm(dummyRealm)
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

func undelegateByDummy2() {
	testing.SetRealm(adminRealm)
	testing.SkipHeights(1)

	prevBarBalance := bar.BalanceOf(dummy2Addr)
	prevQuxBalance := qux.BalanceOf(dummy2Addr)
	prevGnotBalance := getUgnotBalance(dummy2Addr)

	staker.Undelegate(cross, dummy2Addr, uint64(minAmount))

	afterBarBalance := bar.BalanceOf(dummy2Addr)
	afterQuxBalance := qux.BalanceOf(dummy2Addr)
	afterGnotBalance := getUgnotBalance(dummy2Addr)

	ufmt.Printf("[INFO] admin undelegated %d GNS from dummy2: bar(%d), qux(%d), gnot(%d)\n", minAmount, afterBarBalance-prevBarBalance, afterQuxBalance-prevQuxBalance, afterGnotBalance-prevGnotBalance)
}

func getUgnotBalance(addr std.Address) uint64 {
	banker := std.NewBanker(std.BankerTypeRealmIssue)
	coins := banker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(coins.AmountOf("ugnot"))
}

// Output:
// [SCENARIO] 1. Prepare protocol fee tokens (WUGNOT, bar, qux)
// [INFO] WUGNOT token issued for protocol fee
//
// [SCENARIO] 2. Admin delegates GNS to dummy2
// [INFO] delegated 1000000 GNS from admin to dummy2
//
// [SCENARIO] 3. Admin delegates GNS to dummy
// [INFO] delegated 5000000 GNS from admin to dummy
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
// [SCENARIO] 9. Admin undelegates dummy2
// [INFO] admin undelegated 1000000 GNS from dummy2: bar(583), qux(1083), gnot(1666)
