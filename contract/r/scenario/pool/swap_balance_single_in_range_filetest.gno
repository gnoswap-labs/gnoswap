// Scenario: Swap Balance Validation - Single In-Range Position
// Purpose: Validate exact balance conservation for basic in-range position swaps

// PKGPATH: gno.land/r/gnoswap/pool/swap_balance_single

package swap_balance_single

import (
	"testing"

	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"
)

const (
	maxApprove      int64  = 9223372036854775806
	poolCreationFee int64  = 100_000_000
	fee500          uint32 = 500
)

var (
	adminAddr, _       = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm         = testing.NewUserRealm(adminAddr)
	positionAddr, _    = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm           = testing.NewUserRealm(positionAddr)
	routerRealm        = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	poolAddr, _        = access.GetAddress(prbac.ROLE_POOL.String())
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
)

var (
	btcPath = "gno.land/r/gnoswap/test_token/btc"
	atomPath = "gno.land/r/gnoswap/test_token/atom"
)

const (
	MIN_PRICE = "4295128740"
	MAX_PRICE = "1461446703485210103287273052203988822378723970341"
)

// turn protocol fee on
func init() {
	testing.SetRealm(adminRealm)
	pool.SetFeeProtocol(cross, 6, 6)
}

type BalanceSnapshot struct {
	userAtom        int64
	userBtc        int64
	poolAtom        int64
	poolBtc        int64
	protocolFeeAtom int64
	protocolFeeBtc int64
}

func main() {
	println("[SCENARIO] Swap Balance Validation - Single In-Range Position")
	println("[INFO] Purpose: Validate exact balance conservation for basic in-range swaps")
	println()

	println("[SCENARIO] 1. Setup Pool with In-Range Position")
	initial := setupPool()
	printBalanceSnapshot("After Pool Setup", initial)
	println()

	println("[SCENARIO] 2. ExactInput Swap (ATOM -> BTC)")
	afterExactIn := testExactInputSwap(initial)
	printBalanceSnapshot("After ExactInput Swap", afterExactIn)
	validateBalanceChange(initial, afterExactIn, "ExactInput")
	println()

	println("[SCENARIO] 3. ExactOutput Swap (BTC -> ATOM)")
	afterExactOut := testExactOutputSwap(afterExactIn)
	printBalanceSnapshot("After ExactOutput Swap", afterExactOut)
	validateBalanceChange(afterExactIn, afterExactOut, "ExactOutput")
	println()

	println("[SCENARIO] Complete - All in-range position validations passed")
}

func getBalanceSnapshot() BalanceSnapshot {
	return BalanceSnapshot{
		userAtom:        atom.BalanceOf(adminAddr),
		userBtc:        btc.BalanceOf(adminAddr),
		poolAtom:        atom.BalanceOf(poolAddr),
		poolBtc:        btc.BalanceOf(poolAddr),
		protocolFeeAtom: atom.BalanceOf(protocolFeeAddr),
		protocolFeeBtc: btc.BalanceOf(protocolFeeAddr),
	}
}

func printBalanceSnapshot(step string, snapshot BalanceSnapshot) {
	println("[INFO]", step)
	println("[EXPECTED] User ATOM balance:", snapshot.userAtom)
	println("[EXPECTED] User BTC balance:", snapshot.userBtc)
	println("[EXPECTED] Pool ATOM balance:", snapshot.poolAtom)
	println("[EXPECTED] Pool BTC balance:", snapshot.poolBtc)
	println("[EXPECTED] Protocol fee ATOM balance:", snapshot.protocolFeeAtom)
	println("[EXPECTED] Protocol fee BTC balance:", snapshot.protocolFeeBtc)
}

func setupPool() BalanceSnapshot {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, atomPath, btcPath, fee500, "79228162514264337593543950336")

	btc.Approve(cross, poolAddr, maxApprove)
	atom.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		atomPath,
		btcPath,
		fee500,
		-1000,
		1000,
		"1000000000",
		adminAddr,
	)

	println("[INFO] Pool created at 1:1 price with in-range position (-1000 to 1000)")
	println("[INFO] Minted amounts - atom:", amount0, "btc:", amount1)

	return getBalanceSnapshot()
}

func testExactInputSwap(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(adminRealm)

	pools, _ := pool.GetPool(atomPath, btcPath, fee500)
	tickBefore := pools.Slot0Tick()
	liquidityBefore := pools.Liquidity().ToString()

	println("[INFO] Swapping 100000 ATOM -> BTC (exact input)")

	atom.Approve(cross, poolAddr, 100000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		atomPath,
		btcPath,
		fee500,
		adminAddr,
		true,
		"100000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atomPath, btcPath, amount0Delta, amount1Delta)
		},
	)

	pools, _ = pool.GetPool(atomPath, btcPath, fee500)
	tickAfter := pools.Slot0Tick()
	liquidityAfter := pools.Liquidity().ToString()

	println("[INFO] Swap - In:", swapAmount0, "Out:", swapAmount1)
	println("[INFO] Tick:", tickBefore, "->", tickAfter)
	println("[INFO] Liquidity: before:", liquidityBefore, "after:", liquidityAfter)

	return getBalanceSnapshot()
}

func testExactOutputSwap(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(adminRealm)

	pools, _ := pool.GetPool(atomPath, btcPath, fee500)
	tickBefore := pools.Slot0Tick()
	liquidityBefore := pools.Liquidity().ToString()

	println("[INFO] Swapping BTC -> 50000 ATOM (exact output)")

	btc.Approve(cross, poolAddr, 200000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		atomPath,
		btcPath,
		fee500,
		adminAddr,
		false,
		"-50000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atomPath, btcPath, amount0Delta, amount1Delta)
		},
	)

	pools, _ = pool.GetPool(atomPath, btcPath, fee500)
	tickAfter := pools.Slot0Tick()
	liquidityAfter := pools.Liquidity().ToString()

	println("[INFO] Swap - In:", swapAmount0, "Out:", swapAmount1)
	println("[INFO] Tick:", tickBefore, "->", tickAfter)
	println("[INFO] Liquidity: before:", liquidityBefore, "after:", liquidityAfter)

	return getBalanceSnapshot()
}

func validateBalanceChange(before, after BalanceSnapshot, swapType string) {
	println("[INFO] Validating balance changes for", swapType)

	userAtomDiff := after.userAtom - before.userAtom
	userBtcDiff := after.userBtc - before.userBtc
	poolAtomDiff := after.poolAtom - before.poolAtom
	poolBtcDiff := after.poolBtc - before.poolBtc
	protocolFeeAtomDiff := after.protocolFeeAtom - before.protocolFeeAtom
	protocolFeeBtcDiff := after.protocolFeeBtc - before.protocolFeeBtc

	println("[EXPECTED] User ATOM change:", userAtomDiff)
	println("[EXPECTED] User BTC change:", userBtcDiff)
	println("[EXPECTED] Pool ATOM change:", poolAtomDiff)
	println("[EXPECTED] Pool BTC change:", poolBtcDiff)
	println("[EXPECTED] Protocol Fee ATOM change:", protocolFeeAtomDiff)
	println("[EXPECTED] Protocol Fee BTC change:", protocolFeeBtcDiff)

	// Exact conservation: user + pool + protocol fee changes must sum to 0
	totalAtomChange := userAtomDiff + poolAtomDiff + protocolFeeAtomDiff
	totalBtcChange := userBtcDiff + poolBtcDiff + protocolFeeBtcDiff

	if totalAtomChange != 0 {
		panic(ufmt.Sprintf("[ERROR] ATOM not conserved! Total change: %d", totalAtomChange))
	}
	if totalBtcChange != 0 {
		panic(ufmt.Sprintf("[ERROR] BTC not conserved! Total change: %d", totalBtcChange))
	}

	println("[EXPECTED] Exact balance conservation verified for", swapType)
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64) error {
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
// [SCENARIO] Swap Balance Validation - Single In-Range Position
// [INFO] Purpose: Validate exact balance conservation for basic in-range swaps
//
// [SCENARIO] 1. Setup Pool with In-Range Position
// [INFO] Pool created at 1:1 price with in-range position (-1000 to 1000)
// [INFO] Minted amounts - atom: 48768198 btc: 48768198
// [INFO] After Pool Setup
// [EXPECTED] User ATOM balance: 299999951231802
// [EXPECTED] User BTC balance: 2099999951231802
// [EXPECTED] Pool ATOM balance: 48768198
// [EXPECTED] Pool BTC balance: 48768198
// [EXPECTED] Protocol fee ATOM balance: 0
// [EXPECTED] Protocol fee BTC balance: 0
//
// [SCENARIO] 2. ExactInput Swap (ATOM -> BTC)
// [INFO] Swapping 100000 ATOM -> BTC (exact input)
// [INFO] Swap - In: 100000 Out: -99940
// [INFO] Tick: 0 -> -2
// [INFO] Liquidity: before: 1000000000 after: 1000000000
// [INFO] After ExactInput Swap
// [EXPECTED] User ATOM balance: 299999951131802
// [EXPECTED] User BTC balance: 2099999951331742
// [EXPECTED] Pool ATOM balance: 48868198
// [EXPECTED] Pool BTC balance: 48668258
// [EXPECTED] Protocol fee ATOM balance: 0
// [EXPECTED] Protocol fee BTC balance: 0
// [INFO] Validating balance changes for ExactInput
// [EXPECTED] User ATOM change: -100000
// [EXPECTED] User BTC change: 99940
// [EXPECTED] Pool ATOM change: 100000
// [EXPECTED] Pool BTC change: -99940
// [EXPECTED] Protocol Fee ATOM change: 0
// [EXPECTED] Protocol Fee BTC change: 0
// [EXPECTED] Exact balance conservation verified for ExactInput
//
// [SCENARIO] 3. ExactOutput Swap (BTC -> ATOM)
// [INFO] Swapping BTC -> 50000 ATOM (exact output)
// [INFO] Swap - In: -50000 Out: 50019
// [INFO] Tick: -2 -> -1
// [INFO] Liquidity: before: 1000000000 after: 1000000000
// [INFO] After ExactOutput Swap
// [EXPECTED] User ATOM balance: 299999951181802
// [EXPECTED] User BTC balance: 2099999951281723
// [EXPECTED] Pool ATOM balance: 48818198
// [EXPECTED] Pool BTC balance: 48718277
// [EXPECTED] Protocol fee ATOM balance: 0
// [EXPECTED] Protocol fee BTC balance: 0
// [INFO] Validating balance changes for ExactOutput
// [EXPECTED] User ATOM change: 50000
// [EXPECTED] User BTC change: -50019
// [EXPECTED] Pool ATOM change: -50000
// [EXPECTED] Pool BTC change: 50019
// [EXPECTED] Protocol Fee ATOM change: 0
// [EXPECTED] Protocol Fee BTC change: 0
// [EXPECTED] Exact balance conservation verified for ExactOutput
//
// [SCENARIO] Complete - All in-range position validations passed
