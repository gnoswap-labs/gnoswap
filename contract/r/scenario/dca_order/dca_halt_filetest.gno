// PKGPATH: gno.land/r/demo/main

// DCA order - halt scopes: emergency mode blocks creation and execution but
// keeps claim and cancel (withdrawals) available.

package main

import (
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
	"gno.land/r/gnoswap/halt/v1"
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
	keeperAddr   = testutils.TestAddress("keeper")
	keeperRealm  = testing.NewUserRealm(keeperAddr)
	fooPath      = "gno.land/r/onbloc/foo.FOO"
	barPath      = "gno.land/r/onbloc/bar.BAR"
)

func main(cur realm) {
	setupPoolAndLiquidity(cur)
	poolPath := pool.GetPoolPath(barPath, fooPath, fee500)
	groupID := poolPath + ":" + zeroForOneFlag(poolPath, fooPath) + ":60"

	testing.SetRealm(adminRealm)
	foo.Transfer(cross(cur), aliceAddr, 10_000)
	testing.SetRealm(aliceRealm)
	foo.Approve(cross(cur), dca.Address(), 10_000)
	orderID := dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 4, 1000)
	testing.SetRealm(keeperRealm)
	dca.ExecuteGroup(cross(cur), groupID, 0, 0)

	println("[SCENARIO] 1. Emergency halt blocks creation and execution")
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)
	testing.SkipHeights(minute / 5)

	// Halted groups are not listed, so keepers do not send doomed rounds.
	eq("", dca.GetExecutableGroups("", 10))
	ok(strings.Contains(dca.GetGroupJSON(groupID), `"executable":false`), "halted group not executable")

	testing.SetRealm(aliceRealm)
	aborts(cur, "halted", func() { dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 2, 1000) })
	testing.SetRealm(keeperRealm)
	aborts(cur, "halted", func() { dca.ExecuteGroup(cross(cur), groupID, 0, 0) })

	println("[SCENARIO] 2. Claim and cancel still work during emergency")
	claimed := dca.Claim(cross(cur), orderID)
	ok(claimed > 0, "claim during emergency")
	testing.SetRealm(aliceRealm)
	refund, _ := dca.CancelOrder(cross(cur), orderID)
	eq(int64(3000), refund)
	eq(int64(9000), foo.BalanceOf(aliceAddr))

	println("[SCENARIO] 2b. Safe mode (withdrawals halted) blocks deposits and execution")
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
	testing.SetRealm(aliceRealm)
	safeID := dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 2, 1000)
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelSafeMode)
	testing.SetRealm(aliceRealm)
	aborts(cur, "halted", func() { dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 2, 1000) })
	// Owners cannot cancel now, so their escrow is not sold either.
	eq("", dca.GetExecutableGroups("", 10))
	testing.SetRealm(keeperRealm)
	aborts(cur, "halted", func() { dca.ExecuteGroup(cross(cur), groupID, 0, 0) })
	testing.SetRealm(aliceRealm)
	aborts(cur, "halted", func() { dca.CancelOrder(cross(cur), safeID) })
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
	testing.SetRealm(aliceRealm)
	safeRefund, _ := dca.CancelOrder(cross(cur), safeID)
	eq(int64(2000), safeRefund)

	println("[SCENARIO] 3. Complete halt also blocks withdrawals")
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
	testing.SetRealm(aliceRealm)
	secondID := dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 2, 1000)
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelComplete)
	testing.SetRealm(aliceRealm)
	aborts(cur, "halted", func() { dca.CancelOrder(cross(cur), secondID) })
	aborts(cur, "halted", func() { dca.Claim(cross(cur), secondID) })

	println("[SCENARIO] 4. Execution resumes after the halt is lifted")
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
	eq(groupID, dueIDs(dca.GetExecutableGroups("", 10)))
	testing.SetRealm(keeperRealm)
	in, _ := dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	eq(int64(1000), in)

	println("[SCENARIO] done")
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
// [SCENARIO] 1. Emergency halt blocks creation and execution
// [SCENARIO] 2. Claim and cancel still work during emergency
// [SCENARIO] 2b. Safe mode (withdrawals halted) blocks deposits and execution
// [SCENARIO] 3. Complete halt also blocks withdrawals
// [SCENARIO] 4. Execution resumes after the halt is lifted
// [SCENARIO] done
