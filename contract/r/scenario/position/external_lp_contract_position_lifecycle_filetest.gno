// external LP contract position lifecycle

// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain/runtime"
	"strconv"
	"testing"

	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	int64Max   int64 = 9223372036854775807
	maxTimeout int64 = 9999999999

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())

	externalLPRealm runtime.Realm
	externalLPAddr  address
)

func main() {
	externalLPRealm = testing.NewCodeRealm("gno.land/r/demo/main")
	externalLPAddr = externalLPRealm.Address()

	ufmt.Println("[SCENARIO] 1. Initialize pool and fund external LP contract")
	initPoolAndExternalLP()
	println()

	ufmt.Println("[SCENARIO] 2. External LP contract mints position")
	positionId := externalLPMintPosition()
	println()

	ufmt.Println("[SCENARIO] 3. External LP contract increases liquidity")
	externalLPIncreaseLiquidity(positionId)
	println()

	ufmt.Println("[SCENARIO] 4. External LP contract collects fees")
	externalLPCollectFee(positionId)
	println()

	ufmt.Println("[SCENARIO] 5. External LP contract decreases partial liquidity")
	externalLPDecreasePartialLiquidity(positionId)
	println()

	ufmt.Println("[SCENARIO] 6. External LP contract clears position liquidity")
	externalLPClearPosition(positionId)
	println()

	ufmt.Println("[SCENARIO] 7. External LP contract repositions cleared position")
	externalLPReposition(positionId)
	println()

	ufmt.Println("[SCENARIO] 8. External LP contract collects after reposition")
	externalLPCollectFee(positionId)
	println()

	ufmt.Println("[SCENARIO] 9. External LP contract cannot set position operator")
	externalLPSetOperatorBlocked(positionId)
}

func initPoolAndExternalLP() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)
	pool.CreatePool(cross, barPath, fooPath, 500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	bar.Transfer(cross, externalLPAddr, 1_000_000_000)
	foo.Transfer(cross, externalLPAddr, 1_000_000_000)

	ufmt.Printf("[EXPECTED] External LP contract address: %s\n", externalLPAddr.String())
}

func approveExternalLP(amount int64) {
	testing.SetRealm(externalLPRealm)
	bar.Approve(cross, poolAddr, amount)
	foo.Approve(cross, poolAddr, amount)
}

func externalLPMintPosition() uint64 {
	approveExternalLP(int64Max)

	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		500,
		-500,
		500,
		"100000000",
		"100000000",
		"0",
		"0",
		maxTimeout,
		"",
	)

	assertPositionOwner(positionId, externalLPAddr)
	assertNonZeroString("mint liquidity", liquidity)
	assertNonZeroString("mint amount0", amount0)
	assertNonZeroString("mint amount1", amount1)

	ufmt.Printf("[EXPECTED] Mint owner is external LP contract: %s\n", externalLPAddr.String())
	ufmt.Printf("[EXPECTED] Mint position ID: %d\n", positionId)
	return positionId
}

func externalLPIncreaseLiquidity(positionId uint64) {
	approveExternalLP(int64Max)

	_, liquidity, amount0, amount1, _ := position.IncreaseLiquidity(
		cross,
		positionId,
		"50000000",
		"50000000",
		"0",
		"0",
		maxTimeout,
	)

	assertPositionOwner(positionId, externalLPAddr)
	assertNonZeroString("increase liquidity", liquidity)
	assertNonZeroString("increase amount0", amount0)
	assertNonZeroString("increase amount1", amount1)

	ufmt.Printf("[EXPECTED] IncreaseLiquidity succeeds from external LP contract: %s\n", liquidity)
}

func externalLPCollectFee(positionId uint64) {
	testing.SetRealm(externalLPRealm)

	_, amount0, amount1, _, _, _ := position.CollectFee(cross, positionId)
	assertPositionOwner(positionId, externalLPAddr)

	ufmt.Printf("[EXPECTED] CollectFee succeeds from external LP contract: amount0=%s amount1=%s\n", amount0, amount1)
}

func externalLPDecreasePartialLiquidity(positionId uint64) {
	testing.SetRealm(externalLPRealm)

	liquidity := mustParseUint(position.GetPositionLiquidity(positionId))
	partialLiquidity := liquidity / 2
	if partialLiquidity == 0 {
		panic("expected non-zero partial liquidity")
	}

	_, removedLiquidity, _, _, amount0, amount1, _ := position.DecreaseLiquidity(
		cross,
		positionId,
		strconv.FormatUint(partialLiquidity, 10),
		"0",
		"0",
		maxTimeout,
	)

	assertPositionOwner(positionId, externalLPAddr)
	assertNonZeroString("partial decrease liquidity", removedLiquidity)
	assertNonZeroString("partial decrease amount0", amount0)
	assertNonZeroString("partial decrease amount1", amount1)

	ufmt.Printf("[EXPECTED] DecreaseLiquidity partial succeeds from external LP contract: %s\n", removedLiquidity)
}

func externalLPClearPosition(positionId uint64) {
	testing.SetRealm(externalLPRealm)

	remainingLiquidity := position.GetPositionLiquidity(positionId)
	assertNonZeroString("remaining liquidity before clear", remainingLiquidity)

	position.DecreaseLiquidity(
		cross,
		positionId,
		remainingLiquidity,
		"0",
		"0",
		maxTimeout,
	)

	assertPositionOwner(positionId, externalLPAddr)
	if position.GetPositionLiquidity(positionId) != "0" {
		panic(ufmt.Sprintf("expected cleared liquidity, got %s", position.GetPositionLiquidity(positionId)))
	}

	ufmt.Println("[EXPECTED] Full DecreaseLiquidity clears the external LP contract position")
}

func externalLPReposition(positionId uint64) {
	approveExternalLP(int64Max)

	_, liquidity, tickLower, tickUpper, amount0, amount1 := position.Reposition(
		cross,
		positionId,
		-1000,
		1000,
		"75000000",
		"75000000",
		"0",
		"0",
		maxTimeout,
	)

	assertPositionOwner(positionId, externalLPAddr)
	assertNonZeroString("reposition liquidity", liquidity)
	assertNonZeroString("reposition amount0", amount0)
	assertNonZeroString("reposition amount1", amount1)
	if tickLower != -1000 || tickUpper != 1000 {
		panic(ufmt.Sprintf("unexpected reposition ticks: %d %d", tickLower, tickUpper))
	}

	ufmt.Printf("[EXPECTED] Reposition succeeds from external LP contract: %s\n", liquidity)
}

func externalLPSetOperatorBlocked(positionId uint64) {
	testing.SetRealm(externalLPRealm)

	r := revive(func() {
		position.SetPositionOperator(cross, positionId, adminAddr)
	})
	if r == nil {
		panic("external LP contract should not be able to set position operator")
	}

	assertPositionOwner(positionId, externalLPAddr)
	ufmt.Println("[EXPECTED] SetPositionOperator remains staker-only for external LP contract positions")
}

func assertPositionOwner(positionId uint64, expected address) {
	actual := position.GetPositionOwner(positionId)
	if actual != expected {
		panic(ufmt.Sprintf("unexpected owner for position %d: expected %s, got %s", positionId, expected, actual))
	}
}

func assertNonZeroString(label string, value string) {
	if value == "" || value == "0" {
		panic(ufmt.Sprintf("expected non-zero %s, got %s", label, value))
	}
}

func mustParseUint(value string) uint64 {
	parsed, err := strconv.ParseUint(value, 10, 64)
	if err != nil {
		panic(err)
	}
	return parsed
}

// Output:
// [SCENARIO] 1. Initialize pool and fund external LP contract
// [EXPECTED] External LP contract address: g1e8cq4xmeza97f78c2kd6lzwf8hnyet34me44mu
//
// [SCENARIO] 2. External LP contract mints position
// [EXPECTED] Mint owner is external LP contract: g1e8cq4xmeza97f78c2kd6lzwf8hnyet34me44mu
// [EXPECTED] Mint position ID: 1
//
// [SCENARIO] 3. External LP contract increases liquidity
// [EXPECTED] IncreaseLiquidity succeeds from external LP contract: 2025204158
//
// [SCENARIO] 4. External LP contract collects fees
// [EXPECTED] CollectFee succeeds from external LP contract: amount0=0 amount1=0
//
// [SCENARIO] 5. External LP contract decreases partial liquidity
// [EXPECTED] DecreaseLiquidity partial succeeds from external LP contract: 3037806237
//
// [SCENARIO] 6. External LP contract clears position liquidity
// [EXPECTED] Full DecreaseLiquidity clears the external LP contract position
//
// [SCENARIO] 7. External LP contract repositions cleared position
// [EXPECTED] Reposition succeeds from external LP contract: 1537887470
//
// [SCENARIO] 8. External LP contract collects after reposition
// [EXPECTED] CollectFee succeeds from external LP contract: amount0=0 amount1=0
//
// [SCENARIO] 9. External LP contract cannot set position operator
// [EXPECTED] SetPositionOperator remains staker-only for external LP contract positions
