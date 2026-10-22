// PKGPATH: gno.land/r/demo/main

// DCA order - multiple orders with different sizes and lengths share a group;
// joiners never share earlier rounds, finished orders stop selling, late
// keepers do not batch missed rounds.

package main

import (
	"strings"
	"chain/runtime"
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/p/gnoswap/gnsmath/v1"
	prbac "gno.land/p/gnoswap/rbac/v1"
	u256 "gno.land/p/gnoswap/uint256/v1"

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
	carolAddr    = testutils.TestAddress("carol")
	carolRealm   = testing.NewUserRealm(carolAddr)
	keeperAddr   = testutils.TestAddress("keeper")
	keeperRealm  = testing.NewUserRealm(keeperAddr)
	fooPath      = "gno.land/r/onbloc/foo.FOO"
	barPath      = "gno.land/r/onbloc/bar.BAR"
)

func main(cur realm) {
	setupPoolAndLiquidity(cur)
	poolPath := pool.GetPoolPath(barPath, fooPath, fee500)
	groupID := poolPath + ":" + zeroForOneFlag(poolPath, fooPath) + ":60"

	fund(cur, aliceRealm, aliceAddr, 1000*3)
	fund(cur, bobRealm, bobAddr, 3000*2)
	fund(cur, carolRealm, carolAddr, 500*4)

	println("[SCENARIO] 1. Alice: 1000 x 3 rounds; round 1 runs with Alice alone")
	testing.SetRealm(aliceRealm)
	aliceID := dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 3, 1000)

	testing.SetRealm(keeperRealm)
	_, out1 := dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	acc1 := accAdd(u256.Zero(), out1, 1000)

	println("[SCENARIO] 2. Bob (3000 x 2) and Carol (500 x 4) join after round 1")
	testing.SetRealm(bobRealm)
	bobID := dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 3000, 2, 1000)
	testing.SetRealm(carolRealm)
	carolID := dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 500, 4, 1000)

	// Joiners must not share round-1 output.
	eq(int64(0), dca.GetClaimable(bobID))
	eq(int64(0), dca.GetClaimable(carolID))
	// Claiming nothing is a no-op (no state change, no event).
	bobJSON := dca.GetOrderJSON(bobID)
	eq(int64(0), dca.Claim(cross(cur), bobID))
	eq(bobJSON, dca.GetOrderJSON(bobID))

	println("[SCENARIO] 3. Rounds 2-3 sell 4500 each; Alice and Bob end after round 3")
	testing.SetRealm(keeperRealm)
	testing.SkipHeights(minute / 5)
	in2, out2 := dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	eq(int64(4500), in2)
	testing.SkipHeights(minute / 5)
	in3, out3 := dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	eq(int64(4500), in3)
	acc3 := accAdd(accAdd(acc1, out2, 4500), out3, 4500)

	println("[SCENARIO] 4. Late keeper: one round per call, fixed cadence keeps")
	testing.SkipHeights(3*minute/5 + 6) // 3.5 minutes late
	in4, out4 := dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	eq(int64(500), in4)
	aborts(cur, "[GNOSWAP-DCA-ORDER-010]", func() {
		dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	})
	testing.SkipHeights(6) // reach the next aligned slot
	in5, out5 := dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	eq(int64(500), in5)
	acc5 := accAdd(accAdd(acc3, out4, 500), out5, 500)

	println("[SCENARIO] 5. Claims match the per-round pro-rata split exactly")
	expectAlice := owed(1000, acc3, u256.Zero())
	expectBob := owed(3000, acc3, acc1)
	expectCarol := owed(500, acc5, acc1)
	eq(expectAlice, dca.GetClaimable(aliceID))
	eq(expectBob, dca.GetClaimable(bobID))
	eq(expectCarol, dca.GetClaimable(carolID))

	eq(expectAlice, dca.Claim(cross(cur), aliceID))
	eq(expectBob, dca.Claim(cross(cur), bobID))
	eq(expectCarol, dca.Claim(cross(cur), carolID))
	eq(expectAlice, bar.BalanceOf(aliceAddr))
	eq(expectBob, bar.BalanceOf(bobAddr))
	eq(expectCarol, bar.BalanceOf(carolAddr))

	totalOut := out1 + out2 + out3 + out4 + out5
	paid := expectAlice + expectBob + expectCarol
	ok(paid <= totalOut, "paid more than received")
	ok(totalOut-paid <= 3, "dust exceeds one unit per order")
	eq(totalOut-paid, bar.BalanceOf(dca.Address()))
	eq(int64(0), foo.BalanceOf(dca.Address()))
	println("[INFO] rounds out:", out1, out2, out3, out4, out5, "paid:", paid)

	println("[SCENARIO] 6. Executable group IDs page with a cursor, oldest due first")
	fund(cur, aliceRealm, aliceAddr, 2000)
	testing.SetRealm(aliceRealm)
	dca.CreateOrder(cross(cur), poolPath, fooPath, 3600, 1000, 1, 1000)
	dca.CreateOrder(cross(cur), poolPath, fooPath, 86400, 1000, 1, 1000)
	hourID := poolPath + ":0:3600"
	dayID := poolPath + ":0:86400"
	eq(hourID+","+dayID, dueIDs(dca.GetExecutableGroups("", 10)))
	first := dca.GetExecutableGroups("", 1)
	eq(hourID, dueIDs(first))
	second := dca.GetExecutableGroups(first, 1)
	eq(dayID, dueIDs(second))
	eq("", dca.GetExecutableGroups(second, 1))
	// A group executed between pages does not shift the cursor.
	testing.SetRealm(keeperRealm)
	dca.ExecuteGroup(cross(cur), hourID, 0, 0)
	eq(dayID, dueIDs(dca.GetExecutableGroups(first, 10)))
	aborts(cur, "[GNOSWAP-DCA-ORDER-020]", func() { dca.GetExecutableGroups("garbage", 1) })
	dca.ExecuteGroup(cross(cur), dayID, 0, 0)

	println("[SCENARIO] 7. Idle group restarts immediately for a new order")
	testing.SkipHeights(10 * minute / 5)
	fund(cur, aliceRealm, aliceAddr, 1000)
	testing.SetRealm(aliceRealm)
	dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 1, 1000)
	eq(groupID, dueIDs(dca.GetExecutableGroups("", 10)))
	testing.SetRealm(keeperRealm)
	in6, _ := dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	eq(int64(1000), in6)

	println("[SCENARIO] done")
}

func fund(cur realm, userRealm runtime.Realm, user address, amount int64) {
	testing.SetRealm(adminRealm)
	foo.Transfer(cross(cur), user, amount)
	testing.SetRealm(userRealm)
	foo.Approve(cross(cur), dca.Address(), amount)
}

var q128 = u256.Zero().Lsh(u256.One(), 128)

func accAdd(acc *u256.Uint, out int64, rate int64) *u256.Uint {
	delta := u256.MulDiv(u256.NewUint(uint64(out)), q128, u256.NewUint(uint64(rate)))
	return u256.Zero().Add(acc, delta)
}

func owed(rate int64, endAcc *u256.Uint, debt *u256.Uint) int64 {
	diff := u256.Zero().Sub(endAcc, debt)
	return int64(u256.MulDiv(diff, u256.NewUint(uint64(rate)), q128).Uint64())
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

// dueIDs strips the "<nextExecutionAt>|" prefix from GetExecutableGroups entries.
func dueIDs(entries string) string {
	if entries == "" {
		return ""
	}

	ids := []string{}
	for _, entry := range strings.Split(entries, ",") {
		ids = append(ids, entry[strings.Index(entry, "|")+1:])
	}

	return strings.Join(ids, ",")
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
// [SCENARIO] 1. Alice: 1000 x 3 rounds; round 1 runs with Alice alone
// [SCENARIO] 2. Bob (3000 x 2) and Carol (500 x 4) join after round 1
// [SCENARIO] 3. Rounds 2-3 sell 4500 each; Alice and Bob end after round 3
// [SCENARIO] 4. Late keeper: one round per call, fixed cadence keeps
// [SCENARIO] 5. Claims match the per-round pro-rata split exactly
// [INFO] rounds out: 997 4489 4488 498 498 paid: 10968
// [SCENARIO] 6. Executable group IDs page with a cursor, oldest due first
// [SCENARIO] 7. Idle group restarts immediately for a new order
// [SCENARIO] done
