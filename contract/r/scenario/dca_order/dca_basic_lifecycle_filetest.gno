// PKGPATH: gno.land/r/demo/main

// DCA order - single order lifecycle: create, scheduled executions by a
// permissionless keeper, partial claim, completion, and final claim.

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

	println("[SCENARIO] 1. Alice creates a 3-round DCA order selling 1000 FOO per minute")
	testing.SetRealm(adminRealm)
	foo.Transfer(cross(cur), aliceAddr, 10_000)

	testing.SetRealm(aliceRealm)
	foo.Approve(cross(cur), dca.Address(), 3000)
	orderID := dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 3, 1000)
	eq(uint64(1), orderID)
	eq(int64(7_000), foo.BalanceOf(aliceAddr))
	eq(int64(3_000), foo.BalanceOf(dca.Address()))

	groupID := poolPath + ":" + zeroForOneFlag(poolPath, fooPath) + ":60"
	eq(groupID, dueIDs(dca.GetExecutableGroups("", 10)))
	println("[INFO] group:", dca.GetGroupJSON(groupID))

	println("[SCENARIO] 2. Keeper executes round 1 immediately (new group)")
	testing.SetRealm(keeperRealm)
	in1, out1 := dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	eq(int64(1000), in1)
	ok(out1 > 0, "round 1 must produce output")
	eq(int64(2_000), foo.BalanceOf(dca.Address()))
	eq("", dueIDs(dca.GetExecutableGroups("", 10)))

	println("[SCENARIO] 3. Executing again before the interval reverts")
	aborts(cur, "[GNOSWAP-DCA-ORDER-010]", func() {
		dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	})

	println("[SCENARIO] 4. Anyone can claim; output always goes to the owner")
	// Settlement rounds down; at most 1 unit per claim stays as dust.
	claimable1 := dca.GetClaimable(orderID)
	ok(claimable1 <= out1 && out1-claimable1 <= 1, "claimable must be out1 minus at most 1 dust")
	claimed1 := dca.Claim(cross(cur), orderID)
	eq(claimable1, claimed1)
	eq(claimed1, bar.BalanceOf(aliceAddr))
	eq(int64(0), bar.BalanceOf(keeperAddr))
	eq(int64(0), dca.GetClaimable(orderID))

	println("[SCENARIO] 5. Rounds 2 and 3 run on schedule")
	testing.SkipHeights(minute / 5)
	_, out2 := dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	testing.SkipHeights(minute / 5)
	_, out3 := dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	eq(int64(0), foo.BalanceOf(dca.Address()))

	groupJSON := dca.GetGroupJSON(groupID)
	ok(strings.Contains(groupJSON, `"round":"3"`), groupJSON)
	ok(strings.Contains(groupJSON, `"rate":"0"`), groupJSON)

	println("[SCENARIO] 6. A group without active rate cannot execute")
	testing.SkipHeights(minute / 5)
	aborts(cur, "[GNOSWAP-DCA-ORDER-010]", func() {
		dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	})

	println("[SCENARIO] 7. Final claim completes the order")
	claimable2 := dca.GetClaimable(orderID)
	ok(claimable2 <= out1+out2+out3-claimed1 && out1+out2+out3-claimed1-claimable2 <= 2, "claimable must cover rounds 2-3 (<= 1 dust per claim)")
	testing.SetRealm(aliceRealm)
	claimed2 := dca.Claim(cross(cur), orderID)
	eq(claimable2, claimed2)
	eq(claimed1+claimed2, bar.BalanceOf(aliceAddr))
	eq(out1+out2+out3-claimed1-claimed2, bar.BalanceOf(dca.Address()))

	orderJSON := dca.GetOrderJSON(orderID)
	ok(strings.Contains(orderJSON, `"status":"COMPLETED"`), orderJSON)
	ok(strings.Contains(orderJSON, `"executedRounds":"3"`), orderJSON)
	println("[INFO] order:", orderJSON)

	// Only rounding dust (< 1 unit per claim) may remain in escrow.
	ok(bar.BalanceOf(dca.Address()) <= 2, "unexpected output left in escrow")

	println("[SCENARIO] 8. Completed orders cannot be claimed or cancelled again")
	aborts(cur, "[GNOSWAP-DCA-ORDER-007]", func() {
		dca.Claim(cross(cur), orderID)
	})
	aborts(cur, "[GNOSWAP-DCA-ORDER-007]", func() {
		dca.CancelOrder(cross(cur), orderID)
	})

	println("[SCENARIO] 9. A new order in an idle group runs immediately, even before the old slot")
	testing.SetRealm(adminRealm)
	foo.Transfer(cross(cur), aliceAddr, 1000)
	testing.SetRealm(aliceRealm)
	foo.Approve(cross(cur), dca.Address(), 1000)
	dca.CreateOrder(cross(cur), poolPath, fooPath, minute, 1000, 1, 1000)
	eq(groupID, dueIDs(dca.GetExecutableGroups("", 10)))
	testing.SetRealm(keeperRealm)
	in4, _ := dca.ExecuteGroup(cross(cur), groupID, 0, 0)
	eq(int64(1000), in4)
	eq("", dueIDs(dca.GetExecutableGroups("", 10)))

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
// [SCENARIO] 1. Alice creates a 3-round DCA order selling 1000 FOO per minute
// [INFO] group: {"id":"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500:0:60","poolPath":"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500","tokenIn":"gno.land/r/onbloc/foo.FOO","tokenOut":"gno.land/r/onbloc/bar.BAR","zeroForOne":false,"interval":"60","round":"0","rate":"1000","accX128":"0","nextExecutionAt":"1234567890","lastExecutedAt":"0","activeOrders":"1","totalAmountIn":"0","totalAmountOut":"0","executable":true}
// [SCENARIO] 2. Keeper executes round 1 immediately (new group)
// [SCENARIO] 3. Executing again before the interval reverts
// [SCENARIO] 4. Anyone can claim; output always goes to the owner
// [SCENARIO] 5. Rounds 2 and 3 run on schedule
// [SCENARIO] 6. A group without active rate cannot execute
// [SCENARIO] 7. Final claim completes the order
// [INFO] order: {"id":"1","owner":"g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh","groupId":"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500:0:60","poolPath":"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500","tokenIn":"gno.land/r/onbloc/foo.FOO","tokenOut":"gno.land/r/onbloc/bar.BAR","zeroForOne":false,"interval":"60","amountPerExecution":"1000","totalExecutions":"3","executedRounds":"3","startRound":"0","endRound":"3","cancelRound":"0","accDebtX128":"1017784559460526944218953450828418720463","claimedOut":"2989","claimable":"0","refundedIn":"0","feePaid":"0","status":"COMPLETED","createdAt":"1234567890","createdAtHeight":"123","finalizedAt":"1234568070"}
// [SCENARIO] 8. Completed orders cannot be claimed or cancelled again
// [SCENARIO] 9. A new order in an idle group runs immediately, even before the old slot
// [SCENARIO] done
