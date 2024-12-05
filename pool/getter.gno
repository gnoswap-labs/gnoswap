package pool

import (
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

func PoolGetPoolList() []string {
	poolPaths := []string{}
	for poolPath, _ := range pools {
		poolPaths = append(poolPaths, poolPath)
	}

	return poolPaths
}

func PoolGetSlot0Tick(poolPath string) int32 {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno()__PoolGetSlot0Tick || poolPath(%s) does not exist", poolPath),
		))
	}

	return pool.slot0.tick
}

func PoolGetSqrtPriceX96(poolPath string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno()__PoolGetSqrtPriceX96 || poolPath(%s) does not exist", poolPath),
		))
	}

	return pool.slot0.sqrtPriceX96
}

func PoolGetLiquidity(poolPath string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_no_receiver.gno()__PoolGetLiquidity || poolPath(%s) does not exist", poolPath),
		))
	}

	return pool.liquidity.ToString()
}

func (p *Pool) PoolGetSlot0() Slot0 {
	return p.slot0
}

func (p *Pool) PoolGetSlot0SqrtPriceX96() *u256.Uint {
	return p.slot0.sqrtPriceX96
}

func (p *Pool) PoolGetSlot0Tick() int32 {
	return p.slot0.tick
}

func (p *Pool) PoolGetPositionFeeGrowthInside0LastX128(key string) *u256.Uint {
	position, exist := p.positions[key]
	if !exist {
		return u256.Zero()
	}

	return position.feeGrowthInside0LastX128
}

func (p *Pool) PoolGetPositionFeeGrowthInside1LastX128(key string) *u256.Uint {
	position, exist := p.positions[key]
	if !exist {
		return u256.Zero()
	}

	return position.feeGrowthInside1LastX128
}

func (p *Pool) PoolGetTickFeeGrowthOutside0X128(x int32) *u256.Uint {
	tick, exist := p.ticks[x]
	if !exist {
		return u256.Zero()
	}

	return tick.feeGrowthOutside0X128
}

func (p *Pool) PoolGetTickFeeGrowthOutside1X128(x int32) *u256.Uint {
	tick, exist := p.ticks[x]
	if !exist {
		return u256.Zero()
	}

	return tick.feeGrowthOutside1X128
}

func (p *Pool) PoolGetToken0Path() string {
	return p.token0Path
}

func (p *Pool) PoolGetToken1Path() string {
	return p.token1Path
}

func (p *Pool) PoolGetFee() uint32 {
	return p.fee
}

func (p *Pool) PoolGetFeeGrowthGlobal0X128() *u256.Uint {
	return p.feeGrowthGlobal0X128
}

func (p *Pool) PoolGetFeeGrowthGlobal1X128() *u256.Uint {
	return p.feeGrowthGlobal1X128
}

func (p *Pool) PoolGetLiquidity() *u256.Uint {
	return p.liquidity
}
