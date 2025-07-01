// protocol fee with emission reward

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/demo/wugnot"
	en "gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/staker"
	pf "gno.land/r/gnoswap/v1/protocol_fee"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var t *testing.T

var (
	admin       = consts.ADMIN
	adminRealm  = std.NewUserRealm(admin)
	dummyToAddr = testutils.TestAddress("dummyTo")
	dummyAddr   = testutils.TestAddress("dummy")
	dummyRealm  = std.NewUserRealm(dummyAddr)
	stakerRealm = std.NewUserRealm(consts.STAKER_ADDR)
	minAmount   = int64(1_000_000)

	barPath    = "gno.land/r/onbloc/bar"
	quxPath    = "gno.land/r/onbloc/qux"
	wugnotPath = "gno.land/r/demo/wugnot"
)

func main() {
	println("[SCENARIO] 1. Prepare protocol fee tokens (WUGNOT, bar, qux)")
	prepareProtocolFeeTokens()
	println()

	println("[SCENARIO] 2. Admin delegates GNS to dummyTo")
	adminDelegateToDummyTo()
	println()

	println("[SCENARIO] 3. Admin delegates GNS to dummy")
	adminDelegateToDummy()
	println()

	println("[SCENARIO] 4. Mock protocol fee deposit")
	mockProtocolFeeDeposit()
	println()

	println("[SCENARIO] 5. Skip blocks and distribute emission/protocol fee")
	skipBlocksAndDistribute()
	println()

	println("[SCENARIO] 6. Check and collect protocol fee reward")
	protocolFeeRewardScenario()
	println()

	println("[SCENARIO] 7. Mock additional protocol fee deposit")
	mockProtocolFeeDeposit2()
	println()

	println("[SCENARIO] 8. Collect more reward after additional protocol fee")
	collectMoreReward()
	println()

	println("[SCENARIO] 9. Admin undelegates dummyTo")
	adminUndelegateDummyTo()
	println()
}

func prepareProtocolFeeTokens() {
	// issue WUGNOT tokens for protocol fee
	testing.IssueCoins(consts.WUGNOT_ADDR, std.Coins{{"ugnot", 1}})
	ufmt.Printf("[INFO] WUGNOT token issued for protocol fee\n")
}

func adminDelegateToDummyTo() {
	testing.SetRealm(adminRealm)
	gns.Approve(cross, consts.GOV_STAKER_ADDR, minAmount)
	staker.Delegate(cross, dummyToAddr, uint64(minAmount), "")
	ufmt.Printf("[INFO] delegated %d GNS from admin to dummyTo\n", minAmount)
}

func adminDelegateToDummy() {
	testing.SetRealm(adminRealm)
	amount := 5 * minAmount
	gns.Transfer(cross, dummyAddr, amount)
	testing.SetRealm(dummyRealm)
	gns.Approve(cross, consts.GOV_STAKER_ADDR, amount)
	staker.Delegate(cross, dummyAddr, uint64(amount), "")
	ufmt.Printf("[INFO] delegated %d GNS from admin to dummy\n", amount)
}

func mockProtocolFeeDeposit() {
	// mock protocol fee deposit (bar, qux, wugnot)
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 1000)
	qux.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 2500)
	testing.SetOriginSend(std.Coins{{"ugnot", 10000}})
	wugnot.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 10000)
	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, barPath, 1000)
	pf.AddToProtocolFee(cross, quxPath, 2500)
	pf.AddToProtocolFee(cross, wugnotPath, 10000)
	ufmt.Printf("[INFO] protocol fee deposited: bar(1000), qux(2500), wugnot(10000)\n")
}

func skipBlocksAndDistribute() {
	testing.SkipHeights(10)
	en.MintAndDistributeGns(cross)
	testing.SkipHeights(1)
	ufmt.Printf("[INFO] skipped 10+1 blocks and distributed emission/protocol fee\n")
}

func protocolFeeRewardScenario() {
	gcr := staker.GetClaimableRewardByAddress(dummyAddr)
	ufmt.Printf("[INFO] claimable reward (dummy): %s\n", gcr)
	testing.SetRealm(dummyRealm)
	staker.CollectReward(cross)
	ufmt.Printf("[INFO] collected protocol fee reward for dummy\n")
}

func mockProtocolFeeDeposit2() {
	// mock additional protocol fee deposit (bar, qux)
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 2500)
	qux.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 4000)
	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, barPath, 2500)
	pf.AddToProtocolFee(cross, quxPath, 4000)
	testing.SkipHeights(1)
	ufmt.Printf("[INFO] additional protocol fee deposited: bar(2500), qux(4000)\n")
}

func collectMoreReward() {
	testing.SetRealm(dummyRealm)
	staker.CollectReward(cross)
	ufmt.Printf("[INFO] collected more protocol fee reward for dummy\n")
}

func adminUndelegateDummyTo() {
	testing.SetRealm(adminRealm)
	staker.Undelegate(cross, dummyToAddr, uint64(minAmount))
	ufmt.Printf("[INFO] admin undelegated %d GNS from dummyTo\n", minAmount)
}
