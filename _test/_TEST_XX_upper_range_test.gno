package swap_scneraio

import (
	"std"
	"testing"

	_ "gno.land/r/demo/grc20_wrapper"

	pl "gno.land/r/demo/pool"
	pos "gno.land/r/demo/position"
	rou "gno.land/r/demo/router"

	"gno.land/r/demo/gns"
	"gno.land/r/demo/token01"
	"gno.land/r/demo/token02"
)

var (
	test1 = std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5")

	poolAddr     = std.DerivePkgAddr("gno.land/r/demo/pool")
	positionAddr = std.DerivePkgAddr("gno.land/r/demo/position")
	stakerAddr   = std.DerivePkgAddr("gno.land/r/demo/staker")
	routerAddr   = std.DerivePkgAddr("gno.land/r/demo/router")

	token01Path = "gno.land/r/demo/token01"
	token02Path = "gno.land/r/demo/token02"

	max_timeout = bigint(9999999999)
)

func TestPoolInitByAdmin(t *testing.T) {
	std.TestSetOrigCaller(test1)

	pl.InitManual()
	std.TestSkipHeights(1)
}

func TestPoolCreatePools(t *testing.T) {
	std.TestSetOrigCaller(test1)

	// approve gns to CreatePool ( 500 gns for 1 pool)
	gns.Approve(a2u(poolAddr), 500*13)

	pl.CreatePool(token01Path, token02Path, 100, 79228162514264337593543950337) // tick 0 ≈ x1

	std.TestSkipHeights(4)
}

func TestApproveAll(t *testing.T) {
	std.TestSetOrigCaller(test1)

	token01.Approve(a2u(poolAddr), 10_000_000_000_000_000)
	token02.Approve(a2u(poolAddr), 10_000_000_000_000_000)
}

func TestPositionUpperRange(t *testing.T) {
	std.TestSetOrigCaller(test1)

	tokenId, liquidity, amount0, amount1 := pos.Mint(
		token01Path,       // token0
		token02Path,       // token1
		100,               // fee
		800,               // tickLower
		1200,              // tickUpper
		1_000_000_000_000, // amount0Desired
		1_000_000_000_000, // amount1Desired
		0,                 // amount0Min
		0,                 // amount1Min
		max_timeout,       // deadline
	)

	shouldEQ(t, tokenId, bigint(1))
	shouldEQ(t, amount0, bigint(999_999_999_999)) // Token1
	shouldEQ(t, amount1, bigint(0))               // Token2

	std.TestSkipHeights(3)
}

func TestDrySwapRouteUpperRangeEnoughBalance(t *testing.T) {
	std.TestSetOrigCaller(test1)

	// Token2 is input
	// Token1 is output
	dryResult := rou.DrySwapRoute(
		token02Path,         // inputToken
		token01Path,         // outputToken
		bigint(100_000_000), // amountSpecified
		"EXACT_IN",          // swapType
		"gno.land/r/demo/token02:gno.land/r/demo/token01:100", // strRouteArr
		"100", // quoteArr
	)
	shouldEQ(t, dryResult, bigint(92_302_603))
}

// func TestSwapRouteUpperRangeEnoughBalance(t *testing.T) {
// 	std.TestSetOrigCaller(test1)

// 	oldToken2 := token02.BalanceOf(a2u(test1))
// 	oldToken1 := token01.BalanceOf(a2u(test1))

// 	// TOKEN 2 WILL BE INPUT
// 	swapResult := rou.SwapRoute(
// 		token02Path,         // inputToken
// 		token01Path,         // outputToken
// 		bigint(100_000_000), // amountSpecified
// 		"EXACT_IN",          // swapType
// 		"gno.land/r/demo/token02:gno.land/r/demo/token01:100", // strRouteArr
// 		"100", // quoteArr
// 		"1",   // tokenAmountLimit(minRecv)
// 	)
// 	shouldEQ(t, swapResult, bigint(99_989_753))

// 	newToken2 := token02.BalanceOf(a2u(test1))
// 	newToken1 := token01.BalanceOf(a2u(test1))

// 	println("sent Token2:", oldToken2-newToken2)
// 	println("recv Token1:", newToken1-oldToken1)
// }
