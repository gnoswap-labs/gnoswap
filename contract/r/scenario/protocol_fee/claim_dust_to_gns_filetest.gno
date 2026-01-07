// PKGPATH: gno.land/r/demo/main
package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/r/gnoswap/access"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	pf "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
)

var (
	adminAddr, _       = access.GetAddress(prbac.ROLE_ADMIN.String())
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	govStakerAddr, _   = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	poolAddr, _        = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _      = access.GetAddress(prbac.ROLE_ROUTER.String())
)

var (
	adminRealm       = testing.NewUserRealm(adminAddr)
	stakerRealm      = testing.NewCodeRealm("gno.land/r/gnoswap/staker")
	govStakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker")
	protocolFeeRealm = testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee")
)

const (
	barPath = "gno.land/r/onbloc/bar"
	gnsPath = "gno.land/r/gnoswap/gns"

	minTick    int32 = -887220
	maxTick    int32 = 887220
	maxTimeout int64 = 9999999999
	maxApprove int64 = 9223372036854775806
)

var (
	baseProtocolFeeBarBalance int64
	baseProtocolFeeGnsBalance int64
	baseRecordedBarAmount     int64
	baseRecordedGnsAmount     int64
)

func main() {
	println("[SCENARIO] Claim dust to GNS from protocol_fee")
	println()

	println("[SCENARIO] 1. Setup pool and liquidity")
	setupPool()
	println()

	println("[SCENARIO] 2. Record dust balances")
	setupDustBalances()
	println()

	println("[SCENARIO] 3. Configure dust filters")
	configureDustFilters()
	println()

	println("[SCENARIO] 4. Approve router for protocol_fee")
	approveRouter()
	println()

	println("[SCENARIO] 5. Claim dust to GNS")
	claimDustToGns()
	println()
}

func setupPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())

	println("[INFO] Approving tokens for pool operations")
	bar.Approve(cross, poolAddr, maxApprove)
	gns.Approve(cross, poolAddr, maxApprove)

	println("[INFO] Creating bar-GNS pool (fee: 3000)")
	pl.CreatePool(cross, barPath, gnsPath, 3000, "79228162514264337593543950336") // encodePriceSqrt(1, 1)

	println("[INFO] Minting position in bar-GNS pool")
	pn.Mint(cross, barPath, gnsPath, 3000, minTick, maxTick, "1000000", "1000000", "0", "0", maxTimeout, adminAddr, adminAddr, "")

	pool := pl.GetPool(barPath, gnsPath, 3000)
	println("[EXPECTED] pool liquidity:", pool.Liquidity().ToString(), "expected: 1000000")
}

func setupDustBalances() {
	testing.SetRealm(govStakerRealm)
	baseRecordedBarAmount = pf.GetAmountOfToken(barPath)
	baseRecordedGnsAmount = pf.GetAmountOfToken(gnsPath)
	baseProtocolFeeBarBalance = bar.BalanceOf(protocolFeeAddr)
	baseProtocolFeeGnsBalance = gns.BalanceOf(protocolFeeAddr)

	testing.SetRealm(adminRealm)
	testing.SetOriginCaller(adminAddr)

	println("[INFO] Transferring bar dust to protocol_fee")
	bar.Transfer(cross, protocolFeeAddr, 3)
	println("[INFO] Transferring gns dust to protocol_fee")
	gns.Transfer(cross, protocolFeeAddr, 2)

	println("[EXPECTED] protocol_fee bar balance:", bar.BalanceOf(protocolFeeAddr), "expected:", baseProtocolFeeBarBalance+3)
	println("[EXPECTED] protocol_fee gns balance:", gns.BalanceOf(protocolFeeAddr), "expected:", baseProtocolFeeGnsBalance+2)

	testing.SetRealm(stakerRealm)
	println("[INFO] Recording bar dust amount")
	pf.AddToProtocolFee(cross, barPath, 3)
	println("[INFO] Recording gns dust amount")
	pf.AddToProtocolFee(cross, gnsPath, 2)

	testing.SetRealm(govStakerRealm)
	println("[EXPECTED] recorded bar amount:", pf.GetAmountOfToken(barPath), "expected:", baseRecordedBarAmount+3)
	println("[EXPECTED] recorded gns amount:", pf.GetAmountOfToken(gnsPath), "expected:", baseRecordedGnsAmount+2)
}

func configureDustFilters() {
	testing.SetRealm(adminRealm)
	println("[INFO] Setting dust min/max range (1..10)")
	pf.SetDustClaimMinAmount(cross, 1)
	pf.SetDustClaimMaxAmount(cross, 10)
}

func approveRouter() {
	testing.SetRealm(protocolFeeRealm)
	println("[INFO] Approving router to spend protocol_fee bar")
	bar.Approve(cross, routerAddr, maxApprove)
}

func claimDustToGns() {
	testing.SetRealm(govStakerRealm)

	beforeGovGns := gns.BalanceOf(govStakerAddr)

	dryAmountIn, dryAmountOut, ok := router.DrySwapRoute(
		barPath,
		gnsPath,
		"3",
		"EXACT_IN",
		barPath+":"+gnsPath+":3000",
		"100",
		"1",
	)
	if !ok {
		panic("dry swap failed")
	}

	dryOut, err := strconv.ParseInt(dryAmountOut, 10, 64)
	if err != nil {
		panic(err)
	}

	expectedSwapOut := dryOut
	if expectedSwapOut < 0 {
		expectedSwapOut = -expectedSwapOut
	}

	totalGnsOut := pf.ClaimDustToGns(
		cross,
		[]string{barPath, gnsPath},
		[]int64{3, 2},
		[]string{barPath + ":" + gnsPath + ":3000", ""},
		[]string{"100", ""},
		[]string{"1", ""},
		time.Now().Add(time.Hour).Unix(),
		"",
		govStakerAddr,
	)

	println("[EXPECTED] dry swap amountIn:", dryAmountIn, "expected: 3")
	println("[EXPECTED] dry swap amountOut:", dryAmountOut, "expected: > 0")
	println("[EXPECTED] totalGnsOut:", totalGnsOut, "expected:", expectedSwapOut+2)
	println("[EXPECTED] protocol_fee bar balance after claim:", bar.BalanceOf(protocolFeeAddr), "expected:", baseProtocolFeeBarBalance)
	println("[EXPECTED] protocol_fee gns balance after claim:", gns.BalanceOf(protocolFeeAddr), "expected:", baseProtocolFeeGnsBalance)
	println("[EXPECTED] recorded bar amount after claim:", pf.GetAmountOfToken(barPath), "expected:", baseRecordedBarAmount)
	println("[EXPECTED] recorded gns amount after claim:", pf.GetAmountOfToken(gnsPath), "expected:", baseRecordedGnsAmount)
	println("[EXPECTED] govStaker gns delta:", gns.BalanceOf(govStakerAddr)-beforeGovGns, "expected:", expectedSwapOut+2)
}

// Output:
// [SCENARIO] Claim dust to GNS from protocol_fee
//
// [SCENARIO] 1. Setup pool and liquidity
// [INFO] Approving pool creation fee
// [INFO] Approving tokens for pool operations
// [INFO] Creating bar-GNS pool (fee: 3000)
// [INFO] Minting position in bar-GNS pool
// [EXPECTED] pool liquidity: 1000000 expected: 1000000
//
// [SCENARIO] 2. Record dust balances
// [INFO] Transferring bar dust to protocol_fee
// [INFO] Transferring gns dust to protocol_fee
// [EXPECTED] protocol_fee bar balance: 3 expected: 3
// [EXPECTED] protocol_fee gns balance: 100000002 expected: 100000002
// [INFO] Recording bar dust amount
// [INFO] Recording gns dust amount
// [EXPECTED] recorded bar amount: 3 expected: 3
// [EXPECTED] recorded gns amount: 100000002 expected: 100000002
//
// [SCENARIO] 3. Configure dust filters
// [INFO] Setting dust min/max range (1..10)
//
// [SCENARIO] 4. Approve router for protocol_fee
// [INFO] Approving router to spend protocol_fee bar
//
// [SCENARIO] 5. Claim dust to GNS
// [EXPECTED] dry swap amountIn: 3 expected: 3
// [EXPECTED] dry swap amountOut: 1 expected: > 0
// [EXPECTED] totalGnsOut: 3 expected: 3
// [EXPECTED] protocol_fee bar balance after claim: 0 expected: 0
// [EXPECTED] protocol_fee gns balance after claim: 100000000 expected: 100000000
// [EXPECTED] recorded bar amount after claim: 0 expected: 0
// [EXPECTED] recorded gns amount after claim: 100000000 expected: 100000000
// [EXPECTED] govStaker gns delta: 3 expected: 3
