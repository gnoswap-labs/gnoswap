// wugnot gns 100 pool burn position with narrow range

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

func main() {
	// 1. Create Pool (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:100)
	// - token0: gno.land/r/demo/wugnot
	// - token1: gno.land/r/gnoswap/v1/gns
	// - fee: 100
	// - startTick: 6960 (sqrtPriceX96: 112207715239306133611883942758)
	// 2. Position Mint
	// - token0: gno.land/r/demo/wugnot
	// - token1: gno.land/r/gnoswap/v1/gns
	// - fee: 100
	// - minTick: -1
	// - maxTick: 1
	// - amount0: 10000000
	// - amount1: 10000000
	// - minAmount0: 1
	// - minAmount1: 1
	// - deadline: 9999999999
	// 2. Position Burn
	// - token0: gno.land/r/demo/wugnot
	// - token1: gno.land/r/gnoswap/v1/gns
	// - fee: 100
	// - liquidity: 9999999
	// - minAmount0: 0
	// - minAmount1: 0
}
