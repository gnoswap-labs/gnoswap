package router

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	_ "gno.land/r/grc20_wrapper"
	p "gno.land/r/pool"
	pos "gno.land/r/position"
)

var (
	gsa  = testutils.TestAddress("gsa")  // Gnoswap Admin
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01

	poolAddr   = std.DerivePkgAddr("gno.land/r/pool")
	posAddr    = std.DerivePkgAddr("gno.land/r/position")
	routerAddr = std.DerivePkgAddr("gno.land/r/router")
)

var (
	// Common
	fooPath = "gno.land/r/foo" // token1
	barPath = "gno.land/r/bar" // token2
	bazPath = "gno.land/r/baz" // token3
	quxPath = "gno.land/r/qux" // token4

	test_tickLower       = int32(9000)
	test_tickUpper       = int32(11000)
	test_liquidityExpect = bigint(1000)
)

func init() {
	println(gsa, "// gsa")
	println(lp01, "// lp01")
	println(poolAddr, "// poolAddr")
	println(posAddr, "// posAddr")
	println(routerAddr, "// routerAddr")
}

func TestInitManual(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	p.InitManual()
	std.TestSkipHeights(1)
}

func TestCreatePool(t *testing.T) {
	std.TestSetOrigCaller(gsa)

	// p.CreatePool(fooPath, barPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// p.CreatePool(fooPath, barPath, uint16(500), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// p.CreatePool(fooPath, bazPath, uint16(500), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// p.CreatePool(barPath, bazPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// findSwapPaths("gno.land/r/foo", "gno.land/r/baz")                           // 3 paths
	// // foo_bar_100 > bar_baz_100
	// // foo_bar_500 > bar_baz_100
	// // foo_baz_500

	// p.CreatePool(fooPath, barPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// p.CreatePool(fooPath, quxPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// p.CreatePool(barPath, bazPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// p.CreatePool(barPath, quxPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// p.CreatePool(bazPath, quxPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// findSwapPaths("gno.land/r/foo", "gno.land/r/qux")                           // 3 paths
	// // foo_qux_100
	// // foo_bar_100 > bar_qux_100
	// // foo_bar_100 > bar_baz_100 > baz_qux_100

	// p.CreatePool(fooPath, barPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// p.CreatePool(fooPath, barPath, uint16(500), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// p.CreatePool(fooPath, quxPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// p.CreatePool(barPath, bazPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// p.CreatePool(barPath, quxPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// p.CreatePool(bazPath, quxPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// findSwapPaths("gno.land/r/foo", "gno.land/r/qux")                           // 5 paths
	// foo_qux_100
	// foo_bar_100 > bar_qux_100
	// foo_bar_500 > bar_qux_100
	// foo_bar_100 > bar_baz_100 > baz_qux_100
	// foo_bar_500 > bar_baz_100 > baz_qux_100

	p.CreatePool(fooPath, barPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	p.CreatePool(fooPath, quxPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	p.CreatePool(barPath, quxPath, uint16(100), 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	// findSwapPaths("gno.land/r/foo", "gno.land/r/qux") // 2 paths
	// foo_bar_100 > bar_qux_100
	// foo_qux_100
}

func TestPositionMint(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	pos.Mint(
		fooPath,
		barPath,
		uint16(100),
		test_tickLower,
		test_tickUpper,
		bigint(10000000),
		bigint(10000000),
		bigint(1),
		bigint(1),
		bigint(9999999999),
	)

	pos.Mint(
		fooPath,
		quxPath,
		uint16(100),
		test_tickLower,
		test_tickUpper,
		bigint(10000),
		bigint(10000),
		bigint(1),
		bigint(1),
		bigint(9999999999),
	)

	pos.Mint(
		barPath,
		quxPath,
		uint16(100),
		test_tickLower,
		test_tickUpper,
		bigint(10000000),
		bigint(10000000),
		bigint(1),
		bigint(1),
		bigint(9999999999),
	)
}

func TestFuncs(t *testing.T) {
	// sPath := findSwapPaths("gno.land/r/foo", "gno.land/r/qux") // 2 paths

	outputAmount := SwapRoute(
		"gno.land/r/foo", // inputTokenPath
		"gno.land/r/qux", // outputTokenPath

		10_000,                  // amountIn
		std.Address("g123recv"), // recipient
		0,                       // sqrtPriceLimitX96
	)

	println("YOU GOT QUX OF", outputAmount)

}
