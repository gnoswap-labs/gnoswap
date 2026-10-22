// PKGPATH: gno.land/r/demo/main

// DCA order - cancellation refunds, prepaid creation fee, admin-only
// configuration, and input validation.

package main

import (
	"chain/runtime"
	"strings"
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/p/gnoswap/gnsmath/v1"
	prbac "gno.land/p/gnoswap/rbac/v1"

	_ "gno.land/r/gnoswap/common/v1"
	_ "gno.land/r/gnoswap/test/dca_order/v1"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac/v1"
	_ "gno.land/r/gnoswap/router/v1"

	"gno.land/r/gnoswap/access/v1"
	dca "gno.land/r/gnoswap/test/dca_order"
	"gno.land/r/gnoswap/gns"
	pool "gno.land/r/gnoswap/pool"
	position "gno.land/r/gnoswap/position"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const IntervalHourForTest int64 = 3600

const (
	fee500     uint32 = 500
	maxApprove int64  = 9223372036854775806
	minute     int64  = 60
)

var t = &testing.T{}

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())
	lpAddr       = testutils.TestAddress("lp")
	lpRealm      = testing.NewUserRealm(lpAddr)
	aliceAddr    = testutils.TestAddress("alice")
	aliceRealm   = testing.NewUserRealm(aliceAddr)
	bobAddr      = testutils.TestAddress("bob")
	bobRealm     = testing.NewUserRealm(bobAddr)
	keeperAddr   = testutils.TestAddress("keeper")
	keeperRealm  = testing.NewUserRealm(keeperAddr)
	fooPath      = "gno.land/r/onbloc/foo.FOO"
	barPath      = "gno.land/r/onbloc/bar.BAR"
)

func main(cur realm) {
	setupPoolAndLiquidity(cur)
	poolPath := pool.GetPoolPath(barPath, fooPath, fee500)
	groupID := poolPath + ":" + zeroForOneFlag(poolPath, fooPath) + ":60"

	println("[SCENARIO] 1. Input validation")
	fund(cur, aliceRealm, aliceAddr, 1_000_000)
	testing.SetRealm(aliceRealm)
	aborts(cur, "[GNOSWAP-DCA-ORDER-003]", func() { dca.CreateOrder(cross(cur), poolPath, fooPath, 120, 1000, 3, 1000) })
	aborts(cur, "[GNOSWAP-DCA-ORDER-002]", func() { dca.CreateOrder(cross(cur), poolPath, "gno.land/r/onbloc/baz.BAZ", minute, 1000, 3, 1000) })
	aborts(cur, "[GNOSWAP-DCA-ORDER-001]", func() {
		dca.CreateOrder(cross(cur), "gno.land/r/onbloc/x:gno.land/r/onbloc/y:500", fooPath, minute, 1000, 3, 1000)
	})
	aborts(cur, "[GNOSWAP-DCA-ORDER-004]", func() { dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 0, 3, 1000) })
	aborts(cur, "[GNOSWAP-DCA-ORDER-004]", func() { dca.CreateOrder(cross(cur), poolPath, fooPath, minute, -5, 3, 1000) })
	aborts(cur, "[GNOSWAP-DCA-ORDER-005]", func() { dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 0, 1000) })
	aborts(cur, "[GNOSWAP-DCA-ORDER-005]", func() { dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 10_001, 1000) })
	aborts(cur, "int64 multiplication overflow", func() { dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 9_000_000_000_000_000_000, 2, 1000) })
	eq("", dca.GetGroupIDs(0, 10))

	println("[SCENARIO] 2. Admin-only configuration")
	aborts(cur, "unauthorized", func() { dca.SetCreationFeeBps(cross(cur), 50) })
	aborts(cur, "unauthorized", func() { dca.SetOrderLimits(cross(cur), 1, 100) })
	testing.SetRealm(adminRealm)
	aborts(cur, "[GNOSWAP-DCA-ORDER-012]", func() { dca.SetCreationFeeBps(cross(cur), 1001) })
	aborts(cur, "[GNOSWAP-DCA-ORDER-012]", func() { dca.SetOrderLimits(cross(cur), 0, 100) })
	dca.SetCreationFeeBps(cross(cur), 50) // 0.5%
	dca.SetOrderLimits(cross(cur), 100, 20)
	println("[INFO] config:", dca.GetConfigJSON())

	testing.SetRealm(aliceRealm)
	aborts(cur, "[GNOSWAP-DCA-ORDER-004]", func() { dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 99, 3, 1000) })
	aborts(cur, "[GNOSWAP-DCA-ORDER-005]", func() { dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 21, 1000) })

	println("[SCENARIO] 3a. The caller caps the fee it accepts")
	aborts(cur, "[GNOSWAP-DCA-ORDER-019]", func() { dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 5, 49) })

	println("[SCENARIO] 3b. The creation fee rounds up in favor of the protocol")
	feeProbeBefore := foo.BalanceOf(aliceAddr)
	probeID := dca.CreateOrder(cross(cur), poolPath, fooPath, IntervalHourForTest, 199, 1, 1000) // 199 * 0.5% = 0.995 -> 1
	eq(feeProbeBefore-199-1, foo.BalanceOf(aliceAddr))
	eq(int64(1), dca.GetPendingFee(fooPath))
	refundProbe, _ := dca.CancelOrder(cross(cur), probeID)
	eq(int64(199), refundProbe)

	println("[SCENARIO] 3. Creation fee is prepaid on top of the order input")
	aliceBefore := foo.BalanceOf(aliceAddr)
	aliceID := dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 5, 1000)
	eq(aliceBefore-5000-25, foo.BalanceOf(aliceAddr))
	eq(int64(1+25), dca.GetPendingFee(fooPath))

	fund(cur, bobRealm, bobAddr, 1_000_000)
	testing.SetRealm(bobRealm)
	bobID := dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 2000, 5, 1000)
	eq(int64(1+25+50), dca.GetPendingFee(fooPath))
	eq(int64(1+5000+25+10000+50), foo.BalanceOf(dca.Address()))
	eq("1,2", dca.GetOrderIDsByOwner(aliceAddr, 0, 10))
	eq("2", dca.GetOrderIDsByOwner(aliceAddr, 1, 10))
	eq("1", dca.GetOrderIDsByOwner(aliceAddr, 0, 1))
	eq("3", dca.GetOrderIDsByOwner(bobAddr, 0, 10))

	println("[SCENARIO] 4. Two rounds execute, then Alice cancels")
	testing.SetRealm(keeperRealm)
	// A floor quoted for a different input is scaled to the actual input
	// instead of reverting: 1940 for 2000 becomes 2910 for the 3000 round.
	// (A failing floor is not exercised here: filetest revive keeps the
	// partial state of a call that aborts mid-swap, which a chain reverts.)
	in1, out1 := dca.ExecuteGroup(cross(cur), groupID, 2000, 1940)
	ok(out1 >= 2910, "scaled floor must hold")
	eq(int64(3000), in1)
	testing.SkipHeights(minute / 5)
	_, out2 := dca.ExecuteGroup(cross(cur), groupID, 0, 0)

	testing.SetRealm(bobRealm)
	aborts(cur, "[GNOSWAP-DCA-ORDER-008]", func() { dca.CancelOrder(cross(cur), aliceID) })

	testing.SetRealm(aliceRealm)
	aliceFooBefore := foo.BalanceOf(aliceAddr)
	expectedAliceOut := dca.GetClaimable(aliceID)
	refund, claimed := dca.CancelOrder(cross(cur), aliceID)
	eq(int64(3*1000), refund)
	eq(expectedAliceOut, claimed)
	ok(claimed*3 <= out1+out2 && out1+out2-claimed*3 <= 3*2, "alice owns one third of rounds 1-2")
	eq(aliceFooBefore+3000, foo.BalanceOf(aliceAddr))
	eq(claimed, bar.BalanceOf(aliceAddr))
	ok(strings.Contains(dca.GetOrderJSON(aliceID), `"status":"CANCELLED"`), "alice order cancelled")
	ok(strings.Contains(dca.GetGroupJSON(groupID), `"rate":"2000"`), "group rate drops to bob only")
	aborts(cur, "[GNOSWAP-DCA-ORDER-007]", func() { dca.CancelOrder(cross(cur), aliceID) })
	aborts(cur, "[GNOSWAP-DCA-ORDER-007]", func() { dca.Claim(cross(cur), aliceID) })

	println("[SCENARIO] 5. Bob's remaining rounds sell only his input")
	testing.SetRealm(keeperRealm)
	for i := 0; i < 3; i++ {
		testing.SkipHeights(minute / 5)
		in, _ := dca.ExecuteGroup(cross(cur), groupID, 0, 0)
		eq(int64(2000), in)
		// A second executor learns the round already ran.
		aborts(cur, "[GNOSWAP-DCA-ORDER-010]", func() { dca.ExecuteGroup(cross(cur), groupID, 1234, 1) })
	}
	ok(strings.Contains(dca.GetGroupJSON(groupID), `"rate":"0"`), "group idle after bob's last round")
	// A cancelled order stops counting rounds at its cancellation.
	ok(strings.Contains(dca.GetOrderJSON(aliceID), `"executedRounds":"2"`), "cancelled order keeps executedRounds=2")
	ok(strings.Contains(dca.GetOrderJSON(aliceID), `"cancelRound":"2"`), "cancel round recorded")

	println("[SCENARIO] 6. Cancelling a fully executed order completes it with no refund")
	testing.SetRealm(bobRealm)
	bobRefund, bobClaimed := dca.CancelOrder(cross(cur), bobID)
	eq(int64(0), bobRefund)
	ok(bobClaimed > 0, "bob receives output")
	ok(strings.Contains(dca.GetOrderJSON(bobID), `"status":"COMPLETED"`), "bob order completed")

	// Escrow holds only prepaid fees plus output rounding dust.
	eq(int64(76), foo.BalanceOf(dca.Address()))
	ok(bar.BalanceOf(dca.Address()) <= 5, "only rounding dust remains")

	println("[SCENARIO] 7. Fee withdrawal is admin-only and bounded")
	testing.SetRealm(aliceRealm)
	aborts(cur, "unauthorized", func() { dca.WithdrawFee(cross(cur), fooPath, aliceAddr, 10) })
	testing.SetRealm(adminRealm)
	aborts(cur, "[GNOSWAP-DCA-ORDER-014]", func() { dca.WithdrawFee(cross(cur), fooPath, adminAddr, 77) })
	aborts(cur, "[GNOSWAP-DCA-ORDER-013]", func() { dca.WithdrawFee(cross(cur), fooPath, dca.Address(), 76) })
	adminFooBefore := foo.BalanceOf(adminAddr)
	dca.WithdrawFee(cross(cur), fooPath, adminAddr, 76)
	eq(adminFooBefore+76, foo.BalanceOf(adminAddr))
	eq(int64(0), dca.GetPendingFee(fooPath))
	eq(int64(0), foo.BalanceOf(dca.Address()))

	println("[SCENARIO] done")
}

func fund(cur realm, userRealm runtime.Realm, user address, amount int64) {
	testing.SetRealm(adminRealm)
	foo.Transfer(cross(cur), user, amount)
	testing.SetRealm(userRealm)
	foo.Approve(cross(cur), dca.Address(), amount)
}

func zeroForOneFlag(poolPath string, tokenIn string) string {
	token0, _ := pool.GetToken0Path(poolPath)
	if token0 == tokenIn {
		return "1"
	}

	return "0"
}

// Assertion helpers panic so a failure aborts the filetest; uassert with a
// bare testing.T only records errors and would let the scenario pass.
func eq(want, got any) {
	if want != got {
		panic(ufmt.Sprintf("assertion failed: want %v, got %v", want, got))
	}
}

func ok(cond bool, msg string) {
	if !cond {
		panic("assertion failed: " + msg)
	}
}

func aborts(cur realm, substr string, fn func()) {
	if !uassert.AbortsContains(t, cur, substr, fn) {
		panic("expected abort containing " + substr)
	}
}

func setupPoolAndLiquidity(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, pool.GetPoolCreationFee())
	pool.CreatePool(cross(cur), barPath, fooPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	foo.Transfer(cross(cur), lpAddr, 50_000_000)
	bar.Transfer(cross(cur), lpAddr, 50_000_000)

	testing.SetRealm(lpRealm)
	foo.Approve(cross(cur), poolAddr, maxApprove)
	bar.Approve(cross(cur), poolAddr, maxApprove)
	position.Mint(
		cross(cur),
		barPath,
		fooPath,
		fee500,
		-10000,
		10000,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		lpAddr,
		"",
	)
}

// Output:
// [SCENARIO] 1. Input validation
// [SCENARIO] 2. Admin-only configuration
// [INFO] config: {"creationFeeBps":"50","minAmountPerExecution":"100","maxTotalExecutions":"20","allowedIntervals":["60","3600","86400","604800","2592000"]}
// [SCENARIO] 3a. The caller caps the fee it accepts
// [SCENARIO] 3b. The creation fee rounds up in favor of the protocol
// [SCENARIO] 3. Creation fee is prepaid on top of the order input
// [SCENARIO] 4. Two rounds execute, then Alice cancels
// [SCENARIO] 5. Bob's remaining rounds sell only his input
// [SCENARIO] 6. Cancelling a fully executed order completes it with no refund
// [SCENARIO] 7. Fee withdrawal is admin-only and bounded
// [SCENARIO] done
