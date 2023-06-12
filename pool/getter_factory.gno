package gnoswap

import (
	"gno.land/p/demo/grc/grc20"
)

func GetPoolToken0(pool *Pool) *grc20.AdminToken {
	return pool.token0
}

func GetPoolToken1(pool *Pool) *grc20.AdminToken {
	return pool.token1
}

func GetPoolFee(pool *Pool) bigint {
	return pool.fee
}

func GetPoolLiquidity(pool *Pool) bigint {
	return pool.liquidity
}
