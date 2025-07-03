// exact out swap route with multi route

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

func main() {
	// 1. Create Pool Amd Mint Position (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:500)
	// - token0: gno.land/r/demo/wugnot
	// - token1: gno.land/r/gnoswap/v1/gns
	// - fee: 500
	// - startTick: 6960 (sqrtPriceX96: 112207715239306133611883942758)
	// 2. Create Pool And Mint Position (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000)
	// - token0: gno.land/r/demo/wugnot
	// - token1: gno.land/r/gnoswap/v1/gns
	// - fee: 3000
	// - startTick: 6960 (sqrtPriceX96: 112207715239306133611883942758)
	// 3. Create Pool And Mint Position (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:10000)
	// - token0: gno.land/r/demo/wugnot
	// - token1: gno.land/r/gnoswap/v1/gns
	// - fee: 10000
	// - startTick: 6960 (sqrtPriceX96: 112207715239306133611883942758)
	// 4. ExactOutSwapRoute
	// - inputToken: gnot
	// - outputToken: gno.land/r/gnoswap/v1/gns
	// - specifiedAmount: 1001502
	// - route: gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:500,gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000,gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:10000
	// - rate: 40,40,20
	// - amountInMax: 548135
	// - deadline: 9999999999
}
