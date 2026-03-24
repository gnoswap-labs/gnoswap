package v1

import (
	"strconv"
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

type tokenBalanceSnapshot struct {
	userToken0 int64
	userToken1 int64
	poolToken0 int64
	poolToken1 int64
}

func snapshotTokenBalances(t *testing.T, user address) tokenBalanceSnapshot {
	t.Helper()

	return tokenBalanceSnapshot{
		userToken0: TokenBalance(t, barPath, user),
		userToken1: TokenBalance(t, fooPath, user),
		poolToken0: TokenBalance(t, barPath, poolAddr),
		poolToken1: TokenBalance(t, fooPath, poolAddr),
	}
}

func mustDecimalInt64(t *testing.T, raw string) int64 {
	t.Helper()

	return mustDecimalInt64FromString(t, raw)
}

func mustDecimalInt64FromUint(t *testing.T, value *u256.Uint) int64 {
	t.Helper()

	return mustDecimalInt64FromString(t, value.ToString())
}

func mustDecimalInt64FromString(t *testing.T, raw string) int64 {
	t.Helper()

	parsed, err := strconv.ParseInt(raw, 10, 64)
	if err != nil {
		t.Fatalf("parse decimal %q: %v", raw, err)
	}

	return parsed
}

func addDecimalStrings(t *testing.T, left string, right string) string {
	t.Helper()

	sum := mustDecimalInt64(t, left) + mustDecimalInt64(t, right)
	return strconv.FormatInt(sum, 10)
}

func assertUserSpentAndPoolReceived(t *testing.T, before, after tokenBalanceSnapshot, amount0, amount1 string) {
	t.Helper()

	amt0 := mustDecimalInt64(t, amount0)
	amt1 := mustDecimalInt64(t, amount1)

	assertDecimalStringsWithinOne(t, strconv.FormatInt(-amt0, 10), strconv.FormatInt(after.userToken0-before.userToken0, 10), "user token0 spend should match returned amount")
	assertDecimalStringsWithinOne(t, strconv.FormatInt(-amt1, 10), strconv.FormatInt(after.userToken1-before.userToken1, 10), "user token1 spend should match returned amount")
	assertDecimalStringsWithinOne(t, strconv.FormatInt(amt0, 10), strconv.FormatInt(after.poolToken0-before.poolToken0, 10), "pool token0 receipt should match returned amount")
	assertDecimalStringsWithinOne(t, strconv.FormatInt(amt1, 10), strconv.FormatInt(after.poolToken1-before.poolToken1, 10), "pool token1 receipt should match returned amount")
}

func assertUserReceivedAndPoolSpent(t *testing.T, before, after tokenBalanceSnapshot, amount0, amount1 string) {
	t.Helper()

	amt0 := mustDecimalInt64(t, amount0)
	amt1 := mustDecimalInt64(t, amount1)

	assertDecimalStringsWithinOne(t, strconv.FormatInt(amt0, 10), strconv.FormatInt(after.userToken0-before.userToken0, 10), "user token0 receipt should match returned amount")
	assertDecimalStringsWithinOne(t, strconv.FormatInt(amt1, 10), strconv.FormatInt(after.userToken1-before.userToken1, 10), "user token1 receipt should match returned amount")
	assertDecimalStringsWithinOne(t, strconv.FormatInt(-amt0, 10), strconv.FormatInt(after.poolToken0-before.poolToken0, 10), "pool token0 spend should match returned amount")
	assertDecimalStringsWithinOne(t, strconv.FormatInt(-amt1, 10), strconv.FormatInt(after.poolToken1-before.poolToken1, 10), "pool token1 spend should match returned amount")
}

func assertCalcIncreaseMatchesAmountsWithinOne(t *testing.T, before0, before1, after0, after1 *u256.Uint, amount0, amount1 string, message string) {
	t.Helper()

	delta0 := mustDecimalInt64FromUint(t, after0) - mustDecimalInt64FromUint(t, before0)
	delta1 := mustDecimalInt64FromUint(t, after1) - mustDecimalInt64FromUint(t, before1)
	assertDecimalStringsWithinOne(t, amount0, strconv.FormatInt(delta0, 10), message+" token0")
	assertDecimalStringsWithinOne(t, amount1, strconv.FormatInt(delta1, 10), message+" token1")
}

func assertCalcDecreaseMatchesAmountsWithinOne(t *testing.T, before0, before1, after0, after1 *u256.Uint, amount0, amount1 string, message string) {
	t.Helper()

	delta0 := mustDecimalInt64FromUint(t, before0) - mustDecimalInt64FromUint(t, after0)
	delta1 := mustDecimalInt64FromUint(t, before1) - mustDecimalInt64FromUint(t, after1)
	assertDecimalStringsWithinOne(t, amount0, strconv.FormatInt(delta0, 10), message+" token0")
	assertDecimalStringsWithinOne(t, amount1, strconv.FormatInt(delta1, 10), message+" token1")
}

func mintInvariantPosition(t *testing.T, owner address) (uint64, string, string, string) {
	t.Helper()

	return mockInstanceMint(
		barPath,
		fooPath,
		fee500,
		-10000,
		10000,
		"1000000",
		"1000000",
		"0",
		"0",
		time.Now().Add(time.Hour).Unix(),
		owner,
		owner,
		"",
	)
}

func fundInvariantOwner(t *testing.T, owner address) {
	t.Helper()
	TokenFaucet(t, barPath, owner)
	TokenFaucet(t, fooPath, owner)
}

func TestMintTransitionInvariantMatchesActualTransfers(t *testing.T) {
	initPositionTest(t)
	createPoolWithoutFee(barPath, fooPath, fee500, 0)
	fundInvariantOwner(t, alice)

	before := snapshotTokenBalances(t, alice)
	positionId, _, amount0, amount1 := mintInvariantPosition(t, alice)
	after := snapshotTokenBalances(t, alice)

	assertUserSpentAndPoolReceived(t, before, after, amount0, amount1)

	positionAfter := mockInstance.mustGetPosition(positionId)
	calcAfter0, calcAfter1 := calculatePositionBalances(positionAfter)
	assertDecimalStringsWithinOne(t, amount0, calcAfter0.ToString(), "mint calcAfter should match actual token0 deposit")
	assertDecimalStringsWithinOne(t, amount1, calcAfter1.ToString(), "mint calcAfter should match actual token1 deposit")
	assertDecimalStringsWithinOne(t, calcAfter0.ToString(), mockInstance.GetPositionToken0Balance(positionId).ToString(), "mint token0 getter should return balance matching calcAfter")
	assertDecimalStringsWithinOne(t, calcAfter1.ToString(), mockInstance.GetPositionToken1Balance(positionId).ToString(), "mint token1 getter should return balance matching calcAfter")
}

func TestIncreaseLiquidityTransitionInvariantMatchesActualTransfers(t *testing.T) {
	initPositionTest(t)
	createPoolWithoutFee(barPath, fooPath, fee500, 0)
	fundInvariantOwner(t, alice)

	positionId, _, _, _ := mintInvariantPosition(t, alice)
	movePoolPriceForPositionTest(t, false, "300000")

	positionBefore := mockInstance.mustGetPosition(positionId)
	calcBefore0, calcBefore1 := calculatePositionBalances(positionBefore)
	before := snapshotTokenBalances(t, alice)

	_, _, amount0, amount1, _ := mockInstanceIncreaseLiquidity(
		positionId,
		"500000",
		"1000000",
		"0",
		"0",
		time.Now().Add(time.Hour).Unix(),
		alice,
	)

	after := snapshotTokenBalances(t, alice)
	assertUserSpentAndPoolReceived(t, before, after, amount0, amount1)

	positionAfter := mockInstance.mustGetPosition(positionId)
	calcAfter0, calcAfter1 := calculatePositionBalances(positionAfter)
	assertCalcIncreaseMatchesAmountsWithinOne(t, calcBefore0, calcBefore1, calcAfter0, calcAfter1, amount0, amount1, "increase calc delta should match actual deposit")
	assertDecimalStringsWithinOne(t, calcAfter0.ToString(), mockInstance.GetPositionToken0Balance(positionId).ToString(), "increase token0 getter should return balance matching calcAfter")
	assertDecimalStringsWithinOne(t, calcAfter1.ToString(), mockInstance.GetPositionToken1Balance(positionId).ToString(), "increase token1 getter should return balance matching calcAfter")
}

func TestDecreaseLiquidityTransitionInvariantMatchesActualTransfers(t *testing.T) {
	initPositionTest(t)
	createPoolWithoutFee(barPath, fooPath, fee500, 0)
	fundInvariantOwner(t, alice)

	positionId, _, _, _ := mintInvariantPosition(t, alice)
	movePoolPriceForPositionTest(t, false, "300000")

	positionBefore := mockInstance.mustGetPosition(positionId)
	calcBefore0, calcBefore1 := calculatePositionBalances(positionBefore)
	before := snapshotTokenBalances(t, alice)
	testing.SetRealm(testing.NewUserRealm(alice))
	testing.SetOriginCaller(alice)

	_, _, fee0, fee1, amount0, amount1, _ := mockInstanceDecreaseLiquidity(
		positionId,
		"1000000",
		"0",
		"0",
		time.Now().Add(time.Hour).Unix(),
	)

	after := snapshotTokenBalances(t, alice)
	assertUserReceivedAndPoolSpent(t, before, after, addDecimalStrings(t, amount0, fee0), addDecimalStrings(t, amount1, fee1))

	positionAfter := mockInstance.mustGetPosition(positionId)
	calcAfter0, calcAfter1 := calculatePositionBalances(positionAfter)
	assertCalcDecreaseMatchesAmountsWithinOne(t, calcBefore0, calcBefore1, calcAfter0, calcAfter1, amount0, amount1, "decrease calc delta should match actual withdrawal")
	assertDecimalStringsWithinOne(t, calcAfter0.ToString(), mockInstance.GetPositionToken0Balance(positionId).ToString(), "decrease token0 getter should return balance matching calcAfter")
	assertDecimalStringsWithinOne(t, calcAfter1.ToString(), mockInstance.GetPositionToken1Balance(positionId).ToString(), "decrease token1 getter should return balance matching calcAfter")
}

func TestRepositionTransitionInvariantMatchesActualTransfers(t *testing.T) {
	initPositionTest(t)
	createPoolWithoutFee(barPath, fooPath, fee500, 0)
	fundInvariantOwner(t, alice)

	positionId, _, _, _ := mintInvariantPosition(t, alice)
	movePoolPriceForPositionTest(t, false, "300000")

	positionBeforeClear := mockInstance.mustGetPosition(positionId)
	liquidityToRemove := positionBeforeClear.Liquidity().ToString()
	testing.SetRealm(testing.NewUserRealm(alice))
	testing.SetOriginCaller(alice)
	_, _, fee0, fee1, clearAmount0, clearAmount1, _ := mockInstanceDecreaseLiquidity(
		positionId,
		liquidityToRemove,
		"0",
		"0",
		time.Now().Add(time.Hour).Unix(),
	)
	uassert.True(t, mustDecimalInt64(t, addDecimalStrings(t, clearAmount0, fee0)) > 0 || mustDecimalInt64(t, addDecimalStrings(t, clearAmount1, fee1)) > 0, "clear should return value before reposition")

	cleared := mockInstance.mustGetPosition(positionId)
	calcCleared0, calcCleared1 := calculatePositionBalances(cleared)
	uassert.Equal(t, "0", calcCleared0.ToString())
	uassert.Equal(t, "0", calcCleared1.ToString())

	before := snapshotTokenBalances(t, alice)
	testing.SetOriginCaller(alice)
	_, _, _, _, amount0, amount1 := mockInstanceReposition(
		positionId,
		-5000,
		5000,
		"500000",
		"1000000",
		"0",
		"0",
		time.Now().Add(time.Hour).Unix(),
		alice,
	)
	after := snapshotTokenBalances(t, alice)

	assertUserSpentAndPoolReceived(t, before, after, amount0, amount1)

	positionAfter := mockInstance.mustGetPosition(positionId)
	calcAfter0, calcAfter1 := calculatePositionBalances(positionAfter)
	assertCalcIncreaseMatchesAmountsWithinOne(t, calcCleared0, calcCleared1, calcAfter0, calcAfter1, amount0, amount1, "reposition calc delta should match actual redeposit")
	assertDecimalStringsWithinOne(t, calcAfter0.ToString(), mockInstance.GetPositionToken0Balance(positionId).ToString(), "reposition token0 getter should return balance matching calcAfter")
	assertDecimalStringsWithinOne(t, calcAfter1.ToString(), mockInstance.GetPositionToken1Balance(positionId).ToString(), "reposition token1 getter should return balance matching calcAfter")
}
