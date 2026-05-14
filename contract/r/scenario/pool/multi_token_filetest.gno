// PKGPATH: gno.land/r/demo/main

package main

import (
	"strconv"
	"testing"

	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
	"gno.land/r/gnoswap/test_token/btc"

	"gno.land/r/gnoswap/gns"
)

// Constants for fee tiers
const (
	fee500 uint32 = 500
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
)

// Variables for test addresses and realms
var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = testing.NewUserRealm(positionAddr)
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())
	rouRealm        = testing.NewUserRealm(routerAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
)

// Token paths
var (
	btcPath = "gno.land/r/gnoswap/test_token/btc"
	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
)

var (
	test_tickLower          = int32(9000)
	test_tickUpper          = int32(11000)
	test_liquidityExpectStr = "100000000"
	test_liquidityExpect256 = u256.NewUint(100_000_000)

	poolCreationFee = int64(100_000_000)

	MIN_PRICE string = "4295128740"
)

func main() {
	println("[SCENARIO] Multi Token")
	testing.SetRealm(adminRealm)

	println("[INFO] Create btc <> atom pool")
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, atomPath, btcPath, fee500, common.TickMathGetSqrtRatioAtTick(-10000).ToString()) // tick -10000

	println("[INFO] Create atom <> atone pool")
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, atonePath, atomPath, fee500, "130621891405341611593710811006")

	println("[SCENARIO] 1. Mint Btc:Atom Liquidity")
	TestMintBtcAtomLiquidity()

	println("[SCENARIO] 2. Mint Atom:Atone Liquidity")
	TestMintAtomAtoneLiquidity()

	println("[SCENARIO] 3. Swap Btc:Atom Btc > Atom")
	TestSwapBtcAtomBtcToAtom()

	println("[SCENARIO] 4. Swap Atom:Atone Atom > Atone by admin")
	TestSwapAtomAtoneAtomToAtone()

	println("[SCENARIO] 5. Collect Btc:Atom Fees")
	TestCollectBtcAtomFees()

	println("[SCENARIO] 6. Collect Atom:Atone Fees")
	TestCollectAtomAtoneFees()

	println("[SCENARIO] 7. Burn Btc:Atom Liquidity")
	TestBurnBtcAtomLiquidity()

	println("[SCENARIO] 8. Burn Atom:Atone Liquidity")
	TestBurnAtomAtoneLiquidity()

	println("[SCENARIO] 9. Collect Btc:Atom burned Liquidity")
	TestCollectBtcAtomLiquidity()

	println("[SCENARIO] 10. Collect Atom:Atone burned Liquidity")
	TestCollectAtomAtoneLiquidity()
}

// Mint Btc:Atom Liquidity by admin
func TestMintBtcAtomLiquidity() {
	testing.SetRealm(adminRealm)
	btc.Approve(cross, poolAddr, maxApprove)
	atom.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		btcPath,
		atomPath,
		fee500,
		-test_tickUpper,
		-test_tickLower,
		test_liquidityExpectStr,
		adminAddr,
	)

	println("[EXPECTED] amount0:", amount0, "expected: 8040316")
	println("[EXPECTED] amount1:", amount1, "expected: 2958015")
	println()
}

// Mint Atom:Atone Liquidity by admin
func TestMintAtomAtoneLiquidity() {
	testing.SetRealm(adminRealm)
	atom.Approve(cross, poolAddr, maxApprove)
	atone.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		atomPath,
		atonePath,
		fee500,
		test_tickLower,
		test_tickUpper,
		test_liquidityExpectStr,
		adminAddr,
	)

	println("[EXPECTED] amount0:", amount0, "expected: 2958015")
	println("[EXPECTED] amount1:", amount1, "expected: 8040316")
	println()
}

// Swap Btc:Atom Btc > Atom by admin
func TestSwapBtcAtomBtcToAtom() {
	oldTest1Atom := atom.BalanceOf(adminAddr)
	oldTest1Btc := btc.BalanceOf(adminAddr)

	oldPoolAtom := atom.BalanceOf(poolAddr)
	oldPoolBtc := btc.BalanceOf(poolAddr)

	testing.SetRealm(adminRealm)
	atom.Approve(cross, poolAddr, 16000)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	poolIn, poolOut := pool.Swap(
		cross,
		atomPath,
		btcPath,
		fee500,
		adminAddr,
		true,
		"16000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			mockSwapCallback(atomPath, btcPath, amount0Delta, amount1Delta, true)

			return nil
		},
	)
	println("[EXPECTED] poolIn:", poolIn, "expected: 16000")
	println("[EXPECTED] poolOut:", poolOut, "expected: -5882")
	println()

	newTest1Atom := atom.BalanceOf(adminAddr)
	newTest1Btc := btc.BalanceOf(adminAddr)

	newPoolAtom := atom.BalanceOf(poolAddr)
	newPoolBtc := btc.BalanceOf(poolAddr)

	println("[EXPECTED] oldTest1Atom-newTest1Atom:", oldTest1Atom-newTest1Atom, "expected: 16000")
	println("[EXPECTED] newTest1Btc-oldTest1Btc:", newTest1Btc-oldTest1Btc, "expected: 5882")
	println("[EXPECTED] newPoolAtom-oldPoolAtom:", newPoolAtom-oldPoolAtom, "expected: 16000")
	println("[EXPECTED] oldPoolBtc-newPoolBtc:", oldPoolBtc-newPoolBtc, "expected: 5882")
	println()
}

func TestSwapAtomAtoneAtomToAtone() {
	oldTest1Token0Balance := atom.BalanceOf(adminAddr)
	oldadminAtoneBalance := atone.BalanceOf(adminAddr)
	oldPoolToken0Balance := atom.BalanceOf(poolAddr)
	oldPoolAtoneBalance := atone.BalanceOf(poolAddr)

	testing.SetRealm(adminRealm)
	atom.Approve(cross, poolAddr, 16000)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	poolIn, poolOut := pool.Swap(
		cross,
		atomPath,
		atonePath,
		fee500,
		adminAddr,
		true,
		"16000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atomPath, atonePath, amount0Delta, amount1Delta, true)
		},
	)

	println("[EXPECTED] poolIn:", poolIn, "expected: 16000")
	println("[EXPECTED] poolOut:", poolOut, "expected: -43457")
	println()

	newTest1Token0Balance := atom.BalanceOf(adminAddr)
	newAdminAtoneBalance := atone.BalanceOf(adminAddr)
	newPoolToken0Balance := atom.BalanceOf(poolAddr)
	newPoolAtoneBalance := atone.BalanceOf(poolAddr)

	println("[EXPECTED] oldTest1Token0Balance-newTest1Token0Balance:", oldTest1Token0Balance-newTest1Token0Balance, "expected: 16000")
	println("[EXPECTED] newAdminAtoneBalance-oldadminAtoneBalance:", newAdminAtoneBalance-oldadminAtoneBalance, "expected: 43457")
	println("[EXPECTED] newPoolToken0Balance-oldPoolToken0Balance:", newPoolToken0Balance-oldPoolToken0Balance, "expected: 16000")
	println("[EXPECTED] oldPoolAtoneBalance-newPoolAtoneBalance:", oldPoolAtoneBalance-newPoolAtoneBalance, "expected: 43457")
	println()
}

func TestCollectBtcAtomFees() {
	testing.SetRealm(posRealm)

	poolPath := ufmt.Sprintf("%s:%s:%d", atomPath, btcPath, fee500)
	oldToken0Balance := pool.GetBalanceToken0(poolPath)
	oldToken1Balance := pool.GetBalanceToken1(poolPath)

	// burn 0 to collect swap fees
	pool.Burn(cross, atomPath, btcPath, fee500, -test_tickUpper, -test_tickLower, "0", adminAddr)

	c0, c1 := pool.Collect(
		cross,
		atomPath,
		btcPath,
		fee500,
		adminAddr,
		-test_tickUpper,
		-test_tickLower,
		"100000",
		"100000",
	)

	println("[INFO] Swap: btc -> atom, thus only btc has fees")
	println("[EXPECTED] c0:", c0, "expected: should not be 0") // swap was btc > atom, so only btc has fees
	println("[EXPECTED] c1:", c1, "expected: should be 0")     // swap was btc > atom, so atom has no fees

	newToken0Balance := pool.GetBalanceToken0(poolPath)
	newToken1Balance := pool.GetBalanceToken1(poolPath)

	println("[EXPECTED] oldToken0Balance:", oldToken0Balance)
	println("[EXPECTED] oldToken1Balance:", oldToken1Balance)
	println("[EXPECTED] newToken0Balance:", newToken0Balance)
	println("[EXPECTED] newToken1Balance:", newToken1Balance)
	println()
}

func TestCollectAtomAtoneFees() {
	testing.SetRealm(posRealm)

	poolPath := ufmt.Sprintf("%s:%s:%d", atomPath, atonePath, fee500)
	oldToken0Balance := pool.GetBalanceToken1(poolPath)
	oldToken1Balance := pool.GetBalanceToken0(poolPath)

	// burn 0 to collect swap fees
	pool.Burn(cross, atomPath, atonePath, fee500, test_tickLower, test_tickUpper, "0", adminAddr)

	c0, c1 := pool.Collect(
		cross,
		atomPath,
		atonePath,
		fee500,
		adminAddr,
		test_tickLower,
		test_tickUpper,
		"100000",
		"100000",
	)

	println("[INFO] Swap: atom -> atone, thus only atom has fees")
	println("[EXPECTED] c0:", c0, "expected: should not be 0") // swap was atom > atone, so only atom has fees
	println("[EXPECTED] c1:", c1, "expected: should be 0")     // swap was atom > atone, so atone has no fees

	newToken0Balance := pool.GetBalanceToken0(poolPath)
	newToken1Balance := pool.GetBalanceToken1(poolPath)

	println("[EXPECTED] oldToken0Balance:", oldToken0Balance)
	println("[EXPECTED] oldToken1Balance:", oldToken1Balance)
	println("[EXPECTED] newToken0Balance:", newToken0Balance)
	println("[EXPECTED] newToken1Balance:", newToken1Balance)
	println()
}

// Burn Btc:Atom Liquidity by admin
func TestBurnBtcAtomLiquidity() {
	testing.SetRealm(posRealm)

	poolData, _ := pool.GetPool(btcPath, atomPath, fee500)
	poolOldLiquidity := poolData.Liquidity()

	b0, b1 := pool.Burn(
		cross,
		btcPath,
		atomPath,
		fee500,
		-test_tickUpper,
		-test_tickLower,
		test_liquidityExpectStr,
		adminAddr,
	)

	println("[EXPECTED] b0:", b0, "expected: should not be 0")
	println("[EXPECTED] b1:", b1, "expected: should not be 0")

	poolData, _ = pool.GetPool(btcPath, atomPath, fee500)
	poolNewLiquidity := poolData.Liquidity()

	expected := u256.Zero().Sub(poolOldLiquidity, poolNewLiquidity).ToString()
	println("[EXPECTED] expected:", expected, "expected: should be", test_liquidityExpect256.ToString())
	println()
}

func TestBurnAtomAtoneLiquidity() {
	testing.SetRealm(posRealm)

	poolData, _ := pool.GetPool(atomPath, atonePath, fee500)
	poolOldLiquidity := poolData.Liquidity()

	b0, b1 := pool.Burn(
		cross,
		atomPath,
		atonePath,
		fee500,
		test_tickLower,
		test_tickUpper,
		test_liquidityExpectStr,
		adminAddr,
	)

	println("[EXPECTED] b0:", b0, "expected: should not be 0")
	println("[EXPECTED] b1:", b1, "expected: should not be 0")

	poolData, _ = pool.GetPool(atomPath, atonePath, fee500)
	poolNewLiquidity := poolData.Liquidity()

	expected := u256.Zero().Sub(poolOldLiquidity, poolNewLiquidity).ToString()
	println("[EXPECTED] expected:", expected, "expected: should be 0")
	println()
}

// Collect Btc:Atom burned Liquidity by admin
func TestCollectBtcAtomLiquidity() {
	testing.SetRealm(posRealm)

	poolPath := ufmt.Sprintf("%s:%s:%d", atomPath, btcPath, fee500)
	oldToken0Balance := pool.GetBalanceToken0(poolPath)
	oldToken1Balance := pool.GetBalanceToken1(poolPath)

	c0, c1 := pool.Collect(
		cross,
		atomPath,
		btcPath,
		fee500,
		adminAddr,
		-test_tickUpper,
		-test_tickLower,
		"100000",
		"100000",
	)

	println("[EXPECTED] c0:", c0, "expected: should not be 0")
	println("[EXPECTED] c1:", c1, "expected: should not be 0")

	newToken0Balance := pool.GetBalanceToken0(poolPath)
	newToken1Balance := pool.GetBalanceToken1(poolPath)

	println("[EXPECTED] oldToken0Balance:", oldToken0Balance)
	println("[EXPECTED] oldToken1Balance:", oldToken1Balance)
	println("[EXPECTED] newToken0Balance:", newToken0Balance)
	println("[EXPECTED] newToken1Balance:", newToken1Balance)
	println()
}

// Collect Atom:Atone burned Liquidity by admin
func TestCollectAtomAtoneLiquidity() {
	testing.SetRealm(posRealm)

	poolPath := ufmt.Sprintf("%s:%s:%d", atomPath, atonePath, fee500)
	oldToken0Balance := pool.GetBalanceToken1(poolPath)
	oldToken1Balance := pool.GetBalanceToken0(poolPath)

	c0, c1 := pool.Collect(
		cross,
		atomPath,
		atonePath,
		fee500,
		adminAddr,
		test_tickLower,
		test_tickUpper,
		"100000",
		"100000",
	)

	println("[EXPECTED] c0:", c0, "expected: should not be 0")
	println("[EXPECTED] c1:", c1, "expected: should not be 0")

	newToken0Balance := pool.GetBalanceToken0(poolPath)
	newToken1Balance := pool.GetBalanceToken1(poolPath)

	println("[EXPECTED] oldToken0Balance:", oldToken0Balance)
	println("[EXPECTED] oldToken1Balance:", oldToken1Balance)
	println("[EXPECTED] newToken0Balance:", newToken0Balance)
	println("[EXPECTED] newToken1Balance:", newToken1Balance)
	println()
}

func strToUint64(s string) uint64 {
	i, err := strconv.Atoi(s)
	if err != nil {
		panic("strToUint64")
	}
	return uint64(i)
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, zeroForOne bool) error {
	testing.SetRealm(adminRealm)

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	}

	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] Multi Token
// [INFO] Create btc <> atom pool
// [INFO] Create atom <> atone pool
// [SCENARIO] 1. Mint Btc:Atom Liquidity
// [EXPECTED] amount0: 8040316 expected: 8040316
// [EXPECTED] amount1: 2958015 expected: 2958015
//
// [SCENARIO] 2. Mint Atom:Atone Liquidity
// [EXPECTED] amount0: 6067683 expected: 2958015
// [EXPECTED] amount1: 0 expected: 8040316
//
// [SCENARIO] 3. Swap Btc:Atom Btc > Atom
// [EXPECTED] poolIn: 16000 expected: 16000
// [EXPECTED] poolOut: -5882 expected: -5882
//
// [EXPECTED] oldTest1Atom-newTest1Atom: 16000 expected: 16000
// [EXPECTED] newTest1Btc-oldTest1Btc: 5882 expected: 5882
// [EXPECTED] newPoolAtom-oldPoolAtom: 16000 expected: 16000
// [EXPECTED] oldPoolBtc-newPoolBtc: 5882 expected: 5882
//
// [SCENARIO] 4. Swap Atom:Atone Atom > Atone by admin
// [EXPECTED] poolIn: 0 expected: 16000
// [EXPECTED] poolOut: 0 expected: -43457
//
// [EXPECTED] oldTest1Token0Balance-newTest1Token0Balance: 0 expected: 16000
// [EXPECTED] newAdminAtoneBalance-oldadminAtoneBalance: 0 expected: 43457
// [EXPECTED] newPoolToken0Balance-oldPoolToken0Balance: 0 expected: 16000
// [EXPECTED] oldPoolAtoneBalance-newPoolAtoneBalance: 0 expected: 43457
//
// [SCENARIO] 5. Collect Btc:Atom Fees
// [INFO] Swap: btc -> atom, thus only btc has fees
// [EXPECTED] c0: 7 expected: should not be 0
// [EXPECTED] c1: 0 expected: should be 0
// [EXPECTED] oldToken0Balance: 8056316
// [EXPECTED] oldToken1Balance: 2952133
// [EXPECTED] newToken0Balance: 8056309
// [EXPECTED] newToken1Balance: 2952133
//
// [SCENARIO] 6. Collect Atom:Atone Fees
// [INFO] Swap: atom -> atone, thus only atom has fees
// [EXPECTED] c0: 0 expected: should not be 0
// [EXPECTED] c1: 0 expected: should be 0
// [EXPECTED] oldToken0Balance: 0
// [EXPECTED] oldToken1Balance: 6067683
// [EXPECTED] newToken0Balance: 6067683
// [EXPECTED] newToken1Balance: 0
//
// [SCENARIO] 7. Burn Btc:Atom Liquidity
// [EXPECTED] b0: 8056307 expected: should not be 0
// [EXPECTED] b1: 2952131 expected: should not be 0
// [EXPECTED] expected: 100000000 expected: should be 100000000
//
// [SCENARIO] 8. Burn Atom:Atone Liquidity
// [EXPECTED] b0: 6067682 expected: should not be 0
// [EXPECTED] b1: 0 expected: should not be 0
// [EXPECTED] expected: 0 expected: should be 0
//
// [SCENARIO] 9. Collect Btc:Atom burned Liquidity
// [EXPECTED] c0: 100000 expected: should not be 0
// [EXPECTED] c1: 100000 expected: should not be 0
// [EXPECTED] oldToken0Balance: 8056309
// [EXPECTED] oldToken1Balance: 2952133
// [EXPECTED] newToken0Balance: 7956309
// [EXPECTED] newToken1Balance: 2852133
//
// [SCENARIO] 10. Collect Atom:Atone burned Liquidity
// [EXPECTED] c0: 100000 expected: should not be 0
// [EXPECTED] c1: 0 expected: should not be 0
// [EXPECTED] oldToken0Balance: 0
// [EXPECTED] oldToken1Balance: 6067683
// [EXPECTED] newToken0Balance: 5967683
// [EXPECTED] newToken1Balance: 0
