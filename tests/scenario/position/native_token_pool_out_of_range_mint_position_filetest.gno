// native token pool out of range mint position

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

func main() {
	// 1. Create Pool (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000)
	// - token0: gno.land/r/demo/wugnot
	// - token1: gno.land/r/gnoswap/v1/gns
	// - fee: 3000
	// - startTick: 0
	// 2. Mint InRange Position
	// - token0: gno.land/r/demo/wugnot
	// - token1: gno.land/r/gnoswap/v1/gns
	// - fee: 3000
	// - minTick: -6960
	// - maxTick: 6960
	// - amount0: 10000000
	// - amount1: 10000000
	// - minAmount0: 1
	// - minAmount1: 1
	// - deadline: 9999999999
	// 3. Mint OutOfRange Position (only token0)
	// - token0: gno.land/r/demo/wugnot
	// - token1: gno.land/r/gnoswap/v1/gns
	// - fee: 3000
	// - minTick: -10140
	// - maxTick: -8100
	// - amount0: 50000000
	// - amount1: 0
	// - minAmount0: 1
	// - minAmount1: 0
	// - deadline: 9999999999
	// 4. Mint OutOfRange Position (only token1)
	// - token0: gno.land/r/demo/wugnot
	// - token1: gno.land/r/gnoswap/v1/gns
	// - fee: 3000
	// - minTick: 8100
	// - maxTick: 10140
	// - amount0: 0
	// - amount1: 50000000
	// - minAmount0: 0
	// - minAmount1: 1
	// - deadline: 9999999999
}
