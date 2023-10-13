package pool

import (
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"
)

func FindBestPool(
	tokenA string,
	tokenB string,
	zeroForOne bool,
	amountSpecified bigint,
) string {
	if tokenA == tokenB {
		panic("token pair cannot be the same")
	}

	if tokenA > tokenB {
		tokenA, tokenB = tokenB, tokenA
	}

	partialPath := tokenA + "_" + tokenB + "_"
	foundPool := []string{}

	for poolPath, _ := range pools {
		if strings.HasPrefix(poolPath, partialPath) {
			foundPool = append(foundPool, poolPath)
		}
	}

	// check if amount is enough
	firstSelectedPool := []string{}
	if false {
		continue
	} else if zeroForOne == true && amountSpecified > 0 {
		for _, singlePool := range foundPool {
			p := GetPoolFromPoolKey(singlePool)
			poolSqrtX96 := p.slot0.sqrtPriceX96
			poolPrice := poolSqrtX96 * poolSqrtX96 / Q96 / Q96

			pool := GetPoolFromPoolKey(singlePool)
			if pool.balances.token1 > amountSpecified*poolPrice { // must be bigger (can't be equal due to fee)
				firstSelectedPool = append(firstSelectedPool, singlePool)
			}
		}

	} else if zeroForOne == true && amountSpecified < 0 {
		for _, singlePool := range foundPool {
			pool := GetPoolFromPoolKey(singlePool)
			if pool.balances.token1 > (-1 * amountSpecified) { // must be bigger (can't be equal due to fee)
				firstSelectedPool = append(firstSelectedPool, singlePool)
			}
		}

	} else if zeroForOne == false && amountSpecified > 0 {
		for _, singlePool := range foundPool {
			p := GetPoolFromPoolKey(singlePool)
			poolSqrtX96 := p.slot0.sqrtPriceX96
			poolPrice := poolSqrtX96 * poolSqrtX96 / Q96 / Q96

			pool := GetPoolFromPoolKey(singlePool)
			if pool.balances.token0 > amountSpecified/poolPrice { // must be bigger (can't be equal due to fee)
				firstSelectedPool = append(firstSelectedPool, singlePool)
			}
		}

	} else if zeroForOne == false && amountSpecified < 0 {
		for _, singlePool := range foundPool {
			pool := GetPoolFromPoolKey(singlePool)
			if pool.balances.token0 > (-1 * amountSpecified) { // must be bigger (can't be equal due to fee)
				firstSelectedPool = append(firstSelectedPool, singlePool)
			}
		}
	} else {
		panic(ufmt.Sprintf("[POOL] pool_router.gno__FindBestPool() || unknown swap condition, zeroForOne: %t, amountSpecified: %d", zeroForOne, amountSpecified))
	}

	// check tick and return
	var poolWithTick map[int32]string = make(map[int32]string)

	minTick := int32(887272)
	maxTick := int32(-887272)
	for _, singlePool := range firstSelectedPool {
		// save tick with poolPath
		pool := GetPoolFromPoolKey(singlePool)
		poolTick := pool.slot0.tick

		poolWithTick[poolTick] = singlePool

		// find min
		if poolTick < minTick {
			minTick = poolTick
		}

		// find max
		if poolTick > maxTick {
			maxTick = poolTick
		}
	}

	if zeroForOne == true { // if token0 is being sold to buy token1, then we want to find the pool with the largest tick (more token1 can be bought)
		return poolWithTick[maxTick]

	} else { // if token1 is being sold to buy token0, then we want to find the pool with the smallest tick (more token0 can be bought)
		return poolWithTick[minTick]
	}
}

func poolPathDivide(poolPath string) (string, string, uint16) {
	poolPathSplit := strings.Split(poolPath, "_")

	if len(poolPathSplit) != 3 {
		panic(ufmt.Sprintf("[POOL] pool_router.gno__poolPathDivide() || len(poolPathSplit) != 3, poolPath: %s", poolPath))
	}

	feeInt, err := strconv.ParseInt(poolPathSplit[2], 10, 16)
	if err != nil {
		panic(ufmt.Sprintf("[POOL] pool_router.gno__poolPathDivide() || cannot convert fee(%s) to uint16", poolPathSplit[2]))
	}

	return poolPathSplit[0], poolPathSplit[1], uint16(feeInt)
}
